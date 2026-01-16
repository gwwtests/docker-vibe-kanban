# Frequently Asked Questions

## General

### What is vibe-kanban-docker?

A Docker wrapper for [vibe-kanban](https://github.com/BloopAI/vibe-kanban) that provides:

* **Security isolation** - AI agents run in containers, not on your host
* **Read-only by default** - Explicit `--rw` flag required for write access
* **Shared credentials** - Login once, all containers share access
* **Multiple projects** - Each directory gets its own container on a unique port

### Why run vibe-kanban in Docker?

vibe-kanban runs AI agents with powerful permissions (`--dangerously-skip-permissions`). Running in Docker means:

* AI can only access directories you explicitly mount
* Mistakes are contained to the container
* Your host system remains protected
* Easy cleanup - just remove the container

## Containers

### How are container names determined?

Container names are derived from directory names using "tmuxdir-style" canonicalization:

```
/home/user/projects/my-app  →  vkb_my_app
/home/user/Projects/MyApp   →  vkb_myapp
/tmp/test                   →  vkb_test
```

* Lowercase
* Special characters replaced with underscores
* Prefix: `vkb_` (configurable via `VIBE_KANBAN_DOCKER_CONTAINER_PREFIX`)

If two directories would create the same name, a suffix is added: `vkb_myapp`, `vkb_myapp-1`, etc.

### How do I target a specific container?

Two ways:

```bash
# 1. Change to the directory (default behavior)
cd /path/to/project
./vibe-kanban-docker status

# 2. Use --dir flag
./vibe-kanban-docker --dir /path/to/project status
./vibe-kanban-docker --dir /other/project shell
```

### Why use `http://127.0.0.1` instead of `localhost`?

On many systems, `localhost` resolves to IPv6 (`::1`) first. Docker's port forwarding can have issues with IPv6. Using `127.0.0.1` explicitly forces IPv4, which works reliably.

### Do containers survive reboots?

Yes! Containers are created with `--restart unless-stopped`, so they automatically start when Docker starts.

## Ports

### How are ports allocated?

Ports start at 15173 (to avoid conflicts with common dev server ports like 3000, 8080) and increment for each container:

```
First container:   15173
Second container:  15174
Third container:   15175
```

Override the base port with `VIBE_KANBAN_DOCKER_BASE_PORT`:

```bash
VIBE_KANBAN_DOCKER_BASE_PORT=20000 ./vibe-kanban-docker run --rw /path
```

### Why port 15173?

It's unlikely to conflict with:

* Common web dev ports (3000, 5000, 8080)
* Database ports (3306, 5432, 27017)
* Other common services

## Volumes

### What is the `providers` volume?

The `providers` volume (`vibe_kanban_providers`) stores:

```
~/.config/providers/
├── claude/          # Claude Code credentials
├── gh/              # GitHub CLI credentials
└── env/             # Environment variables (API keys)
```

**Key points:**

* Shared across ALL containers
* Login once with `providers login`, works everywhere
* Persists across container restarts
* Safe to delete (you'll need to re-login)

### What is the `dotclaude` volume?

The `dotclaude` volume (`vibe_kanban_dotclaude`) stores:

```
~/.claude/
├── settings.json    # Claude Code settings
├── mcp-servers/     # MCP server configurations
└── ...              # Session data, history
```

**Use cases:**

* Share Claude Code configuration across containers
* Consistent MCP server setup in all environments
* Persist conversation history

**Not mounted by default** - add to your workflow if needed.

### How do I share credentials with other Docker containers?

Mount the providers volume:

```bash
docker run -v vibe_kanban_providers:/home/user/.config/providers your-image
```

Or use the same credentials in a different Docker setup:

```bash
# Copy credentials out
docker run --rm -v vibe_kanban_providers:/data -v $(pwd):/backup alpine \
    tar czf /backup/providers-backup.tar.gz -C /data .

# Copy credentials in
docker run --rm -v other_volume:/data -v $(pwd):/backup alpine \
    tar xzf /backup/providers-backup.tar.gz -C /data
```

## Mounts

### What's the difference between `ro` and `rw` mounts?

| Mode | Meaning | Use Case |
|------|---------|----------|
| `ro` | Read-only | Reference code, data you don't want modified |
| `rw` | Read-write | Active development, AI can modify files |

Default is `ro` (read-only) for safety.

### How do I mount multiple directories?

```bash
# All read-only
./vibe-kanban-docker run /path1 /path2 /path3

# First read-write, others read-only
./vibe-kanban-docker run --rw /src /data /config

# Multiple read-write
./vibe-kanban-docker run --rw /src --rw /tests /docs
```

### Can AI access files outside mounted directories?

No. The container can only see:

* Explicitly mounted host directories
* The providers volume (credentials)
* Container's own filesystem (ephemeral)

This is the core security feature.

## Editor Integration

### Why does vibe-kanban ask me to select an editor?

vibe-kanban has "Open in Editor" buttons for tasks. These work by:

1. **Local mode**: Spawning `code /path` or `cursor /path`
2. **Remote SSH mode**: Generating URLs like `vscode://vscode-remote/ssh-remote+user@host/path`

### Editor integration doesn't work in Docker. Why?

In Docker, local mode fails because `code`/`cursor` CLI aren't installed (and couldn't open windows on your host anyway).

**Solutions:**

1. **Ignore it** - Use the web UI and `./vibe-kanban-docker shell` for terminal access
2. **Configure Remote SSH** - In vibe-kanban Settings → Editor Integration, set your host's SSH details

### How do I use vim/neovim?

Vim doesn't have URL protocol handlers. Options:

```bash
# Use shell access
./vibe-kanban-docker shell
vim /path/to/file

# Or exec directly
./vibe-kanban-docker exec vim /path/to/file
```

## Configuration

### Where are configuration files stored?

| Location | Purpose |
|----------|---------|
| `~/.config/vibe-kanban-docker/` | Host-side config |
| `~/.config/vibe-kanban-docker/containers/` | Container metadata (YAML) |
| `~/.config/vibe-kanban-docker/port_mappings/` | Port allocations |

### How do I customize settings?

```bash
# Copy example settings
mkdir -p ~/.config/vibe-kanban-docker
cp configs/vibe-kanban-docker_settings.example.yaml \
   ~/.config/vibe-kanban-docker/vibe-kanban-docker_settings.yaml

# Edit as needed
vim ~/.config/vibe-kanban-docker/vibe-kanban-docker_settings.yaml
```

### What environment variables are available?

| Variable | Default | Purpose |
|----------|---------|---------|
| `VIBE_KANBAN_DOCKER_IMAGE` | `vibe-kanban-docker:latest` | Docker image to use |
| `VIBE_KANBAN_DOCKER_CONTAINER_PREFIX` | `vkb_` | Container name prefix |
| `VIBE_KANBAN_PROVIDERS_VOL` | `vibe_kanban_providers` | Credentials volume name |
| `VIBE_KANBAN_CONFIG_DIR` | `~/.config/vibe-kanban-docker` | Config directory |
| `VIBE_KANBAN_DOCKER_BASE_PORT` | `15173` | Starting port number |

Use `./vibe-kanban-docker status --verbose` to see current values.

## Troubleshooting

### Container won't start

```bash
# Check Docker is running
docker info

# Check image exists
docker images | grep vibe-kanban-docker

# Rebuild if needed
./vibe-kanban-docker build
```

### vibe-kanban not accessible in browser

```bash
# Check container is running
./vibe-kanban-docker status

# Check logs for errors
./vibe-kanban-docker logs

# Verify port is listening inside container
./vibe-kanban-docker exec ss -tlnp
```

### Permission denied on mounted files

```bash
# Rebuild with your UID/GID
./vibe-kanban-docker build

# Check current UID mapping
docker exec <container> id
```

### How do I completely reset?

```bash
# Remove container
./vibe-kanban-docker rm

# Remove volumes (will lose credentials)
./vibe-kanban-docker volume providers rm
./vibe-kanban-docker volume dotclaude rm

# Remove image
docker rmi vibe-kanban-docker:latest

# Clear config
rm -rf ~/.config/vibe-kanban-docker
```
