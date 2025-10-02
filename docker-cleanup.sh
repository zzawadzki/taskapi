#!/usr/bin/env bash
set -euo pipefail

# docker-cleanup.sh
# Stops Compose services, removes project containers, removes task-api:* images,
# optionally removes volumes, and shows disk space freed.
#
# Usage:
#   ./docker-cleanup.sh [-v] [-y]
#   ./docker-cleanup.sh -h
#
# Options:
#   -v   Also remove named volumes from docker-compose (with confirmation unless -y)
#   -y   Assume "yes" to all confirmations (non-interactive)
#   -h   Show this help
#
# Notes:
# - This script targets images named "task-api:*" specifically.
# - It will try to use `docker compose` and fall back to `docker-compose`.

PROJECT_NAME="task-api"
REMOVE_VOLUMES=false
ASSUME_YES=false

print_help() {
  sed -n '1,50p' "$0" | sed -n '1,30p' | sed 's/^# \{0,1\}//' | sed '/^$/q' || true
  cat <<'EOF'
Examples:
  ./docker-cleanup.sh           # stop and remove containers, remove task-api:* images
  ./docker-cleanup.sh -v        # also remove named volumes (asks for confirmation)
  ./docker-cleanup.sh -v -y     # remove volumes without prompting
EOF
}

confirm() {
  local prompt="$1"
  if $ASSUME_YES; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " reply
  case "$reply" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

human_to_bytes() {
  # Convert docker size strings like "123kB", "45.6MB", "1.2GB" to bytes
  local size="$1"
  # Normalize to upper and remove spaces
  size=$(echo "$size" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
  # Extract number and unit
  local num unit
  num=$(echo "$size" | sed -E 's/([0-9]+\.?[0-9]*).*/\1/')
  unit=$(echo "$size" | sed -E 's/[0-9]+\.?[0-9]*\s*([A-Z]*B).*/\1/')
  # Default to bytes if no unit
  case "$unit" in
    B|BYTE|BYTES|) factor=1 ;;
    KB) factor=1024 ;;
    MB) factor=$((1024**2)) ;;
    GB) factor=$((1024**3)) ;;
    TB) factor=$((1024**4)) ;;
    *) factor=1 ;;
  esac
  # Use awk for floating multiplication
  awk -v n="$num" -v f="$factor" 'BEGIN { printf "%.0f\n", n * f }'
}

bytes_to_human() {
  local bytes=$1
  local unit=(B KB MB GB TB)
  local i=0
  while (( bytes >= 1024 && i < ${#unit[@]}-1 )); do
    bytes=$((bytes/1024))
    ((i++))
  done
  echo "$bytes ${unit[$i]}"
}

compose_cmd() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "" 
  fi
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed or not in PATH" >&2
    exit 1
  fi
}

images_size_bytes() {
  # Sum sizes of images whose repository is exactly PROJECT_NAME (task-api)
  local total=0
  while IFS= read -r line; do
    # line format: "REPO:TAG SIZE" (e.g., "task-api:latest 123MB")
    local size
    size=$(echo "$line" | awk '{print $2}')
    if [[ -n "$size" ]]; then
      local b
      b=$(human_to_bytes "$size")
      total=$((total + b))
    fi
  done < <(docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | awk -v repo="$PROJECT_NAME" -F: '$1==repo {print $0}' | awk '{print $1" "$2}')
  echo "$total"
}

remove_task_api_images() {
  local ids
  # Collect image IDs for task-api:* repositories
  mapfile -t ids < <(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | awk -v repo="$PROJECT_NAME" -F: '$1==repo {print $2}' | awk '{print $2}')
  if (( ${#ids[@]} > 0 )); then
    echo "Removing images for ${PROJECT_NAME}:* (${#ids[@]} image(s))"
    docker rmi -f "${ids[@]}" || true
  else
    echo "No images found matching ${PROJECT_NAME}:*"
  fi
}

main() {
  while getopts ":vyh" opt; do
    case $opt in
      v) REMOVE_VOLUMES=true ;;
      y) ASSUME_YES=true ;;
      h) print_help; exit 0 ;;
      :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
      \?) echo "Unknown option: -$OPTARG" >&2; print_help; exit 1 ;;
    esac
  done

  require_docker

  local CMD
  CMD=$(compose_cmd)
  if [[ -z "$CMD" ]]; then
    echo "Error: docker compose or docker-compose not found" >&2
    exit 1
  fi

  # Compute size of task-api images before removal
  local size_before
  size_before=$(images_size_bytes)

  echo "Bringing down Docker Compose services..."
  if $REMOVE_VOLUMES; then
    if confirm "Also remove named volumes defined by docker-compose?"; then
      echo "Running: $CMD down -v"
      $CMD down -v || true
    else
      echo "Skipping volume removal"
      echo "Running: $CMD down"
      $CMD down || true
    fi
  else
    echo "Running: $CMD down"
    $CMD down || true
  fi

  echo "Removing project images (${PROJECT_NAME}:*)..."
  remove_task_api_images

  # Compute size after removal
  local size_after
  size_after=$(images_size_bytes)

  local freed_bytes=$(( size_before - size_after ))
  if (( freed_bytes < 0 )); then
    freed_bytes=0
  fi
  local freed_human
  freed_human=$(bytes_to_human "$freed_bytes")

  echo "Disk space freed (images ${PROJECT_NAME}:*): $freed_human"
  echo "Done."
}

main "$@"
