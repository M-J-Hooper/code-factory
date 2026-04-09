#!/usr/bin/env bash
#
# init.sh -- Bootstrap code-factory: symlink configs and install OpenCode assets globally.
#
# This script:
#   1. Installs rtk (Rust Token Killer) via cargo if not already present.
#   2. Symlinks configuration files into the user's home directory.
#   3. Syncs MCP servers into Claude Code.
#   4. Symlinks Claude Code hooks, rules, and git hooks.
#   5. Runs sync-opencode.sh to generate OpenCode assets in the repo.
#   6. Symlinks .opencode/{skills,agents,commands} into ~/.config/opencode/.
#   7. Updates Claude Code CLI and all installed marketplace plugins.
#
# Behavior:
#   - If the destination is an existing symlink, it is removed and re-created.
#   - If the destination is a regular file, the script records an error.
#     To fix, back up or remove the existing file manually and re-run.
#   - If the destination does not exist, the symlink is created.
#   - Parent directories are created as needed (e.g., ~/.claude/, ~/.config/opencode/).
#   - The script exits non-zero if any file fails to link, with a summary at the end.
#
# This script is idempotent: running it multiple times produces the same result.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

errors=()

# Install or update rtk (Rust Token Killer) via cargo
echo "Checking rtk installation..."
if ! command -v cargo &>/dev/null; then
    case "$(uname -s)" in
        Linux)
            echo "  Installing Rust via rustup..."
            if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1; then
                # Source cargo env so cargo is available in this session
                . "$HOME/.cargo/env"
                echo "  OK  cargo installed ($(cargo --version))"
            else
                errors+=("rtk: rustup installation failed")
                echo "  FAIL  rustup installation failed"
            fi
            ;;
        *)
            errors+=("rtk: cargo not found, install Rust toolchain first (https://rustup.rs)")
            echo "FAIL  rtk requires cargo (install Rust via https://rustup.rs)"
            ;;
    esac
fi

if command -v cargo &>/dev/null; then
    if command -v rtk &>/dev/null && rtk gain &>/dev/null; then
        echo "  OK  rtk already installed ($(rtk --version 2>/dev/null || echo 'unknown version'))"
        echo "  Checking for updates..."
    else
        echo "  Installing rtk via cargo..."
    fi
    if cargo install --git https://github.com/rtk-ai/rtk --config net.git-fetch-with-cli=true 2>&1; then
        echo "  OK  rtk up-to-date ($(rtk --version 2>/dev/null || echo 'unknown version'))"
    else
        errors+=("rtk: cargo install failed")
        echo "FAIL  rtk installation failed"
    fi
fi
echo ""

# Install Node.js if not available (required by statusLine npx command and hooks)
echo "Checking Node.js installation..."
if command -v node &>/dev/null; then
    echo "  OK  node already installed ($(node --version))"
else
    case "$(uname -s)" in
        Linux)
            echo "  Installing Node.js..."
            ARCH=$(uname -m)
            NODE_ARCH=""
            case "$ARCH" in
                x86_64)  NODE_ARCH="x64" ;;
                aarch64) NODE_ARCH="arm64" ;;
                *)
                    errors+=("node: unsupported architecture $ARCH")
                    echo "  FAIL  unsupported architecture $ARCH"
                    ;;
            esac
            if [[ -n "$NODE_ARCH" ]]; then
                NODE_VERSION="v22.14.0"
                NODE_DIST="node-${NODE_VERSION}-linux-${NODE_ARCH}"
                TMP_DIR=$(mktemp -d)
                if curl -fsSL "https://nodejs.org/dist/${NODE_VERSION}/${NODE_DIST}.tar.xz" -o "$TMP_DIR/node.tar.xz"; then
                    tar -xJf "$TMP_DIR/node.tar.xz" -C "$TMP_DIR"
                    rm -rf "$HOME/.local/node"
                    mv "$TMP_DIR/$NODE_DIST" "$HOME/.local/node"
                    export PATH="$HOME/.local/node/bin:$PATH"
                    echo "  OK  node installed ($(node --version))"
                else
                    errors+=("node: download failed")
                    echo "  FAIL  node download failed"
                fi
                rm -rf "$TMP_DIR"
            fi
            ;;
        *)
            echo "  SKIP  node not found, install manually from https://nodejs.org"
            ;;
    esac
fi
echo ""

SRCS=(
    "$SCRIPT_DIR/settings.json"
    "$SCRIPT_DIR/CLAUDE.md"
    "$SCRIPT_DIR/opencode.jsonc"
)
DESTS=(
    "$HOME/.claude/settings.json"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.config/opencode/opencode.jsonc"
)

# In workspace mode, force-remove settings.json so linking always succeeds
# (workspaces may have a pre-existing regular file instead of a symlink)
if [[ "${IN_WORKSPACE:-}" == "1" ]]; then
    rm -f "$HOME/.claude/settings.json"
fi

for i in "${!SRCS[@]}"; do
    src="${SRCS[$i]}"
    dest="${DESTS[$i]}"

    if [[ ! -f "$src" ]]; then
        errors+=("$src -> $dest: source file not found")
        echo "FAIL  $src (source file not found)"
        continue
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        errors+=("$src -> $dest: destination already exists as a regular file")
        echo "FAIL  $dest already exists as a regular file, cannot link"
        continue
    fi

    if ! ln -s "$src" "$dest"; then
        errors+=("$src -> $dest: ln -s failed")
        echo "FAIL  could not link $dest -> $src"
        continue
    fi
    echo "LINK  $dest -> $src"
done

# Sync MCP servers: regenerate opencode.jsonc block + install into Claude Code
echo ""
echo "Syncing MCP servers..."
"$SCRIPT_DIR/sync-mcp.sh"

echo ""
echo "Installing MCP servers into Claude Code (user scope)..."

# Clean up stale ~/.mcp.json symlink from old approach
if [[ -L "$HOME/.mcp.json" ]]; then
    rm "$HOME/.mcp.json"
    echo "  Removed stale ~/.mcp.json symlink"
fi

mcp_server_names=$(python3 -c "
import json
data = json.load(open('$SCRIPT_DIR/mcp.json'))
for name in data.get('mcpServers', {}):
    print(name)
")

for name in $mcp_server_names; do
    config=$(python3 -c "
import json
data = json.load(open('$SCRIPT_DIR/mcp.json'))
print(json.dumps(data['mcpServers']['$name']))
")
    # Remove existing (ignore errors if not present)
    claude mcp remove "$name" 2>/dev/null || true
    # Add with user scope
    if claude mcp add-json -s user "$name" "$config" 2>&1; then
        echo "  OK  $name"
    else
        errors+=("mcp: failed to install $name")
        echo "  FAIL  $name"
    fi
done

# Symlink Claude Code hooks from hooks/ into ~/.claude/hooks/
echo ""
echo "Linking Claude Code hooks..."
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"
for hook_src in "$SCRIPT_DIR/hooks"/*; do
    [[ -f "$hook_src" ]] || continue
    hook_name=$(basename "$hook_src")
    hook_dest="$HOOKS_DIR/$hook_name"
    if [[ -L "$hook_dest" ]]; then
        rm "$hook_dest"
    elif [[ -e "$hook_dest" ]]; then
        errors+=("$hook_src -> $hook_dest: destination already exists as a regular file")
        echo "  FAIL  $hook_dest already exists as a regular file, cannot link"
        continue
    fi
    if ! ln -s "$hook_src" "$hook_dest"; then
        errors+=("$hook_src -> $hook_dest: ln -s failed")
        echo "  FAIL  could not link $hook_dest -> $hook_src"
    else
        echo "  LINK  $hook_dest -> $hook_src"
    fi
done

# Symlink Claude Code rules from rules/ into ~/.claude/rules/
echo ""
echo "Linking Claude Code rules..."
RULES_DIR="$HOME/.claude/rules"
mkdir -p "$RULES_DIR"
for rule_src in "$SCRIPT_DIR/rules"/*.md; do
    [[ -f "$rule_src" ]] || continue
    rule_name=$(basename "$rule_src")
    rule_dest="$RULES_DIR/$rule_name"
    if [[ -L "$rule_dest" ]]; then
        rm "$rule_dest"
    elif [[ -e "$rule_dest" ]]; then
        errors+=("$rule_src -> $rule_dest: destination already exists as a regular file")
        echo "  FAIL  $rule_dest already exists as a regular file, cannot link"
        continue
    fi
    if ! ln -s "$rule_src" "$rule_dest"; then
        errors+=("$rule_src -> $rule_dest: ln -s failed")
        echo "  FAIL  could not link $rule_dest -> $rule_src"
    else
        echo "  LINK  $rule_dest -> $rule_src"
    fi
done

# Generate OpenCode assets in the repo
echo ""
echo "Syncing skills, agents, and commands..."
"$SCRIPT_DIR/sync-opencode.sh"

# Propagate .opencode/{skills,agents,commands} to ~/.config/opencode/
echo ""
echo "Linking to ~/.config/opencode/..."

GLOBAL_DIR="$HOME/.config/opencode"
OPENCODE_DIR="$SCRIPT_DIR/.opencode"
MANIFEST="$GLOBAL_DIR/.code-factory-managed"

new_manifest=()

# Read old manifest for cleanup
old_manifest=()
if [[ -f "$MANIFEST" ]]; then
    while IFS= read -r line; do
        old_manifest+=("$line")
    done < "$MANIFEST"
fi

# Symlink each rule file
RULES_SRC_DIR="$SCRIPT_DIR/rules"
if [[ -d "$RULES_SRC_DIR" ]]; then
    mkdir -p "$GLOBAL_DIR/rules"
    for rule_src in "$RULES_SRC_DIR"/*.md; do
        [[ -f "$rule_src" ]] || continue
        rule_name=$(basename "$rule_src")
        rule_dest="$GLOBAL_DIR/rules/$rule_name"
        if ! ln -sf "$rule_src" "$rule_dest"; then
            errors+=("$rule_src -> $rule_dest: ln -sf failed")
            echo "  FAIL  rules/$rule_name"
        else
            new_manifest+=("$rule_dest")
            echo "  LINK  rules/$rule_name"
        fi
    done
fi

# Symlink each skill directory
if [[ -d "$OPENCODE_DIR/skills" ]]; then
    mkdir -p "$GLOBAL_DIR/skills"
    for skill_src in "$OPENCODE_DIR/skills"/*/; do
        [[ -d "$skill_src" ]] || continue
        skill_name=$(basename "$skill_src")
        skill_dest="$GLOBAL_DIR/skills/$skill_name"
        if ! ln -sfn "$skill_src" "$skill_dest"; then
            errors+=("$skill_src -> $skill_dest: ln -sfn failed")
            echo "  FAIL  skills/$skill_name/"
        else
            new_manifest+=("$skill_dest")
            echo "  LINK  skills/$skill_name/"
        fi
    done
fi

# Symlink agent, command, and plugin files
for subdir in agents commands plugins; do
    src_dir="$OPENCODE_DIR/$subdir"
    dest_dir="$GLOBAL_DIR/$subdir"
    [[ -d "$src_dir" ]] || continue
    mkdir -p "$dest_dir"

    while IFS= read -r src_file; do
        rel="${src_file#"$src_dir"/}"
        dest_file="$dest_dir/$rel"
        if ! ln -sf "$src_file" "$dest_file"; then
            errors+=("$src_file -> $dest_file: ln -sf failed")
            echo "  FAIL  $subdir/$rel"
        else
            new_manifest+=("$dest_file")
            echo "  LINK  $subdir/$rel"
        fi
    done < <(find "$src_dir" -type f \( -name "*.md" -o -name "*.ts" \) | sort)
done

# Manifest cleanup: remove stale global files
sorted_manifest=$(printf '%s\n' "${new_manifest[@]}" | sort)
cleaned=0
for old_file in "${old_manifest[@]+"${old_manifest[@]}"}"; do
    [[ -z "$old_file" ]] && continue
    if ! echo "$sorted_manifest" | grep -qxF "$old_file"; then
        if [[ -e "$old_file" || -L "$old_file" ]]; then
            rm -f "$old_file"
            echo "  CLEAN  $old_file"
            cleaned=$((cleaned + 1))
        fi
        parent=$(dirname "$old_file")
        rmdir "$parent" 2>/dev/null || true
    fi
done

# Write new manifest
echo "$sorted_manifest" > "$MANIFEST"

echo ""
echo "Linked ${#new_manifest[@]} files to ~/.config/opencode/. Cleaned $cleaned stale files."

# Generate Codex assets in the repo
echo ""
echo "Syncing Codex skills and agents..."
"$SCRIPT_DIR/sync-codex.sh"

# Propagate .codex/{skills,agents} to ~/.codex/
echo ""
echo "Linking to ~/.codex/..."

CODEX_GLOBAL_DIR="$HOME/.codex"
CODEX_LOCAL_DIR="$SCRIPT_DIR/.codex"
CODEX_MANIFEST="$CODEX_GLOBAL_DIR/.code-factory-managed"

codex_new_manifest=()

# Read old Codex manifest for cleanup
codex_old_manifest=()
if [[ -f "$CODEX_MANIFEST" ]]; then
    while IFS= read -r line; do
        codex_old_manifest+=("$line")
    done < "$CODEX_MANIFEST"
fi

# Symlink each Codex skill directory
if [[ -d "$CODEX_LOCAL_DIR/skills" ]]; then
    mkdir -p "$CODEX_GLOBAL_DIR/skills"
    for skill_src in "$CODEX_LOCAL_DIR/skills"/*/; do
        [[ -d "$skill_src" ]] || continue
        skill_name=$(basename "$skill_src")
        skill_dest="$CODEX_GLOBAL_DIR/skills/$skill_name"
        if ! ln -sfn "$skill_src" "$skill_dest"; then
            errors+=("$skill_src -> $skill_dest: ln -sfn failed")
            echo "  FAIL  skills/$skill_name/"
        else
            codex_new_manifest+=("$skill_dest")
            echo "  LINK  skills/$skill_name/"
        fi
    done
fi

# Symlink each Codex agent file
if [[ -d "$CODEX_LOCAL_DIR/agents" ]]; then
    mkdir -p "$CODEX_GLOBAL_DIR/agents"
    while IFS= read -r agent_src; do
        agent_name=$(basename "$agent_src")
        agent_dest="$CODEX_GLOBAL_DIR/agents/$agent_name"
        if ! ln -sf "$agent_src" "$agent_dest"; then
            errors+=("$agent_src -> $agent_dest: ln -sf failed")
            echo "  FAIL  agents/$agent_name"
        else
            codex_new_manifest+=("$agent_dest")
            echo "  LINK  agents/$agent_name"
        fi
    done < <(find "$CODEX_LOCAL_DIR/agents" -name "*.toml" | sort)
fi

# Codex manifest cleanup: remove stale global files
if [[ ${#codex_new_manifest[@]} -gt 0 ]]; then
    codex_sorted_manifest=$(printf '%s\n' "${codex_new_manifest[@]}" | sort)
else
    codex_sorted_manifest=""
fi
codex_cleaned=0
for old_file in "${codex_old_manifest[@]+"${codex_old_manifest[@]}"}"; do
    [[ -z "$old_file" ]] && continue
    if ! echo "$codex_sorted_manifest" | grep -qxF "$old_file"; then
        if [[ -e "$old_file" || -L "$old_file" ]]; then
            rm -f "$old_file"
            echo "  CLEAN  $old_file"
            codex_cleaned=$((codex_cleaned + 1))
        fi
        parent=$(dirname "$old_file")
        rmdir "$parent" 2>/dev/null || true
    fi
done

# Write new Codex manifest
if [[ -n "$codex_sorted_manifest" ]]; then
    echo "$codex_sorted_manifest" > "$CODEX_MANIFEST"
else
    : > "$CODEX_MANIFEST"
fi

echo ""
echo "Linked ${#codex_new_manifest[@]} entries to ~/.codex/. Cleaned $codex_cleaned stale entries."

# Install git hooks from .githooks/
for HOOK_SRC in "$SCRIPT_DIR/.githooks"/*; do
    [[ -f "$HOOK_SRC" ]] || continue
    HOOK_NAME=$(basename "$HOOK_SRC")
    HOOK_DEST="$SCRIPT_DIR/.git/hooks/$HOOK_NAME"
    if [[ -L "$HOOK_DEST" ]]; then
        rm "$HOOK_DEST"
    elif [[ -e "$HOOK_DEST" ]]; then
        errors+=("$HOOK_SRC -> $HOOK_DEST: destination already exists as a regular file")
        echo "FAIL  $HOOK_DEST already exists as a regular file, cannot link"
        continue
    fi
    if [[ ! -e "$HOOK_DEST" ]]; then
        if ! ln -s "$HOOK_SRC" "$HOOK_DEST"; then
            errors+=("$HOOK_SRC -> $HOOK_DEST: ln -s failed")
            echo "FAIL  could not link $HOOK_DEST -> $HOOK_SRC"
        else
            echo "LINK  $HOOK_DEST -> $HOOK_SRC"
        fi
    fi
done

# In workspace mode, patch settings.json with workspace-specific keys
if [[ "${IN_WORKSPACE:-}" == "1" ]]; then
    settings_file="$HOME/.claude/settings.json"
    if [[ -f "$settings_file" ]]; then
        python3 -c "
import json, os
path = os.path.expanduser('$settings_file')
# Resolve symlink so we write to the actual file
real = os.path.realpath(path)
with open(real) as f:
    data = json.load(f)
data['apiKeyHelper'] = 'workspace_secret ANTHROPIC_APIKEY1'
data['forceLoginMethod'] = 'console'
with open(real, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        echo "PATCH  $settings_file (workspace: apiKeyHelper, forceLoginMethod)"
    else
        errors+=("workspace: $settings_file not found after linking, cannot patch")
        echo "FAIL  workspace patch: $settings_file not found"
    fi
fi

# Update Claude Code and marketplace plugins (after all setup is complete)
echo ""
echo "Updating Claude Code and marketplace plugins..."
if command -v claude &>/dev/null; then
    if claude update 2>&1; then
        echo "  OK  claude updated"
    else
        echo "  WARN  claude update failed (may already be up-to-date)"
    fi
    marketplace_repos=$(jq -r '.extraKnownMarketplaces | to_entries[].value.source.repo' "$SCRIPT_DIR/settings.json" 2>/dev/null || true)
    if [[ -n "$marketplace_repos" ]]; then
        while IFS= read -r repo; do
            if claude plugin marketplace add "$repo" 2>&1; then
                echo "  OK  marketplace $repo added"
            else
                echo "  WARN  marketplace $repo add failed (may already exist)"
            fi
        done <<< "$marketplace_repos"
    fi
    enabled_plugins=$(jq -r '.enabledPlugins | keys[]' "$SCRIPT_DIR/settings.json" 2>/dev/null || true)
    if [[ -n "$enabled_plugins" ]]; then
        while IFS= read -r plugin; do
            if claude plugin install "$plugin" 2>&1; then
                echo "  OK  plugin $plugin installed"
            else
                echo "  WARN  plugin $plugin install failed (may already be installed)"
            fi
        done <<< "$enabled_plugins"
    fi
    # Update installed marketplaces
    marketplace_names=$(claude plugin marketplace list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
    if [[ -n "$marketplace_names" ]]; then
        while IFS= read -r marketplace; do
            if claude plugin marketplace update "$marketplace" 2>&1; then
                echo "  OK  marketplace $marketplace updated"
            else
                echo "  WARN  marketplace $marketplace update failed"
            fi
        done <<< "$marketplace_names"
    else
        echo "  No marketplaces installed"
    fi
    # Update installed plugins
    installed_plugins=$(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)
    if [[ -n "$installed_plugins" ]]; then
        while IFS= read -r plugin; do
            if claude plugin update "$plugin" 2>&1; then
                echo "  OK  plugin $plugin updated"
            else
                echo "  WARN  plugin $plugin update failed"
            fi
        done <<< "$installed_plugins"
    else
        echo "  No plugins installed"
    fi
else
    echo "  SKIP  claude CLI not found"
fi

# Final error summary
if [[ ${#errors[@]} -gt 0 ]]; then
    echo ""
    echo "========================================="
    echo "ERROR: ${#errors[@]} file(s) failed to link or sync:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    echo "========================================="
    exit 1
fi
