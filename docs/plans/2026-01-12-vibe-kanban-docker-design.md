# vibe-kanban-docker Design Document

**Date:** 2026-01-12
**Status:** Approved
**Upstream:** https://github.com/BloopAI/vibe-kanban

## Overview

A Docker-based sandboxed development environment for running vibe-kanban with AI coding agents. Provides security isolation while maintaining productivity through flexible volume mounting and shared credentials.

## Goals

* **Security:** Contain AI agents running with `--dangerously-skip-permissions`
* **Productivity:** Easy mounting of project directories for AI-assisted work
* **Persistence:** Containers persist by default, credentials shared across all
* **Flexibility:** Read-only by default, explicit `--rw` flag for write access

---

## Architecture

### Container Naming (tmuxdir-style)

Containers are named based on canonicalized directory names:

```bash
generate_container_name() {
    local raw="$1"
    raw="${raw%/}"                                    # Strip trailing slashes
    raw="${raw##*/}"                                  # Keep only final component
    raw=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')  # Lowercase
    raw=$(printf '%s' "$raw" | tr -c '[:alnum:]' '_')       # Non-alnum → _
    raw=$(printf '%s' "$raw" | sed -E 's/_+/_/g; s/^_+//; s/_+$//')  # Collapse
    printf '%s%s\n' "$CONTAINER_PREFIX" "$raw"
}
```

**Collision handling:** If different directories canonicalize to the same name, append counter suffix (`-1`, `-2`, etc.). Mappings stored in `~/.config/vibe-kanban-docker/container_mappings/`.

### Port Allocation

* Base port: `15173` (offset from vibe-kanban default `3000` to avoid conflicts)
* Each container gets unique port, tracked in `~/.config/vibe-kanban-docker/port_mappings/`
* Port passed to container via `PORT` env var (vibe-kanban reads this)

### Credential Sharing

**All containers share a single providers volume** (`vibe_kanban_providers` by default).

This means:

* **Login once** → all containers have credentials
* Run `vibe-kanban-docker providers login` in any container
* Claude, GitHub CLI, and other provider tokens are immediately available everywhere
* No need to re-authenticate when creating new containers

The volume is mounted at `~/.config/providers/` inside each container, with symlinks to canonical locations (`~/.claude`, `~/.config/gh`, etc.).

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `VIBE_KANBAN_DOCKER_IMAGE` | `vibe-kanban-docker:latest` | Docker image to use |
| `VIBE_KANBAN_DOCKER_CONTAINER_PREFIX` | `vkb_` | Container name prefix |
| `VIBE_KANBAN_PROVIDERS_VOL` | `vibe_kanban_providers` | Credentials volume name |
| `VIBE_KANBAN_CONFIG_DIR` | `~/.config/vibe-kanban-docker` | Config directory |
| `VIBE_KANBAN_DOCKER_BASE_PORT` | `15173` | Starting port for allocation |

---

## Settings File

Location: `~/.config/vibe-kanban-docker/vibe-kanban-docker_settings.yaml`

```yaml
# Container lifecycle policy
# Values:
#   "ephemeral" or 0    → container removed after exit
#   "persistent" or -1  → container persists (default)
#   <seconds>           → TTL, auto-destroy after N seconds (future)
container_lifecycle: persistent
```

---

## File Structure

### Repository

```
docker-vibe-kanban/
├── Dockerfile                      # Arch Linux + all tools
├── .dockerignore                   # Minimal build context
├── vibe-kanban-docker              # Main script (executable)
├── scripts/
│   └── container-startup.sh        # Entrypoint script
├── docs/
│   └── plans/
│       └── 2026-01-12-vibe-kanban-docker-design.md
├── CHEATSHEET.md                   # Quick reference
├── FUTURE_WORK.md                  # Planned features
└── README.md                       # Full documentation
```

### Host Configuration

```
~/.config/vibe-kanban-docker/
├── vibe-kanban-docker_settings.yaml    # User settings
├── containers/
│   └── vkb_<name>.yaml                 # Container metadata (mounts, port, etc.)
├── container_mappings/
│   └── vkb_<name>                      # Contains: absolute directory path
└── port_mappings/
    └── vkb_<name>                      # Contains: allocated port number
```

### Container Metadata

`~/.config/vibe-kanban-docker/containers/vkb_myproject.yaml`:

```yaml
container_name: vkb_myproject
directory: /home/user/projects/myproject
created_at: 2026-01-12T14:30:00Z
image: vibe-kanban-docker:latest
port: 15173
mounts:
  - path: /home/user/projects/myproject
    mode: ro
  - path: /home/user/data
    mode: rw
```

---

## Dockerfile Design

### Base: Arch Linux with AUR

We use Arch Linux (not Alpine like upstream) because:

* AUR access for cutting-edge AI CLI tools
* Full glibc (not musl) for broader compatibility
* pacman + yay for easy package management

### Layer Order (Cache Optimization)

1. **Keyring & System Update** (very stable)
2. **Build Dependencies** (stable)
3. **Sudoers & User Setup** (stable)
4. **Build & Install Yay** (stable)
5. **Core System Tools** (very stable)
6. **Node.js & pnpm** (stable)
7. **Rust Toolchain** (stable) - REQUIRED for vibe-kanban
8. **Cargo Tools** (moderate stability)
9. **GitHub CLI via AUR** (moderate stability)
10. **AI CLI Tools** (less stable)
11. **Environment Setup** (stable)
12. **Provider Directories** (stable)
13. **Clean Package Caches** (stable)
14. **COPY startup script** (late as possible)
15. **User & Entrypoint** (final)

### Development Principles

* **RUN steps in topological order** - Most stable first, least stable last
* **COPY only when needed** - Defer file copying as late as possible
* **Minimal COPY first** - Only specific files, never bulk `COPY . .` until the very end
* **Cache-conscious development** - Changes should invalidate minimal layers

### vibe-kanban Requirements

From upstream README:

* **Rust** (latest stable) - REQUIRED, vibe-kanban is a Rust application
* **Node.js 18+**
* **pnpm 8+**
* **cargo-watch** and **sqlx-cli** for development

### Port Configuration

vibe-kanban reads port from environment variables:

1. `BACKEND_PORT` (highest priority)
2. `PORT`
3. Falls back to `0` (auto-assign) if neither set

We set `PORT` explicitly. If vibe-kanban doesn't start:

* Check: `docker logs <container>`
* Verify: `PORT` env var is set correctly
* Check: `/tmp/vibe-kanban/vibe-kanban.port` inside container
* Ensure: `HOST=0.0.0.0` (binds to all interfaces)

---

## Commands

### Building

```bash
vibe-kanban-docker build              # Build image (uses cache)
vibe-kanban-docker build --no-cache   # Force rebuild
```

### Running Containers

```bash
vibe-kanban-docker run                           # No mounts, container-only
vibe-kanban-docker run /path/to/project          # Read-only mount
vibe-kanban-docker run --rw /path/to/project     # Read-write mount
vibe-kanban-docker run --rw /src /data /config   # src=rw, others=ro
```

### Container Interaction

```bash
vibe-kanban-docker shell              # Interactive bash
vibe-kanban-docker exec <cmd>         # Run command
vibe-kanban-docker logs               # View logs
vibe-kanban-docker stop               # Stop (keeps container)
vibe-kanban-docker rm                 # Remove container
```

### Status

```bash
vibe-kanban-docker status             # Current directory's container
vibe-kanban-docker status --all       # All tracked containers
```

### Credential Management

```bash
vibe-kanban-docker providers login              # Claude + gh auth
vibe-kanban-docker providers status             # Show stored creds
vibe-kanban-docker providers reset              # Clear all

vibe-kanban-docker providers env set VAR=val    # Set env var
vibe-kanban-docker providers env import .env    # Import from file
vibe-kanban-docker providers env list           # List var names
vibe-kanban-docker providers env show VAR       # Show value
vibe-kanban-docker providers env remove VAR     # Delete var
```

---

## Mount Security Model

* **Read-only by default** - All mounts are `:ro` unless explicitly overridden
* **`--rw` flag** - Place before path to enable write access
* **No mounts** - Without paths, container runs with only internal filesystem

Examples:

```bash
./vkb /path/a                      # read-only mount
./vkb --rw /path/a                 # read-write mount
./vkb --rw /path/a /path/b /path/c # a=rw, b=ro, c=ro
./vkb --rw /path/a --rw /path/b    # both rw
./vkb                              # no mounts, container-only
```

---

## Container Lifecycle

* **Persistent by default** - Containers remain after exit, reattach on next run
* **`--ephemeral` flag** - Remove container after exit (override)
* **TTL auto-cleanup** - Future feature (see FUTURE_WORK.md)

---

## Inspiration Sources

* `Local Docker isolated setup patterns` - User mapping, volume patterns
* `Local Arch Linux + yay/AUR Docker setup` - Arch Linux + yay/AUR setup
* `[tmuxdir](https://github.com/shibuido/tmuxdir)` - Directory canonicalization pattern
* `https://github.com/BloopAI/vibe-kanban` - Upstream project
