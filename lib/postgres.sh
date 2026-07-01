#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_POSTGRES_LOADED:-}" ]] && return 0
ABM_POSTGRES_LOADED=1
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - PostgreSQL Backup
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/docker.sh"

# ── Backup de banco PostgreSQL via Docker ─────────────────────
# Uso: backup_postgres <container> <database> <user> <output_file>
backup_postgres() {
  local container="$1"
  local database="$2"
  local user="$3"
  local output_file="$4"

  log_step "Realizando dump do PostgreSQL: $database (container: $container)"

  if ! docker_container_running "$container"; then
    log_error "Container $container não está disponível. Dump do PostgreSQL cancelado."
    return 1
  fi

  if docker exec "$container" pg_dump -U "$user" "$database" > "$output_file" 2>>"${LOG_FILE:-/dev/null}"; then
    if [[ -s "$output_file" ]]; then
      local size
      size="$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)"
      log_success "Dump PostgreSQL '$database' concluído ($(human_size "$size"))."
      return 0
    else
      log_warn "Dump PostgreSQL '$database' está vazio."
      return 1
    fi
  else
    log_error "Falha ao realizar dump do PostgreSQL: $database"
    return 1
  fi
}
