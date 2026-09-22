# 2026-09-22 — a mount-less idle container, and upstream's sunset

All facts below were measured on 2026-09-22 against a real container, `vkb_<project>`, that
had been running for two weeks. In what follows, `<project>` is some directory on the host.

## 1. Why a running container can have no project mounted in it

The container has only one mount: the `vibe_kanban_providers` volume. Its metadata
(`~/.config/vibe-kanban-docker/containers/vkb_<project>.yaml`) says `directory: <project>`, but
that project is **not** mounted in it. This is how the script is meant to behave. The container is not
mounting anything lazily later, and it is not broken in some other way:

* `vibe-kanban-docker` names a container after the **current directory**
  (`resolve_container_name "$target_dir"`) but mounts **only the paths passed as arguments**
  (`parse_mounts "$@"`). If you run it with no path arguments, you get a container with no mounts.
  `--help` and `CHEATSHEET.md` both say so: `run  # No mounts`.
* `cmd_run` still sets `WORKSPACE_DIR` to the current directory. It falls back to `target_dir`
  when no path argument is given, so the variable points at a path that does not exist inside the
  container.
* `scripts/container-startup.sh` starts vibe-kanban only when `-d "$WORKSPACE_DIR"`. Otherwise it
  runs `exec tail -f /dev/null`.
* Nothing mounts a project later. `shell` and `exec` are plain `docker exec` calls.

The live container confirms this:

| check | result |
|---|---|
| metadata `mounts:` | **empty** ⇒ created with zero path args |
| `docker logs` (all 4 lines) | `No WORKSPACE_DIR set or directory doesn't exist.` / `Starting idle shell…`, printed once at creation and once at restart |
| `docker top` | PID 1 = `tail -f /dev/null`, and nothing else |
| vibe-kanban ever ran inside? | no, because `docker diff` shows no `~/.vibe-kanban` |
| created | 2026-09-06 12:06 CEST |
| started | 2026-09-07 14:28 CEST, the same minute the host booted and `docker.service` came up |
| restart policy | `unless-stopped`, restarts = 0 |

⇒ **"Up 2 weeks" does not show anyone used it.** Docker restarted it at boot because of
`--restart unless-stopped`. The port it publishes, 15173, is bound on `0.0.0.0` and `[::]`, but
nothing listens there.

**What did happen on 2026-09-06.** About a minute after the container was created, Claude Code
ran inside it. Its npm update check (`npm view @anthropic-ai/claude-code@latest version`) left logs
timestamped 10:07:29–36Z. `~/.claude` and `~/.config/gh` were created as symlinks into the providers
volume. That fits `vibe-kanban-docker providers login`, run from `<project>`
when no container existed yet. `cmd_providers_login` then calls `cmd_run` **with no arguments**,
which gives exactly this container with no mounts. Shell history and Claude transcripts do not
show the command, so this is the most likely explanation, not a proven one.

⇒ The container has probably done its job already (it was the vehicle for logging in to the
providers). Its credentials live in the shared volume, not in the container. **One exception:**
`~/.claude.json` is a real file in the container's writable layer, not a symlink into the
volume. Removing the container would lose it (Claude Code's account and onboarding state; the
OAuth token itself is in `~/.claude/` → volume). The owner decides whether to remove
it. Nobody has stopped or removed it.

## 2. Wrapper defects this exposed

1. **`providers login` quietly creates a container for the current directory with nothing
   mounted**, and that container then idles forever with `--restart unless-stopped`. It should
   use a throwaway `docker run --rm` against the volume, which `providers status/reset` already
   do, or at least warn.
2. **`WORKSPACE_DIR` falls back to a host path that was never mounted.** It should fall back to
   nothing, or `run` should refuse to start without a mount.
3. **`~/.claude.json` is not persisted** in the providers volume, while `~/.claude/` is. A new
   container therefore loses Claude Code's account and onboarding state.
4. **The port is published on every interface** (`-p ${port}:${port}`). `HOST=0.0.0.0` is needed
   inside the container, but the host side should be `-p 127.0.0.1:${port}:${port}`. Right now this
   exposes only an idle port. Once vibe-kanban runs, it would expose an unauthenticated agent
   orchestrator to the LAN.

## 3. Upstream drift, and upstream is sunsetting

* ⛔ **bloop, the company behind vibe-kanban, shut down on 2026-04-10**
  (vibekanban.com/blog/shutdown, "Goodbye bloop"). The upstream README now opens with
  *"Vibe Kanban is sunsetting."* The project is meant to continue as community-maintained
  Apache-2.0. Secondary sources (not verified here) say bloop's remote/cloud service was turned
  off about 30 days later, and that the community has shipped nothing since.
* **Last release is v0.1.44 (2026-04-24).** `npm view vibe-kanban` shows `latest = 0.1.44`, and
  the package is not deprecated.
* **The wrapper does not pin a version.** The startup script runs `npx vibe-kanban`, so a fresh
  container fetches **0.1.44** today. A `v0.0.148` on the host
  is only the **host's** own npx cache (`~/.vibe-kanban/bin/`, `~/.npm/_npx/…`).
* `tmp/vibe-kanban/` (ignored by git) **is** an upstream checkout, at `393aeb0`, 2026-01-16. It
  is a reading copy made when the wrapper was being written. I did not fetch or update it.
* **The npm launcher downloads a prebuilt binary at run time from bloop's CDN**
  (`R2_BASE_URL = https://npm-cdn.vibekanban.com`). On 2026-09-22 these returned HTTP 200:
  `binaries/manifest.json`, `binaries/v0.0.148-…/manifest.json` and
  `binaries/v0.1.44-20260424091429/manifest.json`. ⛔ **This is the wrapper's single point of
  failure.** When that CDN goes dark, `npx vibe-kanban` stops working in every new container,
  whatever state this repo is in. Nothing in this repo caches or vendors the binary.
* 0.1.44 still defaults to browser/server mode. The Tauri desktop app is opt-in via `--desktop`,
  so running it headless in Docker still works. I have **not tested** whether 0.1.44 still
  respects `PORT` and `HOST`, which `FUTURE_WORK.md` already lists as a TODO.

## 4. What is actually unfinished, versus just old

Nothing in the repo is half-done. The tree is clean, and the design doc says `Status: Approved`
and was implemented. `FUTURE_WORK.md` is a wish list (TTL cleanup, a port command, health checks,
image variants, backup and restore), and none of it was started.

**Unfinished in a way that matters now**, given §2 and §3:

* the four defects in §2
* **keeping the binary alive:** vendor or cache the `vibe-kanban` binary into the image or a
  volume, or build it from source. `tmp/vibe-kanban` plus the Rust toolchain already in the image
  make source builds possible. Do this before bloop's CDN goes away.
* checking that `PORT`/`HOST` work on 0.1.44 (the existing TODO)
* ⚠ **A strategic question for the owner:** is it still worth investing in a wrapper around an
  upstream whose company has shut down? The honest options are: freeze it (it works today),
  harden it (cache the binary and fix §2), or retire it.
