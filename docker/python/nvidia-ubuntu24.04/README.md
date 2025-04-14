## README for Docker image python/nvidia-ubuntu24.04

Development container for Python with full GPU-accelerated ML/AI tooling.
Based on `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`.

**Generated images weigh over 20GB and take several minutes to build**.

### Key Features
- CUDA 12.8.1 and cuDNN
- Python 3.12 via system packages
- Full machine learning and AI ecosystem preinstalled
- System-managed Python (no pyenv)
- ttyd terminal access
- supervisord process manager

### Installed System Packages (APT)
- python3, python3-pip, python3-venv
- build-essential, git, curl, wget, pkg-config
- supervisor, tmux, nano, vim, emacs, bash, file, procps
- libwebsockets-dev, libjson-c-dev

### Installed Python Packages (PIP)
- Core: numpy, scipy, pandas, scikit-learn, matplotlib, seaborn, plotly
- Notebooks: jupyterlab, notebook, ipython
- DL Frameworks: torch, torchvision, torchaudio (CUDA), tensorflow, keras
- ML Frameworks: xgboost, lightgbm, catboost
- NLP/LLM: transformers, datasets, accelerate, tokenizers, sentence-transformers, faiss-cpu
- MLOps: optuna, mlflow, hydra-core, pydantic
- Serving/UI: fastapi, uvicorn, gradio, streamlit
- Utilities: joblib, dill, cloudpickle
- Dev Tools: black, isort, ruff, flake8, mypy, pylint, pytest, pytest-cov, tox, rich, httpie

### Environment
- Default user: `devuser`
- Working dir: `/home/devuser/app`
- Ports exposed: 7681 (ttyd), 10000 (user-defined)

### Usage
```sh
docker run --rm -it \
  --gpus all \
  -p 7681:7681 -p 10000:10000 \
  beyondtabs/python-dev:gpu-ml
```

### Notes
- Requires NVIDIA Container Toolkit on host
- Expects GPU-capable host with compatible drivers
- Python packages installed with --break-system-packages
- supervisord config expected at /home/devuser/supervisord.conf

