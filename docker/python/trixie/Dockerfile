# SPDX-License-Identifier: MPL-2.0

FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    LOG_USER_ID=devuser \
    LOG_WORKSPACE_ID=default \
    LOG_SESSION_ID=dev-session

# Install core system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    wget \
    git \
    ca-certificates \
    build-essential \
    cmake \
    ninja-build \
    clang \
    pkg-config \
    supervisor \
    tmux \
    nano \
    vim \
    emacs \
    bash \
    file \
    procps \
    libwebsockets-dev \
    libjson-c-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ttyd (arch-aware)
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64)   BINARY="ttyd.x86_64" ;; \
        aarch64)  BINARY="ttyd.aarch64" ;; \
        armv7l)   BINARY="ttyd.armhf" ;; \
        armv6l)   BINARY="ttyd.arm" ;; \
        i686)     BINARY="ttyd.i686" ;; \
        *)        echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -L "https://github.com/tsl0922/ttyd/releases/download/1.7.7/${BINARY}" -o /usr/local/bin/ttyd; \
    chmod +x /usr/local/bin/ttyd

# Install Vector
RUN curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y --prefix /usr/local

# Install pipx (bypass PEP 668 restrictions)
RUN python3 -m pip install --no-cache-dir pipx --break-system-packages && \
    pipx ensurepath

# Core Python dev tools & CLIs
RUN pip3 install --no-cache-dir --break-system-packages \
    ipython ptpython rich textual click typer jupyterlab notebook \
    python-dotenv loguru httpx requests tqdm colorama tabulate yaspin

# Dev & test ecosystem
RUN pip3 install --no-cache-dir --break-system-packages \
    pytest pytest-cov pytest-mock pytest-asyncio \
    coverage debugpy icecream tox

# Linting, formatting, type-checking
RUN pip3 install --no-cache-dir --break-system-packages \
    black isort ruff flake8 mypy pylint

# Packaging & project management
RUN pip3 install --no-cache-dir --break-system-packages \
    pipdeptree pip-audit build twine

# Useful serialization + CLI plumbing
RUN pip3 install --no-cache-dir --break-system-packages \
    joblib dill cloudpickle sh python-slugify

# Web / API backend tooling
RUN pip3 install --no-cache-dir --break-system-packages \
    fastapi uvicorn[standard] pydantic

# Security & crypto helpers
RUN pip3 install --no-cache-dir --break-system-packages \
    cryptography passlib

RUN pipx install poetry

# Add user
RUN useradd -ms /bin/bash devuser
WORKDIR /home/devuser/app
RUN chown devuser:devuser /home/devuser/app

RUN mkdir -p \
        /var/log \
        /var/lib/vector \
        /var/log/vector \
        /var/run \
        /home/devuser/run && \
    chown -R devuser:devuser \
        /var/log \
        /var/lib/vector \
        /var/log/vector \
        /var/run \
        /home/devuser/run

# Vector config
COPY --chown=devuser:devuser vector.toml /etc/vector/vector.toml

# Supervisord config
COPY --chown=devuser:devuser supervisord.conf /home/devuser/supervisord.conf

# TTYD wrapper script
COPY ttyd-wrapper.sh /usr/local/bin/ttyd-wrapper.sh
RUN chmod +x /usr/local/bin/ttyd-wrapper.sh

# .bashrc tweaks to trap exits
RUN echo 'trap "" EXIT' >> /home/devuser/.bashrc && \
    echo 'alias exit="echo Nope."' >> /home/devuser/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/devuser/.bashrc && \
    chown devuser:devuser /home/devuser/.bashrc && \
    chmod 0444 /home/devuser/.bashrc

USER devuser

EXPOSE 6006 7681 10000

CMD ["supervisord", "-c", "/home/devuser/supervisord.conf"]
