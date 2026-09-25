# Remote Access — using vibe-kanban from another machine, safely

vibe-kanban has **no login of its own**, and it runs coding agents with broad permissions.
Anyone who can reach its web port can make those agents run code with your credentials. This
guide covers how to run it on one machine and use it from another without exposing that port.

## 1. Run it on the host machine

1. **First time only:**

   ```bash
   git clone <this repo> ~/docker/docker-vibe-kanban
   ~/docker/docker-vibe-kanban/vibe-kanban-docker build
   ```

2. **Start it for a project.** `cd` into the project, then:

   ```bash
   ~/docker/docker-vibe-kanban/vibe-kanban-docker run --rw .
   ```

   The path argument matters. Without one, nothing is mounted, and the startup script idles
   instead of starting vibe-kanban.

3. **Stop / remove** from the same directory: `vibe-kanban-docker stop` or `vibe-kanban-docker rm`.

## 2. Use it on the host machine

Open `http://127.0.0.1:15173`. Each further project gets the next free port, and
`vibe-kanban-docker status` shows which one.

## 3. Use it from another machine: SSH tunnel

The port is published on **`127.0.0.1` only** by default (`VIBE_KANBAN_DOCKER_BIND_ADDR`).
Reach it through SSH:

```bash
ssh -N -L 15173:127.0.0.1:15173 <host>     # then open http://127.0.0.1:15173 locally
ssh -N -L 25173:127.0.0.1:15173 <host>     # if 15173 is busy locally: open :25173 instead
```

Only people who can SSH into the host as you get in. Verified end to end: the tunnel returns
HTTP 200, and a direct connection to the host's LAN or Tailscale address is refused.

## 4. Access options

| # | Option | Who gets in | Cost |
|---|--------|-------------|------|
| 1 | **Loopback publish + `ssh -L`** (the default) | whoever can SSH in as you | none |
| 2 | Tailscale ACL / grants limiting SSH or the port to your devices | only your devices | tailnet admin |
| 3 | `tailscale serve` + ACL | tailnet users the ACL allows | tailnet admin |
| 4 | Reverse proxy with login (Caddy basic auth, oauth2-proxy) | people with the login | more to maintain |
| 5 | Run it only on your own machine, and tunnel in from elsewhere | you only | none; avoids §5 |
| never | `VIBE_KANBAN_DOCKER_BIND_ADDR=0.0.0.0`, or a Tailscale IP | everyone who can reach the host | unauthenticated remote code execution |

Docker-published ports **bypass host firewalls such as ufw**. A `0.0.0.0` publish cannot be
firewalled away, which is why loopback is the default.

## 5. Shared hosts: who can read your credentials

On a machine where **other users are in the `docker` group or have sudo**, those users are
root-equivalent. They can `docker exec` into your container and read the providers volume
(Claude, GitHub and other logins), plus every mounted repo. **No network option in §4 protects
against this.** Before running `providers login` on a shared machine, choose one:

* trust those users;
* use limited, revocable credentials (a dedicated Claude token, a GitHub token scoped to a few
  repos);
* or use option 5.

Rootless Docker would isolate you from other `docker`-group members, but not from sudoers.

## 6. Known limits

* **Upstream is sunsetting.** bloop, the company behind vibe-kanban, shut down on 2026-04-10, and
  v0.1.44 (2026-04-24) is the last release. `npx vibe-kanban` downloads its binary from bloop's
  CDN on first start. That still worked on 2026-09-25, but new containers will break when the CDN
  goes away. See `ramblings/2026-09-22--idle-container-and-upstream-sunset.md`.
* **Preview proxy.** vibe-kanban's in-app preview of a dev server listens on a second, random
  port (logged at startup as `Preview proxy on :NNNNN`). That port is neither published nor
  tunnelled, so publish and forward it too if you need previews remotely.
