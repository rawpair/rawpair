# SPDX-License-Identifier: MPL-2.0

FROM debian:bookworm

# Base setup
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    libjson-c5 \
    libwebsockets17 \
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
    build-essential \
    autoconf \
    automake \
    make \
    git \
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

# Create dev user and working directory
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
EXPOSE 7681

WORKDIR /home/devuser/

RUN git clone https://github.com/LibertyEiffel/Liberty

# RUN wget https://download.savannah.gnu.org/releases/liberty-eiffel/bell.tar.gz
# RUN tar -zxf /home/devuser/bell.tar.gz

# WORKDIR /home/devuser/bell
WORKDIR /home/devuser/Liberty
RUN ./install.sh

ENV PATH="/home/devuser/Liberty/target/bin:$PATH"

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/rawpair.conf"]
