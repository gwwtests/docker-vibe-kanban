# vibe-kanban Editor Integration in Docker Containers

Research notes on how vibe-kanban's "Open in Editor" feature works and its implications for containerized deployments.

## The Question

When running vibe-kanban in Docker, it prompts for editor selection (VS Code, Cursor, vim, etc.). How does a web app running inside a container communicate with editors on the host?

## Architecture Overview

vibe-kanban uses a **hybrid approach**:

* **Local mode**: Spawns editor process directly (`code /path`, `cursor /path`)
* **Remote SSH mode**: Generates protocol URLs (`vscode://vscode-remote/ssh-remote+user@host/path`)

```
┌─────────────────────────────────────────────────────────────────┐
│                        User clicks "Open in Editor"             │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend checks editor config                  │
└─────────────────────────────────────────────────────────────────┘
                    │                           │
          Local Mode │                           │ Remote SSH Mode
                    ▼                           ▼
┌─────────────────────────┐     ┌─────────────────────────────────┐
│ spawn: code /path       │     │ return URL:                     │
│ (requires CLI in PATH)  │     │ vscode://vscode-remote/         │
└─────────────────────────┘     │ ssh-remote+user@host/path       │
                                └─────────────────────────────────┘
                                                │
                                                ▼
                                ┌─────────────────────────────────┐
                                │ Browser opens URL → triggers    │
                                │ local VS Code protocol handler  │
                                └─────────────────────────────────┘
```

## Supported Editors

From `crates/services/src/services/config/editor/mod.rs`:

| Editor | CLI Command | Protocol URL Support |
|--------|-------------|---------------------|
| VS Code | `code` | `vscode://` |
| Cursor | `cursor` | `cursor://` |
| Windsurf | `windsurf` | `windsurf://` |
| Zed | `zed` | `zed://ssh/` |
| IntelliJ | `idea` | No |
| Xcode | `xed` | No |
| Custom | user-defined | No |

## The Docker Problem

In a containerized environment:

1. **Local mode fails** - Container doesn't have `code`/`cursor` CLI installed
2. **Process spawning is isolated** - Even if CLI existed, it couldn't open windows on host
3. **No X11/Wayland forwarding** by default

### Error Message

Users see: `No such file or directory (os error 2)` when editor CLI is missing.

## Solutions for Docker Deployments

### Option 1: Remote SSH Configuration (Recommended)

Configure in vibe-kanban Settings → Editor Integration:

```yaml
Remote SSH Host: <host-ip-or-hostname>
Remote SSH User: <your-username>
```

When clicking "Open in Editor":

1. vibe-kanban generates: `vscode://vscode-remote/ssh-remote+user@host/workspace/path`
2. Browser opens URL
3. Local VS Code launches with Remote-SSH extension
4. VS Code connects back to container via SSH

**Requirements:**

* SSH server running (in container or on host)
* SSH keys configured for passwordless auth
* VS Code Remote-SSH extension installed locally

### Option 2: Ignore Editor Integration

The web UI is fully functional without editor integration:

* View/edit files through the web interface
* Use `./vibe-kanban-docker shell` for terminal access
* Manually open files: `vim /path/to/file`

### Option 3: Custom Editor Command

Set editor type to "Custom" with a command that:

* Writes the path to a known location
* External script picks it up and opens editor

```bash
# Custom command example (writes to shared volume)
echo "$1" > /tmp/open-in-editor.txt
```

## Vim/Neovim Considerations

Vim doesn't have URL protocol handlers like VS Code. Options:

* Use terminal: `./vibe-kanban-docker shell` then `vim /path`
* Use custom command to signal nvim-remote or similar
* Accept that editor integration is VS Code-centric

## Relevant GitHub Issues

* [#1006 - Failed to open editor for project](https://github.com/BloopAI/vibe-kanban/issues/1006) - Exact error when CLI missing
* [#344 - Unable to open on remote dev machine](https://github.com/BloopAI/vibe-kanban/issues/344) - Workaround with `HOST=0.0.0.0`
* [#311 - Docker can't work](https://github.com/BloopAI/vibe-kanban/issues/311) - Docker build issues (fixed in PR #312)
* [#2034 - Docker container question](https://github.com/BloopAI/vibe-kanban/discussions/2034) - Unanswered question about official Docker support
* [#2089 - VS Code Insiders support](https://github.com/BloopAI/vibe-kanban/discussions/2089) - Request for additional editor support

## Key Source Files

| File | Purpose |
|------|---------|
| `crates/services/src/services/config/editor/mod.rs` | Editor type enum and opening logic |
| `crates/server/src/routes/task_attempts.rs` | API endpoint for open-in-editor |
| `frontend/src/hooks/useOpenInEditor.ts` | Frontend hook for editor opening |
| `frontend/src/components/dialogs/tasks/EditorSelectionDialog.tsx` | Editor picker UI |

## Design Philosophy

From [VirtusLab blog](https://virtuslab.com/blog/ai/vibe-kanban/):

> "You avoid Docker overhead (volumes, networks, images) while getting isolation that's perfectly sufficient for file-level operations."

vibe-kanban uses **git worktrees** for isolation rather than Docker containers. Our docker-vibe-kanban wrapper adds container isolation on top, which creates the editor integration challenge.

## Conclusion

The editor selection prompt can be safely ignored for Docker deployments. The primary workflow is:

1. Use web UI for task management
2. Use `./vibe-kanban-docker shell` for terminal access
3. Optionally configure Remote SSH for VS Code integration

For vim users, the web UI + shell access is the practical path forward.
