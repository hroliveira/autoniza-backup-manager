#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_DOCKER_LOADED:-}" ]] && return 0
ABM_DOCKER_LOADED=1
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Docker Utilities
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"

# ── Verificar se container está rodando ───────────────────────
docker_container_running() {
  local container="$1"
  local status
  status="$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")"
  if [[ "$status" == "running" ]]; then
    return 0
  else
    log_warn "Container '$container' não está rodando (status: $status)."
    return 1
  fi
}

# ── Executar comando dentro de um container ──────────────────
docker_exec() {
  local container="$1"
  shift
  docker exec "$container" "$@"
}

# ── Copiar arquivo de dentro de um container ─────────────────
docker_cp_from() {
  local container="$1"
  local source="$2"
  local dest="$3"
  docker cp "${container}:${source}" "$dest"
}
