#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Script Principal de Backup
# ═══════════════════════════════════════════════════════════════
# Executa backup completo: dumps de bancos, pastas, Restic,
# retenção, verificação, relatórios e notificações.
# ═══════════════════════════════════════════════════════════════


# ── Caminhos absolutos ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
CONFIG_DIR="${BACKUP_ROOT}/config"
LIB_DIR="${BACKUP_ROOT}/lib"
LOG_DIR="${BACKUP_ROOT}/logs"
TMP_DIR="${BACKUP_ROOT}/tmp"
DUMP_DIR="${BACKUP_ROOT}/dumps"
REPORT_DIR="${BACKUP_ROOT}/reports"

# ── Carregar bibliotecas ─────────────────────────────────────
# shellcheck source=lib/logger.sh
source "${LIB_DIR}/logger.sh"
# shellcheck source=lib/utils.sh
source "${LIB_DIR}/utils.sh"
# shellcheck source=lib/docker.sh
source "${LIB_DIR}/docker.sh"
# shellcheck source=lib/restic.sh
source "${LIB_DIR}/restic.sh"
# shellcheck source=lib/postgres.sh
source "${LIB_DIR}/postgres.sh"
# shellcheck source=lib/mysql.sh
source "${LIB_DIR}/mysql.sh"
# shellcheck source=lib/redis.sh
source "${LIB_DIR}/redis.sh"
# shellcheck source=lib/notify.sh
source "${LIB_DIR}/notify.sh"
# shellcheck source=lib/report.sh
source "${LIB_DIR}/report.sh"

# ── Arquivos de configuração ─────────────────────────────────
CONFIG_ENV="${CONFIG_DIR}/config.env"
BACKUP_YAML="${CONFIG_DIR}/backup.yaml"

# ── Variáveis globais ────────────────────────────────────────
START_TIME=0
END_TIME=0
BACKUP_STATUS="success"
BACKUP_DETAILS=""
SNAPSHOT_ID=""
ERROR_MESSAGES=""
TEMP_DIR=""

# ── Cleanup em caso de erro ──────────────────────────────────
cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    BACKUP_STATUS="error"
    log_error "Backup interrompido com código de erro $exit_code"
  fi
  # Limpar tmp
  [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR" && log_info "Tmp limpo: $TEMP_DIR"
  # Notificar falha se necessário
  if [[ "$BACKUP_STATUS" == "error" ]]; then
    local msg="${ERROR_MESSAGES:-Erro inesperado durante o backup}"
    send_notification "error" "Backup falhou: $msg" "" ""
  fi
  exit "$exit_code"
}
trap cleanup EXIT SIGINT SIGTERM

# ── Main ──────────────────────────────────────────────────────
main() {
  START_TIME=$(date +%s)

  log_success "═══════════════════════════════════════════════"
  log_success "  Autoniza Backup Manager - Iniciando Backup"
  log_success "═══════════════════════════════════════════════"

  # ── 1. Carregar configurações ──────────────────────────────
  log_step "Carregando configurações..."
  require_command "yq"
  require_command "jq"
  require_command "restic"

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

  if [[ ! -f "$BACKUP_YAML" ]]; then
    log_error "Arquivo backup.yaml não encontrado em $BACKUP_YAML"
    exit 1
  fi
  validate_yaml "$BACKUP_YAML"

  # ── Extrair configurações do YAML ──────────────────────────
  SERVER_NAME="$(yq_get "$BACKUP_YAML" '.server.name' "unknown")"
  SERVER_ENV="$(yq_get "$BACKUP_YAML" '.server.environment' "unknown")"
  RET_DAILY="$(yq_get "$BACKUP_YAML" '.retention.daily' "7")"
  RET_WEEKLY="$(yq_get "$BACKUP_YAML" '.retention.weekly' "4")"
  RET_MONTHLY="$(yq_get "$BACKUP_YAML" '.retention.monthly' "12")"
  CHECK_ENABLED="$(yq_get "$BACKUP_YAML" '.checks.restic_check' "false")"
  READ_SUBSET="$(yq_get "$BACKUP_YAML" '.checks.read_data_subset' "")"

  log_info "Servidor: $SERVER_NAME | Ambiente: $SERVER_ENV"

  # ── 2. Criar diretórios necessários ────────────────────────
  ensure_dir "$LOG_DIR"
  ensure_dir "$TMP_DIR"
  ensure_dir "$DUMP_DIR"
  ensure_dir "$REPORT_DIR"

  # ── 3. Criar pasta temporária para este backup ─────────────
  local date_tag
  date_tag="$(date_compact)"
  TEMP_DIR="${TMP_DIR}/backup_${date_tag}"
  ensure_dir "$TEMP_DIR"

  # ── 4. Executar pre-backup hook ────────────────────────────
  local pre_hook="${BACKUP_ROOT}/hooks/pre-backup.sh"
  if [[ -f "$pre_hook" && -x "$pre_hook" ]]; then
    log_step "Executando pre-backup hook..."
    if "$pre_hook"; then
      log_success "Pre-backup hook concluído."
    else
      log_error "Pre-backup hook falhou. Continuando..."
      ERROR_MESSAGES+="Pre-backup hook falhou; "
    fi
  fi

  # ── 5. Dump dos bancos PostgreSQL ──────────────────────────
  local pg_count
  pg_count="$(yq eval '.postgres | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
  if [[ "$pg_count" -gt 0 ]]; then
    log_step "Processando bancos PostgreSQL..."
    for i in $(seq 0 $((pg_count - 1))); do
      local pg_name pg_container pg_db pg_user
      pg_name="$(yq eval ".postgres[$i].name" "$BACKUP_YAML")"
      pg_container="$(yq eval ".postgres[$i].container" "$BACKUP_YAML")"
      pg_db="$(yq eval ".postgres[$i].database" "$BACKUP_YAML")"
      pg_user="$(yq eval ".postgres[$i].user" "$BACKUP_YAML")"
      local pg_output="${TEMP_DIR}/${pg_name}_postgres.sql"
      if backup_postgres "$pg_container" "$pg_db" "$pg_user" "$pg_output"; then
        BACKUP_DETAILS+="PostgreSQL $pg_name: OK\n"
      else
        BACKUP_DETAILS+="PostgreSQL $pg_name: FALHA\n"
        ERROR_MESSAGES+="PostgreSQL $pg_name falhou; "
      fi
    done
  fi

  # ── 6. Dump dos bancos MySQL/MariaDB ───────────────────────
  local mysql_count
  mysql_count="$(yq eval '.mysql | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
  if [[ "$mysql_count" -gt 0 ]]; then
    log_step "Processando bancos MySQL..."
    for i in $(seq 0 $((mysql_count - 1))); do
      local my_name my_container my_db my_user my_pass
      my_name="$(yq eval ".mysql[$i].name" "$BACKUP_YAML")"
      my_container="$(yq eval ".mysql[$i].container" "$BACKUP_YAML")"
      my_db="$(yq eval ".mysql[$i].database" "$BACKUP_YAML")"
      my_user="$(yq eval ".mysql[$i].user" "$BACKUP_YAML")"
      my_pass="$(yq eval ".mysql[$i].password" "$BACKUP_YAML")"
      local my_output="${TEMP_DIR}/${my_name}_mysql.sql"
      if backup_mysql "$my_container" "$my_db" "$my_user" "$my_pass" "$my_output"; then
        BACKUP_DETAILS+="MySQL $my_name: OK\n"
      else
        BACKUP_DETAILS+="MySQL $my_name: FALHA\n"
        ERROR_MESSAGES+="MySQL $my_name falhou; "
      fi
    done
  fi

  # ── 7. Snapshot Redis ──────────────────────────────────────
  local redis_count
  redis_count="$(yq eval '.redis | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
  if [[ "$redis_count" -gt 0 ]]; then
    log_step "Processando Redis..."
    for i in $(seq 0 $((redis_count - 1))); do
      local rd_name rd_container
      rd_name="$(yq eval ".redis[$i].name" "$BACKUP_YAML")"
      rd_container="$(yq eval ".redis[$i].container" "$BACKUP_YAML")"
      local rd_output="${TEMP_DIR}/${rd_name}_redis.rdb"
      if backup_redis "$rd_container" "$rd_output"; then
        BACKUP_DETAILS+="Redis $rd_name: OK\n"
      else
        BACKUP_DETAILS+="Redis $rd_name: FALHA\n"
        ERROR_MESSAGES+="Redis $rd_name falhou; "
      fi
    done
  fi

  # ── 8. Verificar dumps criados ─────────────────────────────
  log_step "Verificando dumps..."
  local dump_files
  dump_files="$(find "$TEMP_DIR" -type f 2>/dev/null)"
  if [[ -z "$dump_files" ]]; then
    log_info "Nenhum dump foi gerado nesta execução (pode ser normal se não houver bancos configurados)."
  else
    while IFS= read -r f; do
      if [[ ! -s "$f" ]]; then
        log_warn "Arquivo vazio: $f"
      fi
    done <<< "$dump_files"
  fi

  # ── 9. Inicializar repositório Restic ──────────────────────
  restic_init_if_needed

  # ── 10. Executar restic backup ─────────────────────────────
  log_step "Executando Restic backup..."
  local restic_source="$TEMP_DIR"

  # Incluir pastas adicionais do YAML
  local folders_count
  folders_count="$(yq eval '.folders | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
  if [[ "$folders_count" -gt 0 ]]; then
    restic_source="$TEMP_DIR"
    # Copiamos os caminhos das pastas para incluir
    local folder_args=()
    for i in $(seq 0 $((folders_count - 1))); do
      local folder_path
      folder_path="$(yq eval ".folders[$i]" "$BACKUP_YAML")"
      folder_args+=("$folder_path")
    done

    log_info "Incluindo pastas do sistema: ${folder_args[*]}"
    if restic backup \
      --tag "automatic" \
      --tag "server:${SERVER_NAME}" \
      --tag "env:${SERVER_ENV}" \
      --host "$(hostname)" \
      "${folder_args[@]}" \
      "$restic_source"; then
      log_success "Restic backup concluído (pastas + dumps)."
    else
      log_error "Falha no restic backup."
      ERROR_MESSAGES+="Restic backup falhou; "
    fi
  else
    if restic_run_backup "$restic_source" "automatic"; then
      log_success "Restic backup concluído."
    else
      log_error "Falha no restic backup."
      ERROR_MESSAGES+="Restic backup falhou; "
    fi
  fi

  # Obter snapshot ID
  SNAPSHOT_ID="$(restic_last_snapshot || echo "unknown")"

  # ── 11. Aplicar retenção ───────────────────────────────────
  if restic_apply_retention "$RET_DAILY" "$RET_WEEKLY" "$RET_MONTHLY"; then
    BACKUP_DETAILS+="Retenção: daily=$RET_DAILY weekly=$RET_WEEKLY monthly=$RET_MONTHLY\n"
  else
    ERROR_MESSAGES+="Retenção falhou; "
  fi

  # ── 12. Verificar integridade ──────────────────────────────
  if [[ "$CHECK_ENABLED" == "true" ]]; then
    if restic_verify "$READ_SUBSET"; then
      BACKUP_DETAILS+="Restic check: OK\n"
    else
      ERROR_MESSAGES+="Restic check falhou; "
    fi
  fi

  # ── 13. Executar post-backup hook ──────────────────────────
  local post_hook="${BACKUP_ROOT}/hooks/post-backup.sh"
  if [[ -f "$post_hook" && -x "$post_hook" ]]; then
    log_step "Executando post-backup hook..."
    if "$post_hook"; then
      log_success "Post-backup hook concluído."
    else
      log_warn "Post-backup hook falhou."
      ERROR_MESSAGES+="Post-backup hook falhou; "
    fi
  fi

  # ── 14. Gerar relatórios ──────────────────────────────────
  END_TIME=$(date +%s)
  local elapsed
  elapsed="$(duration "$START_TIME" "$END_TIME")"

  if [[ -n "$ERROR_MESSAGES" ]]; then
    BACKUP_STATUS="error"
  fi

  BACKUP_DETAILS+="Duração total: $elapsed\n"

  local text_report="${REPORT_DIR}/backup_$(date_compact).txt"
  local html_report="${REPORT_DIR}/backup_$(date_compact).html"
  generate_text_report "$text_report" "$BACKUP_STATUS" "$SNAPSHOT_ID" "$elapsed" "$BACKUP_DETAILS"
  generate_html_report "$html_report" "$BACKUP_STATUS" "$SNAPSHOT_ID" "$elapsed" "$BACKUP_DETAILS"

  # ── 15. Notificar ─────────────────────────────────────────
  if [[ "$BACKUP_STATUS" == "success" ]]; then
    send_notification "success" "Backup concluído com sucesso." "$SNAPSHOT_ID" "$elapsed"
  else
    send_notification "error" "Backup concluído com erros: $ERROR_MESSAGES" "$SNAPSHOT_ID" "$elapsed"
  fi

  # ── 16. Resumo final ──────────────────────────────────────
  echo ""
  log_success "═══════════════════════════════════════════════"
  log_success "  Backup Finalizado"
  log_success "═══════════════════════════════════════════════"
  log_info "Status:    ${BACKUP_STATUS}"
  log_info "Snapshot:  ${SNAPSHOT_ID}"
  log_info "Duração:   ${elapsed}"
  log_info "Relatório: ${text_report}"
  log_info "HTML:      ${html_report}"
  if [[ -n "$ERROR_MESSAGES" ]]; then
    log_warn "Erros:     ${ERROR_MESSAGES}"
  fi
  echo ""
}

main "$@"
