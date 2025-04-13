# SPDX-License-Identifier: MPL-2.0
FROM debian:trixie-slim

# Base setup
RUN apt-get update && apt-get install -y --no-install-recommends \
    gettext-base \
    gnupg2 \
    ca-certificates \
    curl \
    lsb-release \
    make \
    git \
    file \
    procps \
    nano \
    vim \
    emacs \
    tmux \
    supervisor \
    nginx \
    libjson-c5 \
    libwebsockets19t64 \
    libssl3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add Sury PHP repo
RUN curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/php-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/php-archive-keyring.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.0-cli php8.0-fpm php8.0-mbstring \
    php8.1-cli php8.1-fpm php8.1-mbstring \
    php8.2-cli php8.2-fpm php8.2-mbstring \
    php8.3-cli php8.3-fpm php8.3-mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install ttyd
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

# Create dev user
RUN useradd -ms /bin/bash devuser

RUN mkdir -p /var/lib/nginx/body && \
    chown -R devuser:devuser /var/lib/nginx

RUN mkdir -p /run/nginx && \
    chown -R devuser:devuser /run/nginx


WORKDIR /home/devuser/app
RUN chown devuser:devuser /home/devuser/app

RUN mkdir -p \
        /var/log \
        /var/lib/vector \
        /var/log/vector \
        /var/run \
        /var/run /var/log/nginx \
        /home/devuser/run && \
    chown -R devuser:devuser \
        /var/log \
        /var/lib/vector \
        /var/log/vector \
        /var/run \
        /var/run /var/log/nginx \
        /home/devuser/run

RUN mkdir -p /run/nginx && chown -R devuser:devuser /run/nginx

RUN mkdir -p /etc/nginx/sites-enabled && \
    chown -R devuser:devuser /etc/nginx/sites-enabled


# FPM
COPY php/www-8.0.conf /etc/php/8.0/fpm/pool.d/www.conf
COPY php/www-8.1.conf /etc/php/8.1/fpm/pool.d/www.conf
COPY php/www-8.2.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY php/www-8.3.conf /etc/php/8.3/fpm/pool.d/www.conf

COPY php/php-fpm-8.0.conf /etc/php/8.0/fpm/php-fpm.conf
COPY php/php-fpm-8.1.conf /etc/php/8.1/fpm/php-fpm.conf
COPY php/php-fpm-8.2.conf /etc/php/8.2/fpm/php-fpm.conf
COPY php/php-fpm-8.3.conf /etc/php/8.3/fpm/php-fpm.conf

# Nginx site configuration
COPY php/nginx.conf /etc/nginx/nginx.conf
COPY php/nginx-template.conf /etc/nginx/sites-available/template.conf
RUN mkdir -p /etc/nginx/sites-enabled

COPY php/startup-check.sh /usr/local/bin/startup-check.sh
RUN chmod +x /usr/local/bin/startup-check.sh

# Vector config
COPY --chown=devuser:devuser vector.toml /etc/vector/vector.toml

# Supervisor config
COPY --chown=devuser:devuser supervisord-php.conf /etc/supervisor/conf.d/rawpair.conf

# Helper scripts
COPY ttyd-wrapper.sh /usr/local/bin/ttyd-wrapper.sh
COPY php/switch-php.sh /usr/local/bin/switch-php
COPY php/switch-phpfpm.sh /usr/local/bin/switch-phpfpm
COPY php/index.php /home/devuser/app/index.php
RUN chmod +x /usr/local/bin/ttyd-wrapper.sh /usr/local/bin/switch-php /usr/local/bin/switch-phpfpm

# Bashrc trap and dynamic PHP version in prompt
RUN echo 'trap "" EXIT' >> /home/devuser/.bashrc && \
    echo 'alias exit="echo Nope."' >> /home/devuser/.bashrc && \
    # hash-r is required to clear bash's cache
    echo '\
switch-php() {\n\
/usr/local/bin/switch-php "$@" && hash -r\n\
}\n\
' >> /home/devuser/.bashrc && \
    echo 'export PATH="$HOME/bin:$PATH"' >> /home/devuser/.bashrc && \
    echo '\
PROMPT_COMMAND='\''\n\
  if command -v php > /dev/null; then\n\
    PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;")\n\
  else\n\
    PHP_VER="none"\n\
  fi\n\
  PS1="[\\u@\\h \\W] (php $PHP_VER)\\$ "\n\
'\''\n' >> /home/devuser/.bashrc && \
    chown devuser:devuser /home/devuser/.bashrc && \
    chmod 0444 /home/devuser/.bashrc

    RUN echo 'export PATH="$HOME/bin:$PATH"' >> /home/devuser/.bashrc


# Environment
ENV TERM=xterm \
    LOG_USER_ID=devuser \
    LOG_WORKSPACE_ID=default \
    LOG_SESSION_ID=dev-session \
    PHP_VERSION=8.3

EXPOSE 7681 10000
USER devuser

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/rawpair.conf"]
