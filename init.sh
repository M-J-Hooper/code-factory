#!/usr/bin/env bash
#
# init.sh -- Symlink code-factory configuration files into the user's home directory.
#
# This script creates symlinks for the following files:
#   mcp.json        -> ~/.mcp.json                      (MCP server configuration)
#   settings.json   -> ~/.claude/settings.json           (Claude Code global settings)
#   opencode.jsonc  -> ~/.config/opencode/opencode.jsonc (OpenCode CLI configuration)
#
# Behavior:
#   - If the destination is an existing symlink, it is removed and re-created.
#   - If the destination is a regular file, it is skipped with a warning.
#     To use the symlink, back up or remove the existing file manually.
#   - If the destination does not exist, the symlink is created.
#   - Parent directories are created as needed (e.g., ~/.claude/, ~/.config/opencode/).
#
# This script is idempotent: running it multiple times produces the same result.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SRCS=(
    "$SCRIPT_DIR/mcp.json"
    "$SCRIPT_DIR/settings.json"
    "$SCRIPT_DIR/opencode.jsonc"
)
DESTS=(
    "$HOME/.mcp.json"
    "$HOME/.claude/settings.json"
    "$HOME/.config/opencode/opencode.jsonc"
)

for i in "${!SRCS[@]}"; do
    src="${SRCS[$i]}"
    dest="${DESTS[$i]}"
    
    if [[ ! -f "$src" ]]; then
        echo "SKIP  $src (source file not found)"
        continue
    fi
    
    mkdir -p "$(dirname "$dest")"
    
    if [[ -L "$dest" ]]; then
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        echo "WARN  $dest already exists as a regular file, skipping"
        continue
    fi
    
    ln -s "$src" "$dest"
    echo "LINK  $dest -> $src"
done

# Sync skills and agents to OpenCode global paths
echo ""
echo "Syncing skills and agents to OpenCode..."
"$SCRIPT_DIR/sync-opencode.sh"

# Install pre-commit hook
HOOK_SRC="$SCRIPT_DIR/.githooks/pre-commit"
HOOK_DEST="$SCRIPT_DIR/.git/hooks/pre-commit"
if [[ -f "$HOOK_SRC" ]]; then
    if [[ -L "$HOOK_DEST" ]]; then
        rm "$HOOK_DEST"
    elif [[ -e "$HOOK_DEST" ]]; then
        echo "WARN  $HOOK_DEST already exists as a regular file, skipping"
    fi
    if [[ ! -e "$HOOK_DEST" ]]; then
        ln -s "$HOOK_SRC" "$HOOK_DEST"
        echo "LINK  $HOOK_DEST -> $HOOK_SRC"
    fi
fi
