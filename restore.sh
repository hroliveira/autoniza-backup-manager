#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Script de Restauração
# ═══════════════════════════════════════════════════════════════
# Lista snapshots disponíveis e permite restaurar um snapshot
# específico para um diretório local.
# ═══════════════════════════════════════════════════════════════


# ── Caminhos absolutos ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
CONFIG_DIR="${BACKUP_ROOT}/config"
LIB_DIR="${BACKUP_ROOT}/lib"
RESTORE_DIR="${BACKUP_ROOT}/restore"

# ── Carregar bibliotecas ─────────────────────────────────────
# shellcheck source=lib/logger.sh
source "${LIB_DIR}/logger.sh"
# shellcheck source=lib/utils.sh
source "${LIB_DIR}/utils.sh"
# shellcheck source=lib/restic.sh
source "${LIB_DIR}/restic.sh"

# ── Carregar env ─────────────────────────────────────────────
CONFIG_ENV="${CONFIG_DIR}/config.env"
if [[ ! -f "$CONFIG_ENV" ]]; then
  log_error "Arquivo config.env não encontrado em $CONFIG_ENV"
  exit 1
fi
# shellcheck source=config/config.env
source "$CONFIG_ENV"

require_env "RESTIC_REPOSITORY"
require_env "AWS_ACCESS_KEY_ID"
require_env "AWS_SECRET_ACCESS_KEY"
require_env "RESTIC_PASSWORD"

export RESTIC_REPOSITORY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD

# ── Help ──────────────────────────────────────────────────────
show_help() {
  cat <<EOF
Uso: $(basename "$0") [comando] [opções]

Comandos:
  list              Listar snapshots disponíveis
  restore <id>      Restaurar snapshot pelo ID
  latest            Restaurar o snapshot mais recente
  help              Mostrar esta ajuda

Opções:
  --target <dir>    Diretório de destino para restauração (padrão: ${RESTORE_DIR}/<snapshot-id>)

Exemplos:
  $(basename "$0") list
  $(basename "$0") restore abc123
  $(basename "$0") restore abc123 --target /tmp/restore-test
  $(basename "$0") latest
EOF
}

# ── Listar snapshots ─────────────────────────────────────────
list_snapshots() {
  log_step "Buscando snapshots disponíveis..."
  echo ""
  if ! restic_list_snapshots; then
    log_error "Falha ao listar snapshots. Verifique a conexão com o repositório."
    exit 1
  fi
  echo ""
  log_info "Para restaurar, use: $(basename "$0") restore <snapshot-id>"
}

# ── Restaurar snapshot ───────────────────────────────────────
restore_snapshot() {
  local snapshot_id="$1"
  local target_dir="${2:-${RESTORE_DIR}/${snapshot_id}}"

  log_success "═══════════════════════════════════════════════"
  log_success "  Autoniza Backup Manager - Restauração"
  log_success "═══════════════════════════════════════════════"
  log_info "Snapshot:  ${snapshot_id}"
  log_info "Destino:   ${target_dir}"
  echo ""

  # Confirmar
  echo -e "${YELLOW}⚠ Atenção: Você está prestes a restaurar dados.${RESET}"
  echo -e "Isso NÃO sobrescreverá dados de produção automaticamente."
  read -rp "Deseja continuar? (s/N): " confirm
  if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    log_info "Restauração cancelada pelo usuário."
    exit 0
  fi

  ensure_dir "$target_dir"

  if restic_restore_snapshot "$snapshot_id" "$target_dir"; then
    log_success "Restauração concluída!"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            Instruções Pós-Restauração                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📁 Os arquivos foram restaurados para:"
    echo "   ${target_dir}"
    echo ""
    echo "🗄️  Para restaurar bancos PostgreSQL manualmente:"
    echo "   cat ${target_dir}/<dump>.sql | docker exec -i <container> psql -U <user> <database>"
    echo ""
    echo "🗄️  Para restaurar bancos MySQL manualmente:"
    echo "   cat ${target_dir}/<dump>.sql | docker exec -i <container> mysql -u <user> -p<password> <database>"
    echo ""
    echo "📋 Para restaurar pastas do sistema manualmente:"
    echo "   cp -a ${target_dir}/data/... /data/..."
    echo ""
    echo "${YELLOW}⚠ Revise os dados antes de copiá-los para produção!${RESET}"
  else
    log_error "Falha na restauração."
    exit 1
  fi
}

# ── Main ──────────────────────────────────────────────────────
main() {
  require_command "restic"
  require_command "jq"

  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    list)
      list_snapshots
      ;;
    restore)
      local snapshot_id="${1:-}"
      local target=""
      shift 2>/dev/null || true

      if [[ -z "$snapshot_id" ]]; then
        log_error "ID do snapshot é obrigatório."
        echo ""
        show_help
        exit 1
      fi

      # Parse --target
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --target) target="$2"; shift 2 ;;
          *) log_error "Argumento desconhecido: $1"; exit 1 ;;
        esac
      done

      restore_snapshot "$snapshot_id" "$target"
      ;;
    latest)
      log_step "Buscando snapshot mais recente..."
      local latest_id
      latest_id="$(restic snapshots --json 2>/dev/null | jq -r 'last | .short_id // empty')"
      if [[ -z "$latest_id" ]]; then
        log_error "Nenhum snapshot encontrado."
        exit 1
      fi
      log_info "Snapshot mais recente: $latest_id"
      restore_snapshot "$latest_id"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      log_error "Comando desconhecido: $cmd"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

main "$@"
