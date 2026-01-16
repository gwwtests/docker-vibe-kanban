# Remote VM Deployment Patterns for vibe-kanban

Research notes on running vibe-kanban on remote VMs (DigitalOcean, Runpod, Vast.ai, etc.) and common cloud AI development patterns.

## Official Remote Support

vibe-kanban supports remote deployment but documentation is sparse. Key requirements:

```bash
# Bind to all interfaces for remote access
HOST=0.0.0.0 PORT=12345 npx vibe-kanban
```

## GitHub Issues for Remote Deployment

* [#344 - Unable to open on remote dev machine](https://github.com/BloopAI/vibe-kanban/issues/344) - Fixed with `HOST=0.0.0.0`
* [#1110 - Webhook notifications for remote servers](https://github.com/BloopAI/vibe-kanban/issues/1110) - Desktop notifications don't work headless; requesting webhooks for Slack/Discord/Telegram
* [#311 - Docker can't work](https://github.com/BloopAI/vibe-kanban/issues/311) - Build issues fixed in PR #312
* [#2034 - Docker container question](https://github.com/BloopAI/vibe-kanban/discussions/2034) - Unanswered (Jan 2026)

## Web UI Exposure Methods

| Method | Best For | Notes |
|--------|----------|-------|
| Cloudflare Tunnel | Production | Free, DDoS protection, 100s timeout limit |
| ngrok | Development | Easy setup, traffic inspection UI |
| Tailscale | Private access | Mesh VPN, no port forwarding needed |
| SSH port forwarding | Quick access | `ssh -L 8080:localhost:8080 user@server` |

## GPU Cloud Providers

### Runpod

* Per-minute billing (~40% cheaper for bursty workloads)
* Built-in HTTP proxy: `https://[POD_ID]-[PORT].proxy.runpod.net`
* **100-second timeout** (Cloudflare constraint) - problematic for LLM inference
* RTX 4090: ~$0.34/hr, H100: ~$1.99-2.39/hr

### Vast.ai

* Decentralized marketplace ("Airbnb for GPUs")
* Lowest prices (20-50% cheaper), variable reliability
* H100 from ~$1.87/hr
* Local Volumes for persistence (2025 feature)

### Lambda Labs

* Enterprise-grade, managed infrastructure
* Pre-installed Lambda Stack (CUDA, cuDNN, PyTorch)
* Zero data egress fees
* H100 80GB: ~$2.49-2.99/hr

### Paperspace (DigitalOcean)

* Strong MLOps platform (Gradient)
* Per-second billing
* Most GPUs require Growth plan ($39/mo)
* H100: $5.95/hr on-demand

## Common Deployment Patterns

### Pattern 1: DigitalOcean Droplet + Claude Code

Documented pattern for AI coding tools:

1. Create Ubuntu droplet ($6-20/month)
2. Install Node.js via nvm
3. Install AI CLI tool
4. Authenticate via SSH port forwarding
5. Connect with VS Code Remote SSH

**Total cost**: ~$26-30/month (droplet + Claude Pro)

Sources:

* [VS Code + Claude Code on DigitalOcean](https://www.digitalocean.com/community/tutorials/claude-code-gpu-droplets-vscode)
* [Claude Code Setup on VPS](https://www.ramseyshaffer.com/p/intro-claude-code-setup-on-vps)

### Pattern 2: tmux for Session Persistence

The "killer feature" for remote AI coding:

```bash
# Start persistent session
tmux new -s vibe-dev
npx vibe-kanban

# Detach: Ctrl+b, d
# Reattach from anywhere
tmux attach -t vibe-dev
```

Related tools:

* **Agent Deck** - Terminal session manager with AI integration
* **AgentOS** - Mobile-first web UI for AI sessions
* **Agentboard** - Web wrapper for tmux

### Pattern 3: Tailscale + Self-Hosted

```
[Proxmox/Hypervisor]
    |
    +-- [NixOS VM with GPU Passthrough]
            |
            +-- Docker: vibe-kanban
            +-- Tailscale (secure remote access)
```

Benefits:

* Offline operation, complete data privacy
* One-time hardware investment
* Share access via Tailscale node sharing

### Pattern 4: VS Code Remote SSH + Cloud GPU

1. Rent GPU instance
2. Configure SSH with key-based auth
3. Use VS Code Remote-SSH extension
4. Edit files directly with remote execution

## OAuth/Authentication Challenges

Headless environments struggle with OAuth flows requiring browsers.

**Workarounds:**

```bash
# SSH port forwarding for OAuth
ssh -L 8080:localhost:8080 user@remote-server
# Run login on remote, complete in local browser

# Or copy credentials after local auth
scp ~/.config/claude-code/auth.json user@remote:~/.config/claude-code/

# Docker: mount credentials volume
docker run -v ~/.config/providers:/home/devuser/.config/providers ...
```

## Cost Optimization

| Strategy | Savings | Trade-off |
|----------|---------|-----------|
| Spot/Preemptible | 60-90% | May be interrupted |
| Per-minute billing | ~40% | Bursty workloads only |
| Reserved instances | 45-50% | 1-3 year commitment |
| Self-hosted | Break-even 6-12mo | Upfront hardware cost |

**Hidden costs to watch:**

* Storage: $0.10-0.30/GB/month
* Data egress (Lambda has zero egress)
* Base subscription requirements

## Headless Mode

vibe-kanban has a headless mode for daemons/systemd:

```bash
NODE_ENV=production
CODING_AGENT_MODE=server
HOST=0.0.0.0
BACKEND_PORT=3001
```

Features:

* Skips auto-opening browser
* Exposes `/api/health` endpoint
* Supports SIGINT/SIGTERM graceful shutdown

## Limitations for Remote Deployment

1. **No official Docker image** - Community maintained
2. **No desktop notifications** - Webhook feature requested
3. **No systemd service file** provided
4. **Documentation focuses on local** execution

## Recommended Setup

For DigitalOcean/similar VPS:

1. **OS**: Ubuntu 22.04 LTS
2. **Session**: tmux for persistence
3. **Access**: Tailscale or Cloudflare Tunnel
4. **Editor**: VS Code Remote SSH
5. **Auth**: Pre-authenticate locally, copy credentials

## Community Links

* [Hacker News: Show HN vibe-kanban](https://news.ycombinator.com/item?id=44533004)
* [VirtusLab Blog](https://virtuslab.com/blog/ai/vibe-kanban/)
* [r/LocalLLaMA](https://reddit.com/r/LocalLLaMA) - Self-hosted AI patterns
* [r/selfhosted](https://reddit.com/r/selfhosted) - Docker + Tailscale patterns
