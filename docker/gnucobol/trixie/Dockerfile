FROM debian:trixie-slim

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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -L https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.aarch64 -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

ENV TERM xterm

EXPOSE 7681

CMD ["ttyd", "--writable", "-p", "7681", "tmux", "new", "-A", "-s", "dev", "bash"]