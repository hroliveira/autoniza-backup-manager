#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Redis Backup
# ═══════════════════════════════════════════════════════════════

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logger.sh
source "${SCRIPT_DIR}/logger.sh"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/docker.sh"

# ── Snapshot Redis via Docker ─────────────────────────────────
# Uso: backup_redis <container> <output_file>
backup_redis() {
  local container="$1"
  local output_file="$2"

  log_step "Realizando snapshot do Redis (container: $container)"

  if ! docker_container_running "$container"; then
    log_error "Container $container não está disponível. Snapshot do Redis cancelado."
    return 1
  fi

  # Usa redis-cli SAVE para gerar snapshot no container e depois copia
  local dump_dest
  dump_dest="$(mktemp -d)/dump.rdb"

  if docker exec "$container" redis-cli SAVE 2>>"${LOG_FILE:-/dev/null}"; then
    log_info "SAVE executado no Redis. Copiando dump.rdb..."

    # Tenta copiar o dump.rdb padrão do Redis
    if docker cp "${container}:/data/dump.rdb" "$dump_dest" 2>/dev/null || \
       docker cp "${container}:/var/lib/redis/dump.rdb" "$dump_dest" 2>/dev/null; then
      cp "$dump_dest" "$output_file"
      if [[ -s "$output_file" ]]; then
        local size
        size="$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)"
        log_success "Snapshot Redis concluído ($(human_size "$size"))."
        rm -rf "$(dirname "$dump_dest")"
        return 0
      fi
    fi
  fi

  log_error "Falha ao realizar snapshot do Redis."
  rm -rf "$(dirname "$dump_dest")" 2>/dev/null || true
  return 1
}
