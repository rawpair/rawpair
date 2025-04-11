FROM ubuntu:24.04
RUN apt-get update && apt-get install --no-install-recommends -y \
    m4 \
    curl \
    unzip \
    bubblewrap \
    build-essential \
    pkg-config \
    libgmp-dev \
    git \
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
    zlib1g-dev \
    bash \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64)   BINARY="opam-2.3.0-x86_64-linux" ;; \
        aarch64)  BINARY="opam-2.3.0-arm64-linux" ;; \
        armv7l)   BINARY="opam-2.3.0-armhf-linux" ;; \
        i686)     BINARY="opam-2.3.0-i686-linux" ;; \
        *)        echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -L "https://github.com/ocaml/opam/releases/download/2.3.0/${BINARY}" -o /usr/local/bin/opam; \
    chmod +x /usr/local/bin/opam



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

# Create dev user and working directory
RUN useradd -ms /bin/bash devuser
WORKDIR /home/devuser/app
RUN chown devuser:devuser /home/devuser/app

RUN mkdir -p /var/log /var/lib/vector /var/log/vector /var/run && chown -R devuser:devuser /var/log /var/lib/vector /var/log/vector /var/run

# Vector config
COPY --chown=devuser:devuser vector.toml /etc/vector/vector.toml

# Supervisord config
COPY --chown=devuser:devuser supervisord.conf /etc/supervisor/conf.d/rawpair.conf

# TTYD wrapper script
COPY ttyd-wrapper.sh /usr/local/bin/ttyd-wrapper.sh
RUN chmod +x /usr/local/bin/ttyd-wrapper.sh

# .bashrc tweaks to trap exits
RUN echo 'trap "" EXIT' >> /home/devuser/.bashrc && \
    echo 'alias exit="echo Nope."' >> /home/devuser/.bashrc && \
    chown devuser:devuser /home/devuser/.bashrc && \
    chmod 0444 /home/devuser/.bashrc

# Environment
ENV TERM=xterm \
    LOG_USER_ID=devuser \
    LOG_WORKSPACE_ID=default \
    LOG_SESSION_ID=dev-session

USER devuser

ENV HOME=/home/devuser
ENV OPAMYES=1
ENV OPAMROOT=/home/devuser/.opam
ENV PATH="/home/devuser/.opam/4.14.1/bin:$PATH"

RUN opam init --disable-sandboxing --compiler=4.14.1 -y

RUN bash -c "source /home/devuser/.opam/opam-init/init.sh > /dev/null 2>&1 && \
             opam install dune merlin ocaml-lsp-server menhir -y"

EXPOSE 7681

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/rawpair.conf"]
