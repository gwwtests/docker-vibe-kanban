# syntax=docker/dockerfile:1.4
FROM archlinux:latest

# ============================================
# vibe-kanban-docker: Arch Linux Development Container
# ============================================
#
# This is an Arch Linux-based container for running vibe-kanban.
# We use Arch (not Alpine like upstream) because:
#   - AUR access for cutting-edge AI CLI tools
#   - Full glibc (not musl) for broader compatibility
#   - pacman + yay for easy package management
#
# vibe-kanban upstream Dockerfile:
#   https://github.com/BloopAI/vibe-kanban/blob/main/Dockerfile
#
# Key differences from upstream:
#   - Arch Linux instead of Alpine
#   - All dev tools pre-installed (not minimal runtime)
#   - Dynamic UID/GID mapping for host user compatibility
#   - Shared providers volume for credentials
#
# ============================================
# vibe-kanban Requirements (from upstream README):
# ============================================
#   - Rust: Latest stable (REQUIRED - vibe-kanban is Rust-based)
#   - Node.js: 18+
#   - pnpm: 8+
#   - cargo-watch, sqlx-cli: For development
#
# ============================================
# Port Configuration (IMPORTANT FOR DEBUGGING):
# ============================================
# vibe-kanban reads port from environment variables:
#   1. BACKEND_PORT (highest priority)
#   2. PORT
#   3. Falls back to 0 (auto-assign) if neither set
#
# We set PORT explicitly to our allocated port.
# If vibe-kanban doesn't start or isn't accessible:
#   - Check: docker logs <container>
#   - Verify: PORT env var is set correctly
#   - Check: /tmp/vibe-kanban/vibe-kanban.port inside container
#   - Ensure: HOST=0.0.0.0 (binds to all interfaces)
#
# Reference:
#   https://github.com/BloopAI/vibe-kanban/blob/main/crates/server/src/main.rs
# ============================================
#
# BUILD CACHING PRINCIPLES:
#   - Layers ordered from most stable to least stable
#   - COPY statements deferred as late as possible
#   - Each RUN step is a separate layer for granular caching
#   - Changes to later layers don't invalidate earlier ones
#
# ============================================

LABEL maintainer="vibe-kanban-docker"
LABEL description="Arch Linux sandbox for vibe-kanban AI development"
LABEL vibe-kanban.upstream="https://github.com/BloopAI/vibe-kanban"

# ============================================
# Layer 1: Keyring & System Update (very stable)
# ============================================
# Initialize Arch keyring first - required for package verification
RUN pacman -Sy --noconfirm archlinux-keyring && \
    pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syyu --noconfirm

# ============================================
# Layer 2: Build Dependencies for AUR (stable)
# ============================================
# These are needed to build yay and AUR packages
RUN pacman -S --needed --noconfirm \
    base-devel \
    git \
    sudo \
    go \
    expac \
    jq \
    perl \
    make \
    meson \
    python \
    fakechroot \
    gtest

# ============================================
# Layer 3: User Setup & Sudoers (stable)
# ============================================
# Create non-root user with passwordless sudo for AUR builds
# UID/GID can be overridden at build time to match host user
ARG USER_UID=1000
ARG USER_GID=1000

RUN echo "devuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/devuser && \
    groupadd --gid $USER_GID devuser && \
    useradd --uid $USER_UID --gid $USER_GID -m -G wheel -s /bin/bash devuser

# ============================================
# Layer 4: Build & Install Yay (stable)
# ============================================
# Yay is our AUR helper - must be built as non-root
USER devuser
WORKDIR /home/devuser

RUN git clone https://aur.archlinux.org/yay.git && \
    cd yay && \
    makepkg --noconfirm && \
    sudo pacman -U --noconfirm yay-*.pkg.tar.zst && \
    cd .. && \
    rm -rf yay

# ============================================
# Layer 5: Core System Tools (very stable)
# ============================================
USER root
RUN pacman -S --needed --noconfirm \
    vim \
    neovim \
    git \
    tig \
    tmux \
    screen \
    wget \
    curl \
    aria2 \
    htop \
    mc \
    jq \
    ripgrep \
    fd \
    bat \
    fzf \
    openssh \
    ca-certificates \
    less \
    tree \
    procps-ng \
    iproute2 \
    net-tools \
    bind

# ============================================
# Layer 6: Node.js & pnpm (stable)
# ============================================
# vibe-kanban requires Node.js 18+ and pnpm 8+
RUN pacman -S --needed --noconfirm nodejs npm && \
    npm install -g pnpm@latest

# ============================================
# Layer 7: Rust Toolchain (stable)
# ============================================
# REQUIRED: vibe-kanban is a Rust application
RUN pacman -S --needed --noconfirm rustup

USER devuser
RUN rustup default stable && \
    rustup component add clippy && \
    rustup component add rustfmt

# ============================================
# Layer 8: Cargo Tools (moderate stability)
# ============================================
# Required for vibe-kanban development
RUN cargo install cargo-watch && \
    cargo install sqlx-cli

# ============================================
# Layer 9: GitHub CLI via AUR (moderate stability)
# ============================================
RUN EDITOR=cat yay -S --noconfirm github-cli

# ============================================
# Layer 10: AI CLI Tools via npm (less stable)
# ============================================
# Claude Code - primary AI assistant
USER root
RUN npm install -g @anthropic-ai/claude-code

# Other AI tools (may need different install methods)
# These are optional - failures won't break the build
USER devuser
RUN EDITOR=cat yay -S --noconfirm openai-cli 2>/dev/null || \
    echo "Note: openai-cli not available in AUR, install manually if needed"

# ============================================
# Layer 11: Environment Setup (stable)
# ============================================
USER root
ENV PATH="/home/devuser/.cargo/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:${PATH}"
ENV EDITOR=vim

# Also persist in .bashrc for interactive shells
USER devuser
RUN echo 'export PATH="/home/devuser/.cargo/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:${PATH}"' >> ~/.bashrc && \
    echo 'export EDITOR=vim' >> ~/.bashrc

# ============================================
# Layer 12: Create Provider Directories (stable)
# ============================================
USER root
RUN mkdir -p /home/devuser/.config/providers && \
    mkdir -p /home/devuser/.config/providers/env && \
    chown -R devuser:devuser /home/devuser/.config

# ============================================
# Layer 13: Clean Package Caches (stable)
# ============================================
RUN pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* && \
    rm -rf /home/devuser/.cache/yay/* 2>/dev/null || true

# ============================================
# Layer 14: COPY startup script (late as possible)
# ============================================
# This layer invalidates only when container-startup.sh changes
COPY --chown=devuser:devuser scripts/container-startup.sh /usr/local/bin/container-startup.sh
RUN chmod +x /usr/local/bin/container-startup.sh

# ============================================
# Final: User & Entrypoint
# ============================================
USER devuser
WORKDIR /home/devuser

# Default HOST for container accessibility
ENV HOST=0.0.0.0

ENTRYPOINT ["/usr/local/bin/container-startup.sh"]
CMD ["/bin/bash"]
