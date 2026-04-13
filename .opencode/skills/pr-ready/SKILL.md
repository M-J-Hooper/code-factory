---
name: pr-ready
description: >
  Use when the user wants to get a PR to a ready state by fixing CI failures,
  addressing review feedback, resolving review threads, or responding to code review suggestions.
  Supports --auto for bot/CI automation and --auto-human for fully autonomous mode.
  Triggers: "pr ready", "fix ci", "fix checks", "get pr green",
  "fix pr feedback", "address review feedback", "handle pr feedback".
argument-hint: "[PR number, URL, or comment URL, optional --reviewer <name>, optional --auto, optional --auto-human]"
user-invocable: true
allowed-tools: Bash(git:*), Bash(gh:*), Bash(get_ddci_logs.sh:*), Bash(./scripts/*), Read, Write, Edit, Grep, Glob, AskUserQuestion, Task
---

# PR Ready

Announce: "I'm using the pr-ready skill to get this PR passing CI and review."

## Routing

| If you need... | Use instead |
|----------------|-------------|
| Review a PR and produce feedback | `/review` — read-only analysis with structured findings |
| Get a PR green (review feedback + CI + automated reviews) | `/pr-ready` — you're here |
| Address review comments only (no CI loop) | `/fix-comments` — review comment handling |
| Resolve merge/rebase/cherry-pick conflicts only | `/fix-conflicts` — standalone conflict resolution |

## Step 1: Identify the PR

If `$ARGUMENTS` provides a PR number, use it. Otherwise, detect the PR for the current branch:

```bash
gh pr view --json number,url -q '.number'
```

Also fetch the repo identifier:

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

**If no open PR exists for this branch:** inform the user and stop.

## Step 2: Fix Conflicts

Check if the PR has merge conflicts:

```bash
gh pr view {number} --json mergeable -q '.mergeable'
```

**If `CONFLICTING`:** invoke `/fix-conflicts`, then push the resolved merge commit.

**Otherwise:** skip to Step 3.

## Step 3: Fix Review Comments

Invoke `/fix-comments` with the PR number from Step 1 (pass through `--reviewer` and `--auto-human` flags if provided). This fetches pending review threads, applies fixes, replies, and pushes.

## Step 4: CI Validation + Automated Reviews

**This step ALWAYS runs** — even when `/fix-comments` found no review threads.

**Sequencing rule:** Steps 4a → 4b → 4c execute in order. Each substep has its own prompt.
Do NOT combine them into a single question.
Do NOT skip 4b or 4c after completing 4a.
Do NOT write a summary or "Next Steps" until ALL three substeps have completed.

Capture context for CI failure classification:

```bash
gh pr view {number} --json baseRefName
git diff --name-only origin/{base}...HEAD
```

Save the changed-files list for classifying CI failures as PR-related vs pre-existing.

### 4a: Trigger Automated Reviews (if stale)

Check if new commits exist since the last codex comments:

```bash
# Get the latest bot comment timestamp
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '[.[] | select(.user.login | test("codex"; "i")) | .created_at] | sort | last'

# Get the latest commit timestamp on the PR branch
gh api repos/{owner}/{repo}/pulls/{number}/commits \
  --jq '[.[].commit.committer.date] | sort | last'
```

Compare timestamps. If the latest commit is **after** the latest bot comment (or no bot comments exist), reviews are stale.

**If reviews are current:** skip to 4b — no re-trigger needed.

**If `--auto` mode:** Trigger immediately (no prompt).

**Interactive mode:**

<interaction>
AskUserQuestion(
  header: "Re-trigger automated reviews?",
  question: "There are new commits since the last Codex reviews. Re-trigger them?",
  options: [
    "Yes — review and fix" — Trigger reviewers, fix actionable feedback after CI (max 3 iterations),
    "Just trigger" — Post review comments but do not auto-fix,
    "No" — Skip automated reviews
  ]
)
</interaction>

If triggering: post `@codex` comment now per [references/automated-review-loop.md](references/automated-review-loop.md) Phase 1. **Do NOT wait here** — bots review in background while CI runs in 4b. Step 4c will poll and wait for their responses.

**After 4a completes → proceed to 4b.** Do not skip, summarize, or exit.

### 4b: CI Validation Loop

**If `--auto` mode:** Proceed with "Yes — watch and fix" (no prompt).

**Interactive mode:**

<interaction>
AskUserQuestion(
  header: "Watch CI?",
  question: "Want me to watch CI and auto-fix any failures?",
  options: [
    "Yes — watch and fix" — Monitor CI, analyze failures, apply fixes, and loop until green (max 3 iterations),
    "Just watch" — Monitor CI and report results without auto-fixing,
    "No" — Skip CI monitoring
  ]
)
</interaction>

**If "No":** skip to 4c.

Follow the CI validation loop in [references/ci-validation-loop.md](references/ci-validation-loop.md).

- **"Yes — watch and fix"**: full loop — wait for CI, analyze failures, fix, commit, push, recheck (max 3 iterations).
- **"Just watch"**: wait for CI to complete and report results. No fixes applied.

**After 4b completes → proceed to 4c if reviews were triggered in 4a.** Do not skip, summarize, or exit.

### 4c: Process Automated Review Feedback

If bot reviews were triggered in 4a, **you MUST wait for their responses before reporting results**. Do NOT assume reviews are already complete — CI may have finished quickly (or was already green), leaving insufficient time for bots to respond.

Follow [references/automated-review-loop.md](references/automated-review-loop.md) starting from **Phase 2** (Phase 1 trigger already done in 4a). Phase 2 polls for responses with a 15-minute timeout per reviewer — this polling is mandatory, not optional.

- **"Yes — review and fix"**: wait for responses, fix actionable feedback, commit, push, re-trigger (max 3 iterations).
- **"Just trigger"**: wait for responses and report. No fixes applied.
- **If reviews were not triggered in 4a:** skip this substep.

Append both the CI loop and review loop reports to the Step 5 summary.

**After 4c completes → proceed to Step 5.** The summary is the ONLY place to report final status and next steps.

## Step 5: Summary

Present the final report:

```
## PR #{number} — Ready for Review

### Review Feedback
{summary from /fix-comments — threads resolved, replied, unresolved}

### CI Validation
{if CI loop ran, include the report from references/ci-validation-loop.md Phase 5}
{if CI loop skipped, omit this section}

### Automated Review
{if review loop ran, include the report from references/automated-review-loop.md Phase 8}
{if review loop skipped, omit this section}

### Next Steps
- {if all resolved and CI green}: Ready for re-review
- {if unresolved remain}: {count} threads need follow-up
- {if CI failures remain}: {count} CI failures need investigation
```

**Offer to request re-review** if all threads are resolved:

```bash
gh pr edit {number} --add-reviewer {reviewer1},{reviewer2}
```

## Error Handling

| Error | Action |
|-------|--------|
| No open PR for branch | Inform the user and stop. |
| `gh` not installed or not authenticated | Inform the user to install and authenticate the `gh` CLI. Stop. |
| `/fix-conflicts` or `/fix-comments` fails | Report the error. Proceed to Step 4 (CI loop) anyway — CI validation is independent. |
| CI check timeout | If `gh pr checks --watch` hangs beyond 20 min, fall back to polling. Report timeout to user. |
| CI fix loop exceeds 3 iterations | Stop. Report remaining failures with log excerpts. Let user investigate. |
| Same CI failure recurs after fix | Mark as unfixable. Do NOT retry the same fix. Report to user. |
| DDCI logs unavailable | Skip log analysis. Report the Mosaic URL for manual investigation. |
| Codex not configured | If no review appears after 15-min timeout, skip that reviewer. Continue with others. |
| Automated review loop exceeds 3 iterations | Stop. Report remaining review comments. Let user investigate. |
| Push failure | Report the push error. Do NOT force-push. Let the user decide. |
| Network or API failure | Report the error from `gh`. Let the user retry. |
