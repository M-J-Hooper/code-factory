---
name: pr-ready
description: >
  Use when the user wants to get a PR to a ready state by fixing CI failures
  and addressing automated review feedback. Works on the current branch's open PR.
  Triggers: "pr ready", "fix ci", "fix checks", "fix review comments", "get pr green".
argument-hint: "[optional PR number]"
user-invocable: true
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob, Edit, Write
---

# PR Ready

Announce: "I'm using the pr-ready skill to get this PR passing CI and review."

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

## Step 2: Integrate Latest Changes from Base Branch

Ensure the branch is up to date with the PR's base branch to avoid stale CI results and merge conflicts.

### 2.1: Check Freshness

Fetch the latest remote state and determine if the branch is behind the base branch:

```bash
git fetch origin
gh pr view <pr-number> --json baseRefName -q '.baseRefName'
```

Check if the branch is behind:

```bash
git rev-list --count HEAD..origin/<base-branch>
```

If the count is **0**, the branch is up to date — skip to Step 3.

### 2.2: Choose Strategy — Merge or Rebase

Use a **merge** if either condition is true:
- The branch already contains merge commits (commits with more than one parent):
  ```bash
  git rev-list --merges origin/<base-branch>..HEAD
  ```
- Other open PRs target this branch (it's a shared integration branch):
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

## Step 3: CI Checks Loop

Wait for GitHub Actions checks to complete and fix any failures. Maximum **3 iterations**.

### 3.1: Wait for Checks

Wait for all PR checks to finish:

```bash
gh pr checks <pr-number> --watch --fail-fast
```

If all checks pass, the skill is done — report success to the user.

### 3.2: Identify Failures

If any checks failed, list them:

```bash
gh pr checks <pr-number>
```

For each failed check, fetch its logs:

```bash
gh run view <run-id> --log-failed
```

If the log output is too large, narrow to the specific failed job:

```bash
gh run view <run-id> --log-failed --job <job-id>
```

Parse the logs to identify the root cause of each failure. Classify each failure:

| Category | Examples | Action |
|----------|----------|--------|
| **Fixable** | Test failures, lint errors, type errors, formatting, build errors from code in this PR | Fix it |
| **Flaky** | Intermittent network timeouts, rate limits, unrelated test flaking on code not in this PR | Re-run the job |
| **Infrastructure** | Runner unavailable, Docker pull failures, permission errors | Report to user and stop |

### 3.3: Fix Issues

For each fixable failure:
1. Read the referenced file(s) and understand the failure in context.
2. Make the fix using Edit or Write tools.
3. Track which failure maps to which fix.

**If a failure can't be fixed** (infrastructure issue, flaky test outside PR scope, or unclear root cause): note it for reporting.

### 3.4: Re-run Flaky Jobs

For failures classified as flaky, re-run just the failed jobs:

```bash
gh run rerun <run-id> --failed
```

### 3.5: Commit and Push

If any code fixes were made, use `/commit` to create an atomic commit for the fixes, then push:

```bash
git push
```

This triggers a new round of checks.

### 3.6: Loop or Exit

After pushing fixes (or re-running flaky jobs):
- Go back to step 3.1 to wait for the new check run.
- If the iteration limit (3) has been reached, report remaining failures to the user and exit.

Exit the loop when:
- All checks pass.
- The iteration limit is reached.
- Only infrastructure failures remain (report to user and stop).

## Error Handling

- **No open PR for branch**: inform the user and stop.
- **`gh` not installed or not authenticated**: inform the user to install and authenticate the `gh` CLI. Stop.
- **CI checks loop limit reached**: after 3 iterations, report remaining failures to the user and stop the loop.
- **Infrastructure CI failure**: if a check fails due to runner/infrastructure issues rather than code, report to the user and stop the CI loop.
- **Merge conflict unresolvable**: if a conflict during merge or rebase cannot be confidently resolved, abort (`git merge --abort` or `git rebase --abort`), report the conflict to the user, and stop.
- **Push failure**: report the push error. Do NOT force-push (except `--force-with-lease` after a rebase in Step 2). Let the user decide how to proceed.
- **Network or API failure**: report the error from `gh`. Let the user retry.
