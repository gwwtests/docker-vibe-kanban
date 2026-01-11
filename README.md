# vibe-kanban-docker

Sandboxed AI development environment for [vibe-kanban](https://github.com/BloopAI/vibe-kanban).

Run AI coding agents safely in Docker containers with controlled access to your projects.

## Why?

vibe-kanban runs AI agents with powerful permissions (`--dangerously-skip-permissions`). This container provides:

* **Security isolation** - AI agents can only access mounted directories
* **Read-only by default** - Explicit `--rw` flag required for write access
* **Shared credentials** - Login once, all containers have access
* **Persistent containers** - Resume work where you left off

## Quick Start

```bash
# 1. Build the image
./vibe-kanban-docker build

# 2. Setup credentials (once)
./vibe-kanban-docker providers login

# 3. Run with your project
cd /path/to/your/project
./vibe-kanban-docker run --rw .

# 4. Open shell and start vibe-kanban
./vibe-kanban-docker shell
npx vibe-kanban
```

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

This builds an Arch Linux container with:

* Node.js 18+, pnpm
* Rust (latest stable), cargo-watch, sqlx-cli
* Claude Code, GitHub CLI
* vim, neovim, tig, tmux, ripgrep, fd, bat, fzf
* AUR support via yay

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
./vibe-kanban-docker shell       # Interactive bash
./vibe-kanban-docker exec cmd    # Run single command
./vibe-kanban-docker logs        # View container logs
./vibe-kanban-docker stop        # Stop container
./vibe-kanban-docker rm          # Remove container
```

### Status

```bash
./vibe-kanban-docker status          # Current directory's container
./vibe-kanban-docker status --all    # All tracked containers
```

## Credential Management

**All containers share a single providers volume.** Login once, and all containers have access.

```bash
# Interactive login for Claude and GitHub
./vibe-kanban-docker providers login

# Check stored credentials
./vibe-kanban-docker providers status

# Clear all credentials
./vibe-kanban-docker providers reset
```

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

## Security Model

* **Read-only by default** - Mounts are read-only unless `--rw` is specified
* **No mounts by default** - Running without paths gives container-only filesystem
* **Explicit write access** - Use `--rw` flag before each writable path
* **Isolated credentials** - Stored in Docker volume, not on host filesystem

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

## License

MIT

## Upstream

* [vibe-kanban](https://github.com/BloopAI/vibe-kanban) - The AI-powered Kanban board
