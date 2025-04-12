#!/bin/bash

# SPDX-License-Identifier: MPL-2.0

set -e

# Optional container bootstrap
if [ -x /usr/local/bin/startup-check.sh ]; then
  echo "[ttyd-wrapper] Running startup-check.sh..."
  /usr/local/bin/startup-check.sh || echo "[!] startup-check.sh failed but continuing"
else
  echo "[ttyd-wrapper] No startup-check.sh found. Skipping bootstrap."
fi

# Start or reuse the dev tmux session with a looping shell
tmux has-session -t dev 2>/dev/null || \
  tmux new-session -d -s dev 'while true; do bash; done'

# Pipe all output to the log file
tmux pipe-pane -o -t dev "cat >> /var/log/terminal.log" || true

# Loop to ensure ttyd restarts if it crashes
while true; do
  ttyd --writable -p 7681 tmux attach-session -t dev
  sleep 1
done