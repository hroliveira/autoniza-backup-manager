#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_SCHEDULE_LOADED:-}" ]] && return 0
ABM_SCHEDULE_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Schedule Manager
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
CRON_COMMENT="# Autoniza Backup Manager Cron Job"
CRON_CMD="0 2 * * * ${BACKUP_ROOT}/backup.sh >> ${BACKUP_ROOT}/logs/cron.log 2>&1"

show_cron() {
  log_step "Exibindo tarefas agendadas no Cron..."
  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"
  if echo "$current_cron" | grep -Fq "autoniza-backup"; then
    echo "--- Configurações do Cron Ativas ---"
    echo "$current_cron" | grep -A 1 -F "$CRON_COMMENT" || echo "$current_cron" | grep -F "autoniza-backup"
    echo "------------------------------------"
  else
    log_info "Nenhum agendamento do Autoniza Backup Manager encontrado no crontab."
  fi
}

install_cron() {
  log_step "Instalando agendamento Cron..."
  
  # Remover qualquer versão antiga
  remove_cron --silent
  
  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"
  
  # Montar novo crontab
  (
    echo "$current_cron"
    echo "$CRON_COMMENT"
    echo "$CRON_CMD"
  ) | crontab -
  
  log_success "Agendamento Cron instalado com sucesso! Execução diária às 02:00."
  log_info "Log cron configurado em: ${BACKUP_ROOT}/logs/cron.log"
}

remove_cron() {
  local silent="${1:-}"
  if [[ "$silent" != "--silent" ]]; then
    log_step "Removendo agendamento Cron..."
  fi
  
  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"
  
  if echo "$current_cron" | grep -Fq "autoniza-backup"; then
    # Filtrar fora as linhas do autoniza
    echo "$current_cron" | grep -v -F "autoniza-backup" | grep -v -F "$CRON_COMMENT" | crontab - || crontab -r
    if [[ "$silent" != "--silent" ]]; then
      log_success "Agendamento Cron removido com sucesso."
    fi
  else
    if [[ "$silent" != "--silent" ]]; then
      log_info "Nenhum agendamento Cron ativo para remover."
    fi
  fi
}

test_cron_run() {
  log_step "Executando teste de agendamento (backup manual)..."
  if [[ -f "${BACKUP_ROOT}/backup.sh" ]]; then
    bash "${BACKUP_ROOT}/backup.sh"
  else
    log_error "Script de backup não encontrado em ${BACKUP_ROOT}/backup.sh"
    return 1
  fi
}

manage_schedule_menu() {
  while true; do
    echo "=== Gerenciamento de Agendamento ==="
    echo "1) Instalar Cron (Diário às 02:00)"
    echo "2) Remover Cron"
    echo "3) Mostrar Cron Atual"
    echo "4) Executar Teste de Backup"
    echo "5) Voltar"
    read -rp "Escolha uma opção (1-5): " opt
    case "$opt" in
      1) install_cron ;;
      2) remove_cron ;;
      3) show_cron ;;
      4) test_cron_run ;;
      5) break ;;
      *) log_warn "Opção inválida." ;;
    esac
    echo ""
  done
}
