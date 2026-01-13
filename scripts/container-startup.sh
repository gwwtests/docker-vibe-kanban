#!/bin/bash
# ============================================
# Container Startup Script
# ============================================
# This runs as ENTRYPOINT before CMD.
#
# DEBUGGING PORT ISSUES:
# If vibe-kanban doesn't start or isn't accessible:
#   1. Check this script ran: echo $PORT should show allocated port
#   2. Check vibe-kanban port file: cat /tmp/vibe-kanban/vibe-kanban.port
#   3. Check process: ps aux | grep server
#   4. Check logs: look for "listening on" message
#
# vibe-kanban port priority: BACKEND_PORT > PORT > 0 (auto)
# We set PORT. If BACKEND_PORT is set elsewhere, it takes precedence.
# ============================================

set -e

# ============================================
# Load environment variables from providers volume
# ============================================
# Environment variables (API keys, etc.) are stored as individual files
# in ~/.config/providers/env/ with filename=varname, content=value
load_provider_envs() {
    local env_dir="$HOME/.config/providers/env"
    if [[ -d "$env_dir" ]]; then
        for f in "$env_dir"/*; do
            [[ -f "$f" ]] || continue
            local var_name
            var_name=$(basename "$f")
            # Only export valid variable names
            if [[ "$var_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                export "$var_name"="$(cat "$f")"
            fi
        done
    fi
}

# ============================================
# Create symlinks for credential directories
# ============================================
# Providers volume is mounted at ~/.config/providers/
# We create symlinks from canonical tool locations to subdirs there
setup_credential_symlinks() {
    # Claude Code: ~/.claude -> ~/.config/providers/claude
    if [[ -d "$HOME/.config/providers/claude" ]]; then
        ln -sfn "$HOME/.config/providers/claude" "$HOME/.claude" 2>/dev/null || true
    fi

    # GitHub CLI: ~/.config/gh -> ~/.config/providers/gh
    if [[ -d "$HOME/.config/providers/gh" ]]; then
        mkdir -p "$HOME/.config" 2>/dev/null || true
        ln -sfn "$HOME/.config/providers/gh" "$HOME/.config/gh" 2>/dev/null || true
    fi

    # GitHub Copilot: ~/.config/github-copilot -> ~/.config/providers/copilot
    if [[ -d "$HOME/.config/providers/copilot" ]]; then
        mkdir -p "$HOME/.config" 2>/dev/null || true
        ln -sfn "$HOME/.config/providers/copilot" "$HOME/.config/github-copilot" 2>/dev/null || true
    fi

    # Git config: ~/.gitconfig -> ~/.config/providers/gitconfig
    if [[ -f "$HOME/.config/providers/gitconfig" ]]; then
        ln -sfn "$HOME/.config/providers/gitconfig" "$HOME/.gitconfig" 2>/dev/null || true
    fi
}

# ============================================
# Ensure HOST is set for container accessibility
# ============================================
# vibe-kanban defaults to 127.0.0.1 which won't work from outside container
# We default to 0.0.0.0 to bind to all interfaces
export HOST="${HOST:-0.0.0.0}"

# ============================================
# Run setup functions
# ============================================
load_provider_envs
setup_credential_symlinks

# ============================================
# Auto-start vibe-kanban if WORKSPACE_DIR is set
# ============================================
# WORKSPACE_DIR is set by vibe-kanban-docker run command
# If set, we start vibe-kanban in that directory
start_vibe_kanban() {
    if [[ -n "${WORKSPACE_DIR:-}" && -d "$WORKSPACE_DIR" ]]; then
        echo "=== vibe-kanban-docker ==="
        echo "Workspace: $WORKSPACE_DIR"
        echo "Port:      $PORT"
        echo "URL:       http://127.0.0.1:$PORT"
        echo ""
        cd "$WORKSPACE_DIR"
        exec npx vibe-kanban
    else
        echo "No WORKSPACE_DIR set or directory doesn't exist."
        echo "Starting idle shell. Run 'npx vibe-kanban' manually."
        exec tail -f /dev/null
    fi
}

# ============================================
# Execute: vibe-kanban or passed command
# ============================================
# If no arguments or default "start" arg, run vibe-kanban
# Otherwise, run the passed command (for shell/exec access)
if [[ $# -eq 0 || "$1" == "start" ]]; then
    start_vibe_kanban
else
    exec "$@"
fi
