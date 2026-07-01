#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - MySQL/MariaDB Backup
# ═══════════════════════════════════════════════════════════════


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logger.sh
source "${SCRIPT_DIR}/logger.sh"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/docker.sh"

# ── Backup de banco MySQL/MariaDB via Docker ──────────────────
# Uso: backup_mysql <container> <database> <user> <password> <output_file>
backup_mysql() {
  local container="$1"
  local database="$2"
  local user="$3"
  local password="$4"
  local output_file="$5"

  log_step "Realizando dump do MySQL: $database (container: $container)"

  if ! docker_container_running "$container"; then
    log_error "Container $container não está disponível. Dump do MySQL cancelado."
    return 1
  fi

  if docker exec "$container" mysqldump -u "$user" -p"$password" "$database" > "$output_file" 2>>"${LOG_FILE:-/dev/null}"; then
    if [[ -s "$output_file" ]]; then
      local size
      size="$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)"
      log_success "Dump MySQL '$database' concluído ($(human_size "$size"))."
      return 0
    else
      log_warn "Dump MySQL '$database' está vazio."
      return 1
    fi
  else
    log_error "Falha ao realizar dump do MySQL: $database"
    return 1
  fi
}
