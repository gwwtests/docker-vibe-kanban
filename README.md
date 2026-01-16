# vibe-kanban-docker

> **Not a fork.** This is a convenience wrapper (scripts + Dockerfile) that runs the **original, unmodified** [vibe-kanban](https://github.com/BloopAI/vibe-kanban) inside Docker containers.

## What This Is

A set of scripts and Dockerfile that help you:

* **Launch vibe-kanban in isolated Docker containers** - point at a project directory, get a running vibe-kanban instance
* **Manage AI tool credentials in Docker volumes** - login to Claude, GitHub CLI, etc. once; all containers share access
* **Run multiple projects in parallel** - each in its own container on a separate port
* **Jump into containers easily** - `./vibe-kanban-docker shell` for interactive work

```
┌─────────────────────────────────────────────────────────────────┐
│  This repo provides          │  NOT provided (comes from       │
│  ─────────────────           │  upstream vibe-kanban)          │
│                              │  ───────────────────────────    │
│  • Dockerfile                │  • vibe-kanban itself           │
│  • vibe-kanban-docker script │  • AI agent functionality       │
│  • Credential management     │  • Kanban board UI              │
│  • Container orchestration   │  • All the actual features      │
└─────────────────────────────────────────────────────────────────┘
```

## Why Use This Instead of Running vibe-kanban Directly?

| Running directly | Running via vibe-kanban-docker |
|------------------|-------------------------------|
| AI agents have full system access | AI agents isolated to mounted dirs only |
| Credentials scattered across ~/.config | Credentials in Docker volume, shareable |
| One project at a time (or manual port management) | Multiple projects, auto port allocation |
| Need to install Node.js, Rust, tools | Everything pre-installed in container |
| Rebuilding loses your auth sessions | Credentials persist in volume |

### Credential Sharing - The Killer Feature

Login to AI tools **once**, use in **all containers** (and your own Docker setups):

```bash
# Login once
./vibe-kanban-docker providers login

# Now ALL containers have access - no re-login needed:
./vibe-kanban-docker --dir /project1 run --rw /project1
./vibe-kanban-docker --dir /project2 run --rw /project2
./vibe-kanban-docker --dir /project3 run --rw /project3

# Use the same credentials in YOUR OWN containers:
docker run -v vibe_kanban_providers:/home/user/.config/providers your-own-image
```

## Security Model

vibe-kanban runs AI agents with powerful permissions (`--dangerously-skip-permissions`). This wrapper provides:

* **Container isolation** - AI agents can only access explicitly mounted directories
* **Read-only by default** - Explicit `--rw` flag required for write access
* **No mounts = no access** - Running without paths gives container-only filesystem
* **Credentials isolated** - Stored in Docker volume, not scattered on host

## Quick Start

```bash
# 1. Build the image
./vibe-kanban-docker build

# 2. Setup credentials (once) - interactive menu or specify provider
./vibe-kanban-docker providers login           # Interactive: select from menu
./vibe-kanban-docker providers login claude    # Claude Code only
./vibe-kanban-docker providers login gh        # GitHub CLI only
./vibe-kanban-docker providers login all       # All providers

# 3. Run with your project (vibe-kanban starts automatically)
./vibe-kanban-docker run --rw /path/to/your/project

# 4. Open in browser
# http://127.0.0.1:15173
```

Containers auto-start vibe-kanban and persist across reboots (`--restart unless-stopped`).

## Installation

Clone this repository:

```bash
git clone <repo-url> docker-vibe-kanban
cd docker-vibe-kanban
```

Build the Docker image:

```bash
./vibe-kanban-docker build
```

This builds an Arch Linux container with all tools pre-installed. See [Container Contents](#container-contents) for details.

## Container Contents

**Base: Arch Linux** (not Alpine) — full glibc compatibility, AUR access via yay

| Category | Tools |
|----------|-------|
| **Editors** | vim, neovim |
| **Languages** | Node.js 18+, pnpm, Rust (stable), Python 3 |
| **AI Tools** | Claude Code, GitHub CLI |
| **Rust Dev** | cargo-watch, sqlx-cli, clippy, rustfmt |
| **Terminal** | tmux, screen, htop, mc, less, tree |
| **Search/Find** | ripgrep (rg), fd, fzf, bat |
| **Git** | git, tig |
| **Network** | curl, wget, aria2, openssh |
| **Diagnostics** | procps-ng (ps, top), iproute2 (ip, ss), net-tools (netstat), bind (dig) |
| **Data** | jq |

All tools available to AI agents running inside the container

## Usage

### Running Containers

```bash
# No mounts (container filesystem only)
./vibe-kanban-docker run

# Read-only mount (safe default)
./vibe-kanban-docker run /path/to/project

# Read-write mount (explicit)
./vibe-kanban-docker run --rw /path/to/project

# Mixed mounts
./vibe-kanban-docker run --rw /src /data /config  # src=rw, others=ro
```

### Container Interaction

```bash
./vibe-kanban-docker logs        # View vibe-kanban output
./vibe-kanban-docker shell       # Interactive bash
./vibe-kanban-docker exec cmd    # Run single command
./vibe-kanban-docker stop        # Stop container
./vibe-kanban-docker rm          # Remove container
```

### Container Targeting

Commands operate on the container for the **current directory** by default:

```bash
# From project directory
cd /path/to/project
./vibe-kanban-docker logs

# Or use --dir to target any container
./vibe-kanban-docker --dir /path/to/project logs
./vibe-kanban-docker --dir /other/project shell
```

### Status

```bash
./vibe-kanban-docker status          # Current directory's container
./vibe-kanban-docker status --all    # All tracked containers
```

## Credential Management

**All containers share a single providers volume.** Login once, and all containers have access.

```bash
# Interactive login - select provider from menu
./vibe-kanban-docker providers login

# Or specify provider directly
./vibe-kanban-docker providers login claude    # Claude Code (runs: claude login)
./vibe-kanban-docker providers login gh        # GitHub CLI (runs: gh auth login)
./vibe-kanban-docker providers login all       # All providers

# Check stored credentials
./vibe-kanban-docker providers status

# Clear all credentials
./vibe-kanban-docker providers reset
```

> **Note:** Claude Code uses interactive OAuth by default (`claude login`). Pro/Max subscribers can alternatively use `claude setup-token` to generate a long-lived token, then store it via `providers env set CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...`

### Environment Variables (API Keys)

Store API keys securely in the providers volume:

```bash
# Set a variable
./vibe-kanban-docker providers env set OPENAI_API_KEY=sk-...

# Set interactively (hidden input)
./vibe-kanban-docker providers env set OPENAI_API_KEY

# Import from .env file
./vibe-kanban-docker providers env import ~/.env

# List stored variables (names only)
./vibe-kanban-docker providers env list

# Show a specific value
./vibe-kanban-docker providers env show OPENAI_API_KEY

# Remove a variable
./vibe-kanban-docker providers env remove OPENAI_API_KEY
```

## Container Naming

Containers are named based on the directory you run from:

```
/home/user/projects/myproject → vkb_myproject
/home/user/work/MyApp         → vkb_myapp
```

If different directories would have the same name, a suffix is added (`vkb_myproject-1`, etc.).

## Port Allocation

Each container gets a unique port starting at 15173 (to avoid conflicts with local dev servers).

```bash
./vibe-kanban-docker status  # Shows allocated port and URL
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VIBE_KANBAN_DOCKER_IMAGE` | `vibe-kanban-docker:latest` | Docker image |
| `VIBE_KANBAN_DOCKER_CONTAINER_PREFIX` | `vkb_` | Container name prefix |
| `VIBE_KANBAN_PROVIDERS_VOL` | `vibe_kanban_providers` | Credentials volume |
| `VIBE_KANBAN_CONFIG_DIR` | `~/.config/vibe-kanban-docker` | Config directory |
| `VIBE_KANBAN_DOCKER_BASE_PORT` | `15173` | Starting port |

### Settings File

Copy the example settings:

```bash
mkdir -p ~/.config/vibe-kanban-docker
cp configs/vibe-kanban-docker_settings.example.yaml \
   ~/.config/vibe-kanban-docker/vibe-kanban-docker_settings.yaml
```

## Docker Volumes (Reusable in Your Own Containers!)

Two volumes persist data and can be **mounted in any Docker container**:

| Volume | Purpose | Mount Point |
|--------|---------|-------------|
| `vibe_kanban_providers` | AI tool credentials | `~/.config/providers` |
| `vibe_kanban_dotclaude` | Claude Code config | `~/.claude` |

### Using Credentials in Your Own Containers

The credentials volume works with any Docker setup:

```bash
# Your own container gets Claude, GitHub CLI, API keys - no login needed:
docker run -it \
  -v vibe_kanban_providers:/home/youruser/.config/providers \
  your-own-image

# Inside that container, Claude Code and gh are already authenticated!
```

**Volume contents:**

```
~/.config/providers/
├── claude/          # Claude Code auth (symlinked to ~/.claude)
├── gh/              # GitHub CLI auth (symlinked to ~/.config/gh)
└── env/             # API keys (OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.)
    ├── OPENAI_API_KEY
    └── ANTHROPIC_API_KEY
```

Use `./vibe-kanban-docker status --explain` for detailed explanations of all resources.

## File Locations

| Location | Purpose |
|----------|---------|
| `~/.config/vibe-kanban-docker/` | Configuration and state |
| `~/.config/vibe-kanban-docker/containers/` | Container metadata |
| `~/.config/vibe-kanban-docker/port_mappings/` | Port allocations |
| Docker volume: `vibe_kanban_providers` | Credentials and API keys |

## Troubleshooting

### vibe-kanban not accessible

1. Check container is running: `./vibe-kanban-docker status`
2. Check logs: `./vibe-kanban-docker logs`
3. Verify PORT is set: `./vibe-kanban-docker exec 'echo $PORT'`
4. Check vibe-kanban port file: `./vibe-kanban-docker exec 'cat /tmp/vibe-kanban/vibe-kanban.port'`

### Permission denied on mounted files

* Rebuild image with your UID/GID: `./vibe-kanban-docker build`
* Check mount mode: `./vibe-kanban-docker status` (should show `rw` for writable mounts)

### Container won't start

* Check Docker is running: `docker info`
* Check image exists: `docker images | grep vibe-kanban-docker`
* Rebuild if needed: `./vibe-kanban-docker build`

## Development

### Build Caching Principles

The Dockerfile is structured for optimal caching:

1. **Stable layers first** - System packages, user setup
2. **Less stable layers last** - AI CLI tools, startup script
3. **COPY deferred** - Only copy files when absolutely needed

Changes to documentation don't invalidate the build cache.

### Contributing

See [FUTURE_WORK.md](FUTURE_WORK.md) for planned features.

## Documentation

* [FAQ](docs/FAQ.md) - Frequently asked questions with detailed explanations
* [CHEATSHEET.md](CHEATSHEET.md) - Quick reference for common commands
* [FUTURE_WORK.md](FUTURE_WORK.md) - Planned features and improvements

**Self-documenting commands:**

```bash
./vibe-kanban-docker status --explain    # Explains each status field
./vibe-kanban-docker status --verbose    # Shows all configuration
./vibe-kanban-docker help                # Command reference
```

## License

MIT

## Upstream

* [vibe-kanban](https://github.com/BloopAI/vibe-kanban) - The AI-powered Kanban board
