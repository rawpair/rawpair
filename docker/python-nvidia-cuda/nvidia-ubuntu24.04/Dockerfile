# SPDX-License-Identifier: MPL-2.0

FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

# Non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    cmake \
    ninja-build \
    clang \
    git \
    curl \
    wget \
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

# Numerical & data science core
RUN pip3 install --no-cache-dir --break-system-packages \
    numpy scipy pandas scikit-learn matplotlib seaborn plotly

# Interactive environments
RUN pip3 install --no-cache-dir --break-system-packages \
    jupyterlab notebook ipython

# Deep learning frameworks
RUN pip3 install --no-cache-dir --break-system-packages \
    torch torchvision torchaudio \
    tensorflow keras tf-keras

# Gradient boosting / tabular models
RUN pip3 install --no-cache-dir --break-system-packages \
    xgboost lightgbm catboost

# Transformers and NLP tooling
RUN pip3 install --no-cache-dir --break-system-packages \
    transformers datasets accelerate tokenizers \
    sentence-transformers faiss-cpu

# Experiment management & config
RUN pip3 install --no-cache-dir --break-system-packages \
    optuna mlflow hydra-core pydantic

# Web service & UI prototyping
RUN pip3 install --no-cache-dir --break-system-packages \
    fastapi uvicorn gradio streamlit

# Serialization & execution helpers
RUN pip3 install --no-cache-dir --break-system-packages \
    joblib dill cloudpickle

# Formatting, linting, type checking
RUN pip3 install --no-cache-dir --break-system-packages \
    black isort ruff flake8 mypy pylint

# Testing
RUN pip3 install --no-cache-dir --break-system-packages \
     pytest pytest-cov tox

# Rich output & CLI toys
RUN pip3 install --no-cache-dir --break-system-packages \
    rich httpie

RUN pipx install poetry

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

ENV TERM=xterm \
    LOG_USER_ID=devuser \
    LOG_WORKSPACE_ID=default \
    LOG_SESSION_ID=dev-session

USER devuser

EXPOSE 6006 7681 10000

CMD ["supervisord", "-c", "/home/devuser/supervisord.conf"]
