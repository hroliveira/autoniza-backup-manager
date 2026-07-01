#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_RESTIC_LOADED:-}" ]] && return 0
ABM_RESTIC_LOADED=1
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Restic Wrapper
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/utils.sh"

# ── Verificar se o repositório existe e está acessível ───────
restic_check_repo() {
  log_step "Verificando repositório Restic..."
  if restic snapshots --quiet 2>/dev/null; then
    log_success "Repositório Restic acessível."
    return 0
  else
    log_warn "Repositório Restic não encontrado ou inacessível."
    return 1
  fi
}

# ── Inicializar repositório se necessário ─────────────────────
restic_init_if_needed() {
  if ! restic_check_repo; then
    log_step "Inicializando repositório Restic..."
    if restic init; then
      log_success "Repositório Restic inicializado com sucesso."
    else
      log_error "Falha ao inicializar repositório Restic."
      exit 1
    fi
  fi
}

# ── Executar backup ──────────────────────────────────────────
restic_run_backup() {
  local source_dir="$1"
  local tag="${2:-automatic}"

  if [[ ! -d "$source_dir" ]]; then
    log_error "Diretório de origem não encontrado: $source_dir"
    return 1
  fi

  log_step "Executando restic backup de: $source_dir"
  if restic backup \
    --tag "$tag" \
    --tag "server:${SERVER_NAME:-unknown}" \
    --tag "env:${SERVER_ENV:-unknown}" \
    --host "$(hostname)" \
    "$source_dir"; then
    log_success "Restic backup concluído."
    return 0
  else
    log_error "Falha no restic backup."
    return 1
  fi
}

# ── Aplicar política de retenção ─────────────────────────────
restic_apply_retention() {
  local keep_daily="$1"
  local keep_weekly="$2"
  local keep_monthly="$3"

  log_step "Aplicando retenção: daily=$keep_daily weekly=$keep_weekly monthly=$keep_monthly"
  if restic forget \
    --keep-daily "$keep_daily" \
    --keep-weekly "$keep_weekly" \
    --keep-monthly "$keep_monthly" \
    --prune; then
    log_success "Retenção aplicada com sucesso."
    return 0
  else
    log_error "Falha ao aplicar retenção."
    return 1
  fi
}

# ── Verificar integridade dos snapshots ──────────────────────
restic_verify() {
  local read_data_subset="${1:-}"

  log_step "Executando restic check..."
  if [[ -n "$read_data_subset" ]]; then
    log_info "Verificando subset de dados: $read_data_subset"
    if restic check --read-data-subset="$read_data_subset"; then
      log_success "Restic check concluído (subset: $read_data_subset)."
      return 0
    else
      log_error "Restic check encontrou erros (subset: $read_data_subset)."
      return 1
    fi
  else
    if restic check; then
      log_success "Restic check concluído."
      return 0
    else
      log_error "Restic check encontrou erros."
      return 1
    fi
  fi
}

# ── Listar snapshots ─────────────────────────────────────────
restic_list_snapshots() {
  restic snapshots
}

# ── Restaurar snapshot ───────────────────────────────────────
restic_restore_snapshot() {
  local snapshot_id="$1"
  local target_dir="$2"

  log_step "Restaurando snapshot $snapshot_id para $target_dir"
  if restic restore "$snapshot_id" --target "$target_dir"; then
    log_success "Snapshot $snapshot_id restaurado para $target_dir"
    return 0
  else
    log_error "Falha ao restaurar snapshot $snapshot_id"
    return 1
  fi
}

# ── Último snapshot ID ───────────────────────────────────────
restic_last_snapshot() {
  restic snapshots --json 2>/dev/null | jq -r 'last | .short_id // empty'
}
