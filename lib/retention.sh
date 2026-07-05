#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_RETENTION_LOADED:-}" ]] && return 0
ABM_RETENTION_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Retention Manager
# ═══════════════════════════════════════════════════════════════

# Lógica de aplicação de retenção utilizando o restic
apply_retention_policy() {
  local keep_daily="${1:-$RET_DAILY}"
  local keep_weekly="${2:-$RET_WEEKLY}"
  local keep_monthly="${3:-$RET_MONTHLY}"

  log_step "Aplicando política de retenção Restic..."
  log_info "Configuração: daily=$keep_daily, weekly=$keep_weekly, monthly=$keep_monthly"

  if restic forget \
    --keep-daily "$keep_daily" \
    --keep-weekly "$keep_weekly" \
    --keep-monthly "$keep_monthly" \
    --prune; then
    log_success "Política de retenção aplicada com sucesso."
    return 0
  else
    log_error "Falha ao aplicar política de retenção."
    return 1
  fi
}
