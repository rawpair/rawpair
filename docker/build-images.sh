#!/bin/bash

set -e

FILTER=""
DRY_RUN=0
JOBS=${JOBS:-2}

# Parse args
for arg in "$@"; do
  case "$arg" in
    --filter=*)
      FILTER="${arg#--filter=}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

echo "Building RawPair Docker images${FILTER:+ for '$FILTER'} with $JOBS parallel jobs..."
[ "$DRY_RUN" -eq 1 ] && echo "(dry-run mode enabled, no builds will be executed)"

# Prepare build commands
BUILD_CMDS=()
while IFS= read -r dockerfile; do
  image_dir=$(dirname "$dockerfile")
  rel_path="${image_dir#./}"

  if [[ -n "$FILTER" && "$rel_path" != "$FILTER/"* ]]; then
    continue
  fi

  image_name=$(echo "$rel_path" | tr '/' ':')
  cmd="echo 'Building $image_name'; docker build -f '$dockerfile' -t '$image_name' ."
  BUILD_CMDS+=("$cmd")
done < <(find . -name Dockerfile)

# Execute in parallel
if [[ "$DRY_RUN" -eq 1 ]]; then
  for cmd in "${BUILD_CMDS[@]}"; do
    echo "[dry-run] $cmd"
  done
else
  printf "%s\n" "${BUILD_CMDS[@]}" | xargs -P "$JOBS" -n 1 -I {} bash -c '{}'
fi

echo "All matching images built${DRY_RUN:+ (dry-run)} successfully."
