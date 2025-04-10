#!/bin/bash
set -e

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