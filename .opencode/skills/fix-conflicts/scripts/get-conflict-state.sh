#!/usr/bin/env bash
# Outputs conflict state: operation type, conflicted files with types, and branch context.
# Handles regular repos and worktrees (where .git is a file pointing to a gitdir).

set -euo pipefail

git_dir=$(git rev-parse --git-dir 2>/dev/null) || { echo "Not a git repository"; exit 1; }

# Detect operation type
detect_operation() {
  if [ -f "$git_dir/MERGE_HEAD" ]; then echo "merge"
  elif [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then echo "rebase"
  elif [ -f "$git_dir/REVERT_HEAD" ]; then echo "revert"
  elif [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then echo "cherry-pick"
  else echo "none"
  fi
}

operation=$(detect_operation)
echo "=== Operation: $operation ==="

echo ""
echo "=== Conflicted Files ==="
# Porcelain v2: unmerged entries start with "u", field $2=type, last field=path
conflicts=$(git status --porcelain=v2 2>/dev/null | awk '/^u / {type=$2; path=""; for(i=11;i<=NF;i++) path=(path?path" ":"")$i; print type, path}')
if [ -n "$conflicts" ]; then
  echo "$conflicts"
else
  echo "(none)"
fi

echo ""
echo "=== Context ==="
case "$operation" in
  merge)
    echo "Local: HEAD ($(git rev-parse --short HEAD))"
    echo "Remote: MERGE_HEAD ($(git rev-parse --short MERGE_HEAD))"
    base=$(git merge-base HEAD MERGE_HEAD 2>/dev/null || true)
    [ -n "$base" ] && echo "Base: $(git rev-parse --short "$base")"
    ;;
  rebase)
    if [ -d "$git_dir/rebase-merge" ]; then
      [ -f "$git_dir/rebase-merge/head-name" ] && echo "Branch: $(cat "$git_dir/rebase-merge/head-name")"
      [ -f "$git_dir/rebase-merge/onto" ] && echo "Onto: $(git rev-parse --short "$(cat "$git_dir/rebase-merge/onto")")"
    elif [ -d "$git_dir/rebase-apply" ]; then
      [ -f "$git_dir/rebase-apply/head-name" ] && echo "Branch: $(cat "$git_dir/rebase-apply/head-name")"
      [ -f "$git_dir/rebase-apply/onto" ] && echo "Onto: $(git rev-parse --short "$(cat "$git_dir/rebase-apply/onto")")"
    fi
    ;;
  revert)
    echo "Reverting: $(git rev-parse --short REVERT_HEAD)"
    ;;
  cherry-pick)
    echo "Cherry-picking: $(git rev-parse --short CHERRY_PICK_HEAD)"
    ;;
  none)
    echo "(no operation in progress)"
    ;;
esac
