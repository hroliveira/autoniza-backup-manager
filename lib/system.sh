#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_SYSTEM_LOADED:-}" ]] && return 0
ABM_SYSTEM_LOADED=1

# ── Variáveis globais do sistema ──────────────────────────────
SYSTEM_OS=""
SYSTEM_KERNEL=""
SYSTEM_DOCKER=""
SYSTEM_RESTIC=""
SYSTEM_ABM=""

# ── Versão do Backup Manager ──────────────────────────────────
abm_version() {
  if [[ -f "${BACKUP_ROOT:-/opt/autoniza-backup}/VERSION" ]]; then
    cat "${BACKUP_ROOT:-/opt/autoniza-backup}/VERSION" | tr -d '\r\n '
  else
    echo "2.0.0"
  fi
}

# ── Obter SO ──────────────────────────────────────────────────
get_os() {
  if [[ -f /etc/os-release ]]; then
    local pretty_name
    pretty_name=$(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release | sed 's/"//g')
    echo "${pretty_name:-Linux}"
  else
    uname -s
  fi
}

# ── Obter Kernel ──────────────────────────────────────────────
get_kernel() {
  uname -r
}

# ── Obter Versão do Docker ────────────────────────────────────
get_docker_version() {
  if command -v docker &>/dev/null; then
    docker --version | awk '{print $3}' | sed 's/,//g'
  else
    echo "null"
  fi
}

# ── Obter Versão do Restic ────────────────────────────────────
get_restic_version() {
  if command -v restic &>/dev/null; then
    restic version | awk '{print $2}'
  else
    echo "null"
  fi
}

# ── Coletar todas as informações do sistema ───────────────────
collect_system_info() {
  SYSTEM_OS=$(get_os)
  SYSTEM_KERNEL=$(get_kernel)
  SYSTEM_DOCKER=$(get_docker_version)
  SYSTEM_RESTIC=$(get_restic_version)
  SYSTEM_ABM=$(abm_version)
}
