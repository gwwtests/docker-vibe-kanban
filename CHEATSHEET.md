# vibe-kanban-docker Cheatsheet

Quick reference for common commands.

## Building

```bash
vibe-kanban-docker build              # Build image (uses cache)
vibe-kanban-docker build --no-cache   # Force full rebuild
```

## Running Containers

```bash
# No mounts (container filesystem only)
vibe-kanban-docker run

# Read-only mount (default, safe)
vibe-kanban-docker run /path/to/project

# Read-write mount (explicit)
vibe-kanban-docker run --rw /path/to/project

# Mixed: src=rw, data=ro, config=ro
vibe-kanban-docker run --rw /src /data /config

# Multiple read-write
vibe-kanban-docker run --rw /src --rw /data
```

## Container Interaction

```bash
vibe-kanban-docker shell      # Interactive bash shell
vibe-kanban-docker exec cmd   # Run single command
vibe-kanban-docker logs       # View container logs
vibe-kanban-docker stop       # Stop (keeps container)
vibe-kanban-docker rm         # Remove container completely
```

## Status & Info

```bash
vibe-kanban-docker status         # This directory's container
vibe-kanban-docker status --all   # All tracked containers
```

## Credentials (Shared Across All Containers)

```bash
# Login to AI providers (do once, works everywhere)
vibe-kanban-docker providers login

# Check what's stored
vibe-kanban-docker providers status

# Clear all credentials
vibe-kanban-docker providers reset
```

## Environment Variables (API Keys, etc.)

```bash
# Set a variable
vibe-kanban-docker providers env set OPENAI_API_KEY=sk-...

# Set interactively (hidden input)
vibe-kanban-docker providers env set OPENAI_API_KEY

# Import from .env file
vibe-kanban-docker providers env import ~/.env

# List stored variables (names only, values hidden)
vibe-kanban-docker providers env list

# Show a specific value
vibe-kanban-docker providers env show OPENAI_API_KEY

# Remove a variable
vibe-kanban-docker providers env remove OPENAI_API_KEY
```

## Environment Variable Overrides

```bash
# Use different image
VIBE_KANBAN_DOCKER_IMAGE=myimage:v2 vibe-kanban-docker run

# Use different container prefix
VIBE_KANBAN_DOCKER_CONTAINER_PREFIX=test_ vibe-kanban-docker run

# Use different base port
VIBE_KANBAN_DOCKER_BASE_PORT=20000 vibe-kanban-docker run
```

## Debugging

```bash
# Check container logs
vibe-kanban-docker logs

# Get shell and inspect
vibe-kanban-docker shell
> echo $PORT                              # Should show allocated port
> cat /tmp/vibe-kanban/vibe-kanban.port   # Actual port vibe-kanban is using
> ps aux | grep server                    # Check if server is running

# Check status with details
vibe-kanban-docker status
```

## File Locations

| Location | Purpose |
|----------|---------|
| `~/.config/vibe-kanban-docker/` | Host-side configuration |
| `~/.config/vibe-kanban-docker/containers/` | Container metadata |
| `~/.config/vibe-kanban-docker/port_mappings/` | Port allocations |
| `~/.config/providers/` (in container) | Mounted credentials volume |

## Mount Modes

| Command | Result |
|---------|--------|
| `run /path` | Read-only mount |
| `run --rw /path` | Read-write mount |
| `run --rw /a /b` | a=rw, b=ro |
| `run --rw /a --rw /b` | Both read-write |
| `run` | No mounts |
