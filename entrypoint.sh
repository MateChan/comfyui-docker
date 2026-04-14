#!/bin/bash
set -euo pipefail

PUID=${PUID:-}
PGID=${PGID:-}

detect_runtime_ids() {
  local dirs=(/app/user /app/custom_nodes /app/models /app/input /app/output)
  local dir uid gid

  for dir in "${dirs[@]}"; do
    [ -e "${dir}" ] || continue
    uid=$(stat -c '%u' "${dir}" 2>/dev/null || true)
    gid=$(stat -c '%g' "${dir}" 2>/dev/null || true)

    # Avoid mapping to root account; keep searching for a non-root owner.
    if [ -n "${uid}" ] && [ -n "${gid}" ] && [ "${uid}" != "0" ] && [ "${gid}" != "0" ]; then
      echo "${uid}:${gid}"
      return 0
    fi
  done

  echo "1000:1000"
}

if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
  detected_ids=$(detect_runtime_ids)
  detected_uid=${detected_ids%:*}
  detected_gid=${detected_ids#*:}

  PUID=${PUID:-${detected_uid}}
  PGID=${PGID:-${detected_gid}}
fi

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

ensure_writable_dir() {
  local dir="$1"
  mkdir -p "${dir}"

  # Bind mounts can keep host ownership; try to align and loosen group write where possible.
  chown -R comfyui:comfyui "${dir}" 2>/dev/null || true
  chmod -R ug+rwX "${dir}" 2>/dev/null || true

  if ! gosu comfyui test -w "${dir}"; then
    echo "Warning: ${dir} is not writable by comfyui (UID=${PUID}, GID=${PGID})." >&2
    return 1
  fi
}

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
ensure_writable_dir /app/custom_nodes || {
  echo "ComfyUI-Manager auto install/update skipped due to permissions." >&2
}

# ComfyUI needs to create per-user data under /app/user (e.g. /app/user/default).
if ! ensure_writable_dir /app/user; then
  echo "Error: /app/user must be writable by comfyui (UID=${PUID}, GID=${PGID})." >&2
  echo "Fix host permissions for ./user, then restart the container." >&2
  exit 1
fi

if gosu comfyui test -w /app/custom_nodes; then
  if [ ! -d "/app/custom_nodes/ComfyUI-Manager" ]; then
    echo "Installing ComfyUI-Manager..."
    gosu comfyui git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git /app/custom_nodes/ComfyUI-Manager || {
      echo "Warning: Failed to install ComfyUI-Manager. Continuing..." >&2
    }
  else
    if [ "${COMFYUI_MANAGER_AUTO_UPDATE:-false}" = "true" ]; then
      echo "Updating ComfyUI-Manager..."
      gosu comfyui git -C /app/custom_nodes/ComfyUI-Manager pull --ff-only || {
        echo "Warning: Failed to update ComfyUI-Manager. Continuing..." >&2
      }
    fi
  fi
fi

install_custom_node_requirements

echo "Starting ComfyUI as user comfyui (UID=${PUID}, GID=${PGID})..."
exec gosu comfyui python3 main.py --listen 0.0.0.0 --port 8188
