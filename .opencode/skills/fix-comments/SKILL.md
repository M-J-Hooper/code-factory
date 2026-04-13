---
name: fix-comments
description: >
  Use when the user wants to address code review comments, apply suggestions,
  reply to review threads, or resolve review feedback on a pull request.
  Triggers: "fix review comments", "address feedback", "reply to comments",
  "address pr comments", "resolve pr reviews", "fix comments".
argument-hint: "[PR number, URL, or comment URL, optional --reviewer <name>, optional --auto-human]"
user-invocable: true
allowed-tools: Bash(git:*), Bash(gh:*), Bash(./scripts/*), Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# Fix Review Comments

Announce: "I'm using the fix-comments skill to address review feedback on this PR."

## Routing

| If you need... | Use instead |
|----------------|-------------|
| Get a PR fully green (conflicts + comments + CI + automated reviews) | `/pr-ready` |
| Review a PR and produce feedback | `/review` — read-only analysis with structured findings |
| Resolve merge/rebase/cherry-pick conflicts | `/fix-conflicts` — standalone conflict resolution |

## Step 1: Gather Context

Parse `$ARGUMENTS` for:

| Input | Pattern | Example |
|-------|---------|---------|
| PR number | Digits | `42`, `332190` |
| PR URL | `github.com/.*/pull/\d+` | `https://github.com/org/repo/pull/42` |
| Comment URL | `github.com/.*/pull/\d+#discussion_r\d+` | `https://github.com/org/repo/pull/42#discussion_r123` |
| Reviewer filter | `--reviewer <name>` | `--reviewer alice` |
| Full autonomous mode | `--auto-human` | `--auto-human` |

**Full autonomous mode (`--auto-human`):** Skips prompts for human review threads. Defaults: "Fix all" for non-disagreements, "Explain and keep" for disagreements.

Run in parallel:

- `gh auth status 2>&1`
- `gh repo view --json nameWithOwner -q '.nameWithOwner'` (split on `/` to get `{owner}` and `{repo}` for API calls)
- `git branch --show-current`
- `git status --short`

**If `gh` is not authenticated:** inform the user to run `gh auth login`. Stop.

**If no PR number provided:** detect from current branch:

```bash
gh pr view --json number -q '.number' 2>/dev/null
```

**If still no PR:** ask the user for the PR number. Stop.

Capture the changed-files list for pattern scanning in Step 4:

```bash
gh pr view {number} --json baseRefName -q '.baseRefName'
git diff --name-only origin/{base}...HEAD
```

## Step 2: Fetch Unresolved Review Threads

Fetch actionable review threads using the `get-pr-comments.sh` script. The script handles GraphQL pagination, structured output, and large-output fallback automatically.

```bash
./scripts/get-pr-comments.sh -a {number}
```

For comment URLs, pass the full URL instead of the PR number:

```bash
./scripts/get-pr-comments.sh -a "https://github.com/org/repo/pull/42#discussion_r123"
```

**If output exceeds 25KB:** the script writes to `/tmp/pr-comments-{owner}-{repo}-{pr}.json` and prints a message to stderr. Use the Read tool to load the data from that path.

The script returns a JSON array of threads. Each thread contains:

| Field | Usage |
|-------|-------|
| `thread_id` | GraphQL node ID — pass to `resolveReviewThread` mutation |
| `first_comment_id` | REST API comment ID — pass to reply endpoint |
| `resolved` | Always `false` when using `-a` flag |
| `outdated` | Always `false` when using `-a` flag |
| `path` | File path relative to repo root |
| `line` | End line number in the diff |
| `start_line` | Start line for multi-line comments (null = single line) |
| `comments[]` | Array of `{ comment_id, body, author, outdated, path, line, html_url }` |

**If `--reviewer` specified:** filter the output:

```bash
echo "$THREADS" | jq '[.[] | select(.comments[0].author == "{reviewer}")]'
```

**If no threads returned:** all review threads are resolved. Report and stop.

## Step 3: Categorize and Prioritize

Classify each thread into one of four categories:

| Category | Signals | Action |
|----------|---------|--------|
| **Suggestion** | Body contains `` ```suggestion `` block | Apply the suggested code change |
| **Code change** | Imperative language ("change X", "add Y", "remove Z"), bug report, missing handling | Edit the code as requested |
| **Question** | Ends with `?`, asks "why", requests clarification | Respond with explanation |
| **Disagreement** | Reviewer challenges a design decision, requests a revert or alternative approach | **NEVER auto-resolve.** Present to user for decision. |
| **Outdated** | Thread `outdated` is true or all comments have `outdated: true` | Read current code at `path`. If the concern is already addressed, resolve with a note. If not, reclassify as Code change or Question. |

Assign priority:

| Priority | Criteria |
|----------|----------|
| **P0** | Bugs, security issues, breaking changes, data integrity |
| **P1** | Refactoring with clear benefit, naming/clarity, type safety, missing error handling |
| **P2** | Nits, style preferences, minor optimizations, "for next time" suggestions |

Show the user a concise summary:

```
PR #{number}: {title}
{total} unresolved threads ({reviewer filter if applied})

P0 (Critical):  {count} — {brief descriptions}
P1 (Should fix): {count} — {brief descriptions}
P2 (Nice to have): {count} — {brief descriptions}

Proposed actions:
- Apply suggestions: {count}
- Code changes: {count}
- Respond with explanation: {count}
- Need your decision: {count} (disagreements)
```

**If `--auto-human` mode:** Skip all prompts. Default to "Fix all" for non-disagreements and "Explain and keep" for disagreements. Proceed to Step 4.

**For disagreements**, present each one explicitly:

<interaction>
AskUserQuestion(
  header: "Review disagreement",
  question: "Thread on {path}:{line} — Reviewer says: '{summary}'. How should we handle this?",
  options: [
    "Fix as requested" — Make the change the reviewer wants,
    "Explain and keep" — Respond with explanation, do not change code,
    "Discuss further" — Reply asking for more context, do not resolve
  ]
)
</interaction>

**For everything else**, ask:

<interaction>
AskUserQuestion(
  header: "Proceed?",
  question: "Ready to address {count} threads ({suggestions} suggestions, {changes} code changes, {questions} explanations)?",
  options: [
    "Fix all" — Address all threads as categorized,
    "Let me choose" — Review each thread individually before proceeding
  ]
)
</interaction>

If "Let me choose": present each thread with its category and proposed action. Let the user override categories or skip specific threads.

## Step 4: Execute Fixes

Process threads grouped by file. Within each file, sort by line number **descending** (bottom-to-top) to prevent line drift.

### Applying Suggestions

For threads with `` ```suggestion `` blocks:

1. Extract the suggested code from between `` ```suggestion `` and `` ``` `` markers. If a comment contains multiple suggestion blocks, apply the first one. If ambiguous, ask the user.
2. Read the file at `path`.
3. Replace the lines at `line` (or `start_line..line` for multi-line) with the suggested code.
4. Use the Edit tool to apply the change.

### Applying Code Changes

For threads requiring code changes:

1. Read the file at `path` to understand context around `line`.
2. Determine the fix based on the reviewer's comment.
3. Apply the change using the Edit tool.
4. If the fix is unclear, ask the user for clarification before proceeding.

### Pattern Scanning

After applying a code change, scan the other files in the changed-files list (from Step 1) for the same pattern. If the reviewer flagged missing error handling, a naming convention, or a structural issue — the same problem likely exists elsewhere in this PR.

1. Use Grep to search the changed files for the same pattern.
2. Fix all occurrences, not just the one the reviewer flagged.
3. Note the additional fixes in the Step 5 reply: "Fixed here and in {N} other locations: {file1}, {file2}."

Only scan for the **exact pattern** the reviewer identified. Do not generalize into a broad lint pass.

### Preparing Explanations

For threads requiring explanations:

1. Read the code context to understand the design decision.
2. Draft a technical explanation (not defensive — focus on reasoning, constraints, trade-offs).
3. Format the explanation with semantic line breaks: one sentence per line, break after clause-separating punctuation. Target 120 characters per line. Rendered output is unchanged; this keeps reply diffs clean.
4. Include links to relevant docs or code if applicable.

## Step 5: Reply and Resolve Threads

For each addressed thread, reply directly to the review comment and resolve the thread.

**Reply** with a two-tier approach: try the threaded reply first, fall back to a top-level PR comment if it fails.

**Tier 1 — Threaded reply** (preferred).
Use the thread's `first_comment_id` and a HEREDOC for the body.
Skip this tier if `first_comment_id` is `0`, `null`, or missing.

```bash
gh api repos/{owner}/{repo}/pulls/comments/{first_comment_id}/replies \
  -X POST -f body="$(cat <<'EOF'
{response text}
EOF
)"
```

**Tier 2 — PR comment fallback.**
If Tier 1 was skipped or returned an error (404, 403, rate limit),
post a top-level PR comment that references the original thread.
Build the reference from `comments[0].html_url`, `path`, `line`, and `comments[0].author`:

```bash
gh pr comment {number} --body "$(cat <<'EOF'
Re: [{path}:{line}]({html_url}) (@{author})

{response text}
EOF
)"
```

Track threads that used the fallback — they are reported in Step 7.

Response format by category:

| Category | Format |
|----------|--------|
| Suggestion applied | `Done — applied the suggestion.` |
| Code change | `Fixed — {brief description of what changed}.` |
| Explanation | `{technical explanation with reasoning}` |
| Disagreement (fix) | `Agreed — {brief description of the fix}.` |
| Disagreement (keep) | `{explanation of reasoning}. Let me know if you'd like to discuss further.` |
| Outdated (addressed) | `This has been addressed in a subsequent update.` |

All replies must end with `\n\n_Sent from my Claude_`.

**Resolve** the thread using the GraphQL mutation from [references/graphql-queries.md](references/graphql-queries.md), passing the thread's `thread_id`.
Attempt resolution regardless of which reply tier was used — `thread_id` is independent of `first_comment_id`.
If `thread_id` is also missing (REST fallback data from error handling), skip resolution and note as "replied but not resolved" in Step 7.

**Do NOT resolve:**
- Threads where the user chose "Discuss further"
- Threads where the reply is a question back to the reviewer

## Step 6: Commit and Push

Group changes into logical commits. Strategy:

| Scenario | Commits |
|----------|---------|
| All changes in 1-2 files | Single commit |
| Changes span 3+ files, all related | Single commit |
| Changes span multiple unrelated concerns | One commit per concern |
| Mix of suggestions and code changes | Group by concern, not by category |

Commit message format — follow the repo's convention detected from `git log --oneline -5`. If the repo uses conventional commits:

```
fix(scope): address PR #{number} review feedback

- {description of change 1}
- {description of change 2}
```

Push to remote:

```bash
git push
```

**If push fails due to diverged branch:** inform the user. Do NOT force-push. Let user decide.

## Step 7: Summary

Present a report:

```
## PR #{number} — Review Comments

### Resolved ({count}/{total})
- {path}:{line} — {category}: {brief description}
  Reply: "{response summary}"

### Replied via PR Comment ({count})
{if any threads used the Tier 2 fallback, list them here}
- {path}:{line} — threaded reply unavailable, posted as PR comment
{if none, omit this section}

### Unresolved ({count})
- {path}:{line} — {reason not resolved}

### Commits
- {hash} — {message}
```

## Error Handling

| Error | Action |
|-------|--------|
| `gh` not authenticated | Inform user to run `gh auth login`. Stop. |
| PR not found | Verify the PR number and repo. Report error. Stop. |
| No unresolved threads | Inform user all feedback is addressed. Stop. |
| `get-pr-comments.sh` fails | Fall back to REST: `gh api repos/{owner}/{repo}/pulls/{number}/comments`. Lose thread resolution data but can still categorize and fix. |
| Large output (>25KB) | Script auto-writes to `/tmp/pr-comments-{owner}-{repo}-{pr}.json`. Use the Read tool on that path. |
| Thread resolution fails | Report the error. The reply was still posted. Continue with remaining threads. |
| Reply fails | Try Tier 2 fallback (PR comment referencing original thread). If both tiers fail, report the error and log the intended response. Continue with remaining threads. |
| Edit fails (file not found) | The file may have been renamed or deleted. Report to user. Skip thread. |
| Push fails | Report the error. Do NOT force-push. Let user decide. |
| Merge conflict after edits | Report conflicting files. Let user resolve manually. |
| Line numbers outdated | If comment is marked `outdated`, inform user the code has changed since the review. Read the file and attempt to find the relevant code by context. |
