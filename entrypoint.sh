#!/bin/bash
set -euo pipefail

PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting with PUID=${PUID}, PGID=${PGID}"

if [ "$(id -u comfyui)" != "${PUID}" ] || [ "$(id -g comfyui)" != "${PGID}" ]; then
  echo "Updating comfyui user UID:GID to ${PUID}:${PGID}..."

  groupmod -o -g "${PGID}" comfyui
  usermod -o -u "${PUID}" comfyui
  echo "Updating ownership of /app directories..."
  chown -R comfyui:comfyui /app

  echo "Configuring git safe directories..."
  gosu comfyui git config --global --add safe.directory '*'
fi

install_requirements() {
  local req_file="$1"
  echo "Installing requirements from ${req_file}..."
  uv pip install --system --no-cache-dir -r "${req_file}"
}

install_custom_node_requirements() {
  shopt -s nullglob
  local req_list=(
    /app/custom_nodes/*/requirements*.txt
  )

  for req in "${req_list[@]}"; do
    [ -f "${req}" ] || continue
    install_requirements "${req}"
  done
  shopt -u nullglob
}

# Ensure uv is available before continuing so failures are clear
if ! command -v uv >/dev/null 2>&1; then
  echo "uv command not found. Verify the Docker image includes uv." >&2
  exit 1
fi

# Make sure the custom_nodes directory exists even if the bind mount is missing
mkdir -p /app/custom_nodes

if [ ! -d "/app/custom_nodes/ComfyUI-Manager" ]; then
  echo "Installing ComfyUI-Manager..."
  gosu comfyui git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git /app/custom_nodes/ComfyUI-Manager
else
  if [ "${COMFYUI_MANAGER_AUTO_UPDATE:-false}" = "true" ]; then
    echo "Updating ComfyUI-Manager..."
    gosu comfyui git -C /app/custom_nodes/ComfyUI-Manager pull --ff-only || {
      echo "Warning: Failed to update ComfyUI-Manager. Continuing..." >&2
    }
  fi
fi

install_custom_node_requirements

echo "Starting ComfyUI as user comfyui (UID=${PUID}, GID=${PGID})..."
exec gosu comfyui python3 main.py --listen 0.0.0.0 --port 8188
