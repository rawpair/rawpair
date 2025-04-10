FROM debian:trixie-slim

# Base setup
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnucobol \
    bash \
    curl \
    libjson-c5 \
    libwebsockets19t64 \
    ca-certificates \
    libssl3 \
    procps \
    tmux \
    vim \
    emacs \
    nano \
    git \
    file \
    supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ttyd (arch-aware with mapped names)
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

# Install Vector cleanly into /usr/local (adds to PATH, no profile hacks)
RUN curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y --prefix /usr/local

# Create dev user and working directory
RUN useradd -ms /bin/bash devuser
WORKDIR /home/devuser/app
RUN chown devuser:devuser /home/devuser/app

RUN mkdir -p /var/log && chown devuser:devuser /var/log
RUN mkdir -p /var/lib/vector && chown devuser:devuser /var/lib/vector
RUN mkdir -p /var/log/vector && chown devuser:devuser /var/log/vector

RUN mkdir -p /var/run && chown devuser:devuser /var/run

# Vector config
COPY --chown=devuser:devuser vector.toml /etc/vector/vector.toml

# Supervisord config
COPY --chown=devuser:devuser supervisord.conf /etc/supervisor/conf.d/rawpair.conf

# Environment
ENV TERM xterm \
    LOG_USER_ID=devuser \
    LOG_WORKSPACE_ID=default \
    LOG_SESSION_ID=dev-session

USER devuser
EXPOSE 7681

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/rawpair.conf"]
