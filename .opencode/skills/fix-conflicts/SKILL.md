---
name: fix-conflicts
description: >
  Use when git reports merge conflicts, rebase conflicts, cherry-pick conflicts,
  or revert conflicts, or when the user asks to resolve conflicts.
  Triggers: "fix conflicts", "resolve conflicts", "merge conflicts", "rebase conflicts",
  "fix merge", "resolve merge", "help with conflicts", "conflict markers".
argument-hint: "[optional: specific file to resolve]"
user-invocable: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/fix-conflicts/scripts/*), Bash(git add:*), Bash(git rm:*), Bash(git show:*), Bash(git blame:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Read, Edit, Grep, Glob, AskUserQuestion
---

# Fix Conflicts

Announce: "I'm using the fix-conflicts skill to resolve merge conflicts."

## Step 1: Detect Conflict State

Run the conflict state detector:

```bash
${CLAUDE_PLUGIN_ROOT}/skills/fix-conflicts/scripts/get-conflict-state.sh
```

The output shows the operation type (merge, rebase, revert, cherry-pick), conflicted files with their conflict types, and branch context.

**If Operation is "none" and no conflicted files:** inform the user there are no conflicts to resolve and stop.

**If `$ARGUMENTS` specifies a file:** limit resolution scope to that file only (verify it appears in the conflicted list).

## Step 2: Read Conflicted Files

Read every conflicted file listed in Step 1. For large files (>500 lines), focus on sections containing conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).

Then gather history context to understand what each side intended:

```bash
# Local commits that touched conflicted files
${CLAUDE_PLUGIN_ROOT}/skills/fix-conflicts/scripts/get-conflict-history.sh local

# Remote commits that touched conflicted files
${CLAUDE_PLUGIN_ROOT}/skills/fix-conflicts/scripts/get-conflict-history.sh remote
```

For each conflict, determine:

| Question | How to answer |
|----------|---------------|
| What did the local side change? | Read local history commits, inspect code between `<<<<<<< HEAD` and `=======` |
| What did the remote side change? | Read remote history commits, inspect code between `=======` and `>>>>>>>` |
| Are changes independent? | Different logical concerns = keep both |
| Are changes contradictory? | Same logic changed differently = need judgment |

## Step 3: Resolve by Conflict Type

**Rebase ours/theirs warning:** During `git rebase`, ours/theirs are reversed from merge. `HEAD` (ours) = the branch being rebased **onto** (e.g., main), and theirs = the commits being replayed (your feature branch). The conflict markers reflect this: `<<<<<<< HEAD` shows the upstream code during rebase.

### Standard conflicts (UU — both modified, AA — both added)

1. Understand intent of both sides from history and surrounding code.
2. Choose resolution strategy:

| Situation | Strategy |
|-----------|----------|
| Changes are independent (different functions, different lines) | Merge both — keep all changes |
| Changes overlap but complement each other | Combine intelligently — integrate both intents |
| Changes contradict each other | Ask the user (see "When uncertain" below) |
| One side is strictly newer/better | Keep the better version |

3. Remove ALL conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
4. Verify the result is syntactically correct.

### Modify/delete conflicts (UD — modified locally/deleted remotely, DU — deleted locally/modified remotely)

1. Check history to understand why the file was deleted on one side.
2. Ask the user:

<interaction>
AskUserQuestion(
  header: "Keep or delete?",
  question: "<file> was modified on one side but deleted on the other. The modification: <brief description>. The deletion was in commit <sha>: <message>. Keep the modified version or delete?",
  options: [
    "Keep modified" -- Stage the modified version with git add,
    "Delete" -- Stage deletion with git rm
  ]
)
</interaction>

### Add conflicts (AU — added by us, UA — added by them)

1. Review the added file's content and purpose.
2. If keeping: `git add <file>`
3. If removing: `git rm <file>`
4. If both sides added with different content: treat as a standard UU conflict.

### When uncertain about any conflict

**Do NOT guess about business logic.** Ask the user:

<interaction>
AskUserQuestion(
  header: "Conflict choice",
  question: "Conflict in <file>: <brief description of both sides>. How should this be resolved?",
  options: [
    "Keep local (ours)" -- Use the local/HEAD version,
    "Keep remote (theirs)" -- Use the incoming version,
    "Merge both" -- Combine changes from both sides,
    "Leave unresolved" -- Skip this file for manual resolution
  ]
)
</interaction>

### Special cases

| File type | Resolution approach |
|-----------|-------------------|
| **Lock files** (package-lock.json, pnpm-lock.yaml, yarn.lock, Gemfile.lock, go.sum) | Accept either version, then regenerate: delete the lock file, run the package manager install, stage the new lock file |
| **Generated files** (.pb.go, .generated.ts, compiled assets) | Accept either version, then regenerate using the project's build command |
| **Import conflicts** | Keep both imports, remove duplicates, respect project ordering conventions |
| **Formatting-only conflicts** | Apply project formatting conventions consistently |

## Step 4: Stage Resolved Files

After resolving each file:

```bash
# For kept/merged files
git add <file>

# For deleted files
git rm <file>
```

## Step 5: Verify Resolution

Run in parallel:

```bash
# Confirm no conflict markers remain in the entire repo
git diff --check

# Verify all conflicts are resolved (should show no unmerged paths)
git status
```

**If conflict markers remain:** go back to Step 3 for the affected files.

**If the project has a type checker or linter available:** run it to catch semantic conflicts (code that merges cleanly but is logically broken — e.g., a function signature changed on one side while the other side calls it with old arguments).

## Step 6: Report Results

Provide a summary:

```
Resolved N conflict(s):
- <file1>: <brief resolution description>
- <file2>: <brief resolution description>

Unresolved (if any):
- <file3>: left for manual resolution

To continue:
  merge:       git merge --continue
  rebase:      git rebase --continue
  cherry-pick: git cherry-pick --continue
  revert:      git revert --continue
```

### DO NOT Continue the Operation

**NEVER** automatically run `git merge --continue`, `git rebase --continue`, `git cherry-pick --continue`, `git revert --continue`, or `git commit` after resolving conflicts.

The user must review the resolutions and continue the operation manually.

| Rationalization | Reality |
|----------------|---------|
| "All conflicts are resolved, so it's safe to continue" | The user may want to review resolutions, run tests, or abort |
| "The user asked me to fix conflicts, which implies continuing" | Fixing conflicts and continuing the operation are separate actions |
| "It saves the user a step" | An unwanted merge commit or rebase is harder to undo than typing one command |

## Error Handling

| Error | Action |
|-------|--------|
| Not a git repository | Inform the user and stop |
| No conflicts detected | Inform the user there are no conflicts to resolve. Stop. |
| Conflict state script fails | Fall back to `git status` and `git diff --name-only --diff-filter=U` for manual detection |
| File too large to read | Focus on conflict marker sections using Grep to find `<<<<<<<` line numbers, then Read with offset/limit |
| Semantic conflict (compiles but logically wrong) | Flag the risk to the user: "These files merged cleanly but may have semantic conflicts — recommend running tests" |
| Lock file regeneration fails | Report the error. Suggest the user run the package manager manually. |
| User chooses "Leave unresolved" | Track the file and include it in the unresolved list in Step 6 |
