---
name: pr-fix
description: >
  Use when the user wants to fix merge conflicts, address code review comments,
  or resolve review feedback on an open PR. Also invoked by /pr-ready before CI loops.
  Triggers: "fix conflicts", "resolve conflicts", "fix review comments", "address feedback",
  "reply to comments", "pr fix".
argument-hint: "[optional PR number]"
user-invocable: true
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Edit, Write
---

# PR Fix

Announce: "I'm using the pr-fix skill to resolve conflicts and address review feedback on this PR."

## Step 1: Identify the PR

If `$ARGUMENTS` provides a PR number, use it. Otherwise, detect the PR for the current branch:

```bash
gh pr view --json number,url,baseRefName -q '{number: .number, base: .baseRefName}'
```

Also fetch the repo identifier:

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

**If no open PR exists for this branch:** inform the user and stop.

## Step 2: Integrate Latest Changes from Base Branch

Ensure the branch is up to date with the base branch to avoid stale conflicts.

### 2.1: Check Freshness

```bash
git fetch origin
git rev-list --count HEAD..origin/<base-branch>
```

If the count is **0**, the branch is up to date — skip to Step 3.

### 2.2: Choose Strategy — Merge or Rebase

Use a **merge** if either condition is true:
- The branch already contains merge commits:
  ```bash
  git rev-list --merges origin/<base-branch>..HEAD
  ```
- Other open PRs target this branch:
  ```bash
  gh pr list --base <current-branch> --state open --json number -q 'length'
  ```

Otherwise, use a **rebase**.

### 2.3: Integrate

**If merging:**

```bash
git merge origin/<base-branch>
```

If there are conflicts, resolve them by reading the conflicting files, making the correct resolution using Edit, then staging and completing the merge:

```bash
git add <resolved-files>
git merge --continue
```

**If rebasing:**

```bash
git rebase origin/<base-branch>
```

If there are conflicts, resolve them one commit at a time — read the conflicting files, fix with Edit, then continue:

```bash
git add <resolved-files>
git rebase --continue
```

Repeat until the rebase completes.

### 2.4: Push

After integrating:

```bash
git push
```

If a rebase was used and the push is rejected, force-push with lease:

```bash
git push --force-with-lease
```

## Step 3: Address Review Comments

Fetch all pending review comments on the PR:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments --paginate -q '.[] | select(.position != null) | {id: .id, path: .path, line: .line, body: .body, in_reply_to_id: .in_reply_to_id}'
```

Also fetch review threads to identify unresolved conversations:

```bash
gh pr view <pr-number> --json reviewDecision,reviews,comments
```

**If there are no pending review comments:** skip to Step 4.

### 3.1: Categorize Comments

For each review comment, classify it:

| Category | Examples | Action |
|----------|----------|--------|
| **Actionable** | Bug fix requests, style changes, missing error handling, naming suggestions | Fix the code |
| **Question** | "Why did you choose X?", "Is this intentional?" | Reply with explanation |
| **Nit** | Minor style preferences, optional improvements | Fix if trivial, otherwise reply acknowledging |
| **Resolved** | Already addressed or no longer applicable | Reply noting resolution |

### 3.2: Fix Code Issues

For each actionable comment:

1. Read the referenced file and understand the comment in context.
2. Make the fix using Edit.
3. Track which comment maps to which fix.

Group related fixes together — if multiple comments touch the same file or concern, address them in one pass.

### 3.3: Reply to Comments

After making fixes (or for non-actionable comments), reply to each comment thread:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments -X POST -f body="<reply>" -F in_reply_to=<comment-id>
```

Reply guidelines:

| Category | Reply format |
|----------|-------------|
| **Actionable (fixed)** | "Fixed." or "Fixed — {brief note on approach if non-obvious}." |
| **Question** | Direct answer to the question. |
| **Nit (fixed)** | "Fixed." |
| **Nit (skipped)** | "Acknowledged — skipping for now because {reason}." |
| **Resolved** | "This was already addressed in {commit/context}." |

Keep replies concise. Do not over-explain fixes that are visible in the diff.

All replies must end with `\n\n_Sent from my Claude_`.

### 3.4: Commit and Push

If any code fixes were made, use `/commit` to create an atomic commit, then push:

```bash
git push
```

## Step 4: Report

Summarize what was done:

- **Conflicts**: whether merge/rebase was needed and any conflicts resolved.
- **Comments addressed**: count of actionable fixes, questions answered, nits handled.
- **Remaining**: any comments that could not be addressed (ambiguous, out of scope, require user input).

## Error Handling

| Error | Action |
|-------|--------|
| No open PR for branch | Inform the user and stop. |
| `gh` not installed or not authenticated | Inform the user to install and authenticate the `gh` CLI. Stop. |
| Merge conflict unresolvable | Abort (`git merge --abort` or `git rebase --abort`), report the conflict to the user, and stop. |
| Push failure | Report the push error. Do NOT force-push (except `--force-with-lease` after a rebase). Let the user decide. |
| Review comment ambiguous | Reply asking for clarification, note it in the report as remaining. |
| API rate limit | Report to user and stop. |
| Network or API failure | Report the error from `gh`. Let the user retry. |
