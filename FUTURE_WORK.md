# Future Work

Planned features and improvements for vibe-kanban-docker.

---

## TTL (Time-To-Live) Auto-Cleanup

**Status:** Planned

Container lifecycle with automatic expiration:

```yaml
# In vibe-kanban-docker_settings.yaml
container_lifecycle: 86400  # Auto-remove after 24 hours of inactivity
```

### Implementation Options

* Systemd timer that checks container last-used timestamps
* Docker container labels with expiry time
* Cron job scanning `~/.config/vibe-kanban-docker/containers/`

### Values

| Value | Meaning |
|-------|---------|
| `0` or `"ephemeral"` | Remove immediately on exit |
| `-1` or `"persistent"` | Never auto-remove (current default) |
| `<seconds>` | Remove after N seconds of inactivity |
| `"24h"`, `"7d"`, `"2w"` | Human-friendly durations (future) |

---

## Port Discovery Command

```bash
vibe-kanban-docker port [container]  # Show allocated port
vibe-kanban-docker url [container]   # Show full URL (http://localhost:PORT)
```

Could also read `/tmp/vibe-kanban/vibe-kanban.port` from inside container for the actual bound port.

---

## vibe-kanban Port Behavior Reference

For debugging and future development:

* Backend reads: `BACKEND_PORT` → `PORT` → `0` (auto-assign)
* Dev script: `PORT` sets frontend, `PORT+1` sets backend
* We use `PORT` env var for simplicity
* Upstream source: `crates/server/src/main.rs`

**TODO:** Verify `npx vibe-kanban` respects `PORT` when launched inside container.

---

## Additional AI CLI Tools

Investigate installation methods for:

| Tool | Install Method | Notes |
|------|---------------|-------|
| Gemini CLI | TBD | `google-gemini-cli`? |
| GitHub Copilot CLI | TBD | May require VS Code |
| Aider | `pipx install aider-chat` | Python-based |
| Continue.dev CLI | TBD | |

---

## Image Variants

Consider lighter images for specific use cases:

| Variant | Contents |
|---------|----------|
| `vibe-kanban-docker:minimal` | Node.js + Rust + vibe-kanban only |
| `vibe-kanban-docker:full` | All dev tools (current default) |

**Note:** Rust is ALWAYS required - vibe-kanban is a Rust application. Minimal variant would just exclude extra tools (vim, tig, extra AI CLIs, etc).

---

## Container Health Checks

Add Docker health check to verify vibe-kanban is responding:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget --spider http://localhost:${PORT}/health || exit 1
```

---

## Session Mode Enhancements

From minimal-isolated inspiration:

```bash
vibe-kanban-docker session start   # Create long-running container
vibe-kanban-docker session attach  # Attach to running session
vibe-kanban-docker session detach  # Detach without stopping
```

---

## Remote Development Support

Per upstream vibe-kanban README:

* SSH access for remote containers
* VSCode Remote-SSH integration
* Expose container via SSH tunnel

---

## Multi-Project Workspace

Mount multiple projects into single container:

```bash
vibe-kanban-docker run \
    --workspace /projects/frontend \
    --workspace /projects/backend \
    --workspace /projects/shared
```

---

## Backup & Restore

```bash
vibe-kanban-docker providers backup ~/backup.tar.gz
vibe-kanban-docker providers restore ~/backup.tar.gz
```

Backup the providers volume for migration or disaster recovery.
