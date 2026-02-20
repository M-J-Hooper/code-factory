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

## Step 2: CI Checks Loop

Wait for GitHub Actions checks to complete and fix any failures. Maximum **3 iterations**.

### 2.1: Wait for Checks

Wait for all PR checks to finish:

```bash
gh pr checks <pr-number> --watch --fail-fast
```

If all checks pass, skip to Step 3.

### 2.2: Identify Failures

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

### 2.3: Fix Issues

For each fixable failure:
1. Read the referenced file(s) and understand the failure in context.
2. Make the fix using Edit or Write tools.
3. Track which failure maps to which fix.

**If a failure can't be fixed** (infrastructure issue, flaky test outside PR scope, or unclear root cause): note it for reporting.

### 2.4: Re-run Flaky Jobs

For failures classified as flaky, re-run just the failed jobs:

```bash
gh run rerun <run-id> --failed
```

### 2.5: Commit and Push

If any code fixes were made, use `/commit` to create an atomic commit for the fixes, then push:

```bash
git push
```

This triggers a new round of checks.

### 2.6: Loop or Exit

After pushing fixes (or re-running flaky jobs):
- Go back to step 2.1 to wait for the new check run.
- If the iteration limit (3) has been reached, report remaining failures to the user and exit.

Exit the loop when:
- All checks pass.
- The iteration limit is reached.
- Only infrastructure failures remain (report to user and stop).

## Step 3: Automated Review Loop

After CI checks pass, trigger a Greptile review cycle. Maximum **3 iterations**.

### 3.1: Trigger Review

Comment on the PR to invoke Greptile:

```bash
gh pr comment <pr-number> --body "@greptileai review"
```

### 3.2: Wait for Review

Poll for Greptile's review. First, record the current review count so you can detect a new one:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/reviews
```

Poll every 30 seconds, checking for a new review from a Greptile bot account (username containing `greptile`). Timeout after 5 minutes.

**If timeout is reached:** inform the user that Greptile may not be configured on this repository and stop the loop.

### 3.3: Read Review Comments

Fetch all review comments:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments
```

Filter to comments from the Greptile bot account that are unresolved. Parse each comment for:
- File path
- Line number / diff position
- Issue description

**Skip non-actionable comments:** ignore comments that are purely informational, praise, or summaries. Only act on comments that identify concrete issues to fix.

If there are **no actionable comments**, the review is clean — exit the loop and report success to the user.

### 3.4: Fix Issues

For each actionable comment:
1. Read the referenced file and understand the issue in context.
2. Make the fix using Edit or Write tools.
3. Track which comment maps to which fix.

**If a comment can't be addressed** (ambiguous, requires architectural changes, or is outside the PR scope): note it for the reply step — do not attempt a fix.

### 3.5: Commit and Push

Use `/commit` to create an atomic commit for the fixes, then push:

```bash
git push
```

### 3.6: Reply and Resolve

For each addressed comment, reply using:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments/<comment-id>/replies -f body="<response>"
```

**Every reply must start with** `*Automated response from Claude:*` to clearly indicate it was not written by the user.

- For fixed comments: reply explaining the fix, then resolve the thread.
- For comments that could not be addressed: reply explaining why (e.g. "This requires an architectural change outside the scope of this PR") and **leave the thread unresolved**.

### 3.7: Loop or Exit

After pushing fixes and replying to comments:
- If the iteration limit (3) has been reached, report any remaining unresolved comments to the user and exit.
- Otherwise, go back to step 3.1 to trigger a new review.

Exit the loop when:
- Greptile's review has no new actionable comments.
- The review is approved.
- The iteration limit is reached.

## Error Handling

- **No open PR for branch**: inform the user and stop.
- **`gh` not installed or not authenticated**: inform the user to install and authenticate the `gh` CLI. Stop.
- **CI checks loop limit reached**: after 3 iterations, report remaining failures to the user and stop the loop.
- **Infrastructure CI failure**: if a check fails due to runner/infrastructure issues rather than code, report to the user and stop the CI loop. Proceed to Step 3 (Greptile review) anyway.
- **Greptile not installed on repo**: if no review appears after the 5-minute timeout, inform the user that Greptile may not be configured and stop the review loop.
- **Review loop limit reached**: after 3 iterations, report remaining unresolved comments to the user and stop the loop.
- **Push failure**: report the push error. Do NOT force-push. Let the user decide how to proceed.
- **Network or API failure**: report the error from `gh`. Let the user retry.
