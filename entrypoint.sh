#!/bin/bash
set -euo pipefail

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
  git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git /app/custom_nodes/ComfyUI-Manager
else
  if [ "${COMFYUI_MANAGER_AUTO_UPDATE:-false}" = "true" ]; then
    echo "Updating ComfyUI-Manager..."
    git -C /app/custom_nodes/ComfyUI-Manager pull --ff-only || {
      echo "Failed to update ComfyUI-Manager." >&2
      exit 1
    }
  fi
fi

install_custom_node_requirements

echo "Starting ComfyUI..."
exec python3 main.py --listen 0.0.0.0 --port 8188
