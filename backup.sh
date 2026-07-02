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
# shellcheck source=lib/system.sh
source "${LIB_DIR}/system.sh"
# shellcheck source=lib/metrics.sh
source "${LIB_DIR}/metrics.sh"
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
CURRENT_STAGE="backup"
TEMP_DIR=""

# ── Catálogo de Códigos de Erros ──────────────────────────────
get_error_code() {
  local stage="$1"
  case "$stage" in
    postgres)  echo "PG_DUMP_FAILED" ;;
    mysql)     echo "MYSQL_DUMP_FAILED" ;;
    redis)     echo "REDIS_SAVE_FAILED" ;;
    restic)    echo "RESTIC_CONNECTION_ERROR" ;;
    retention) echo "RESTIC_PRUNE_FAILED" ;;
    check)     echo "RESTIC_CHECK_FAILED" ;;
    notify)    echo "NOTIFICATION_FAILED" ;;
    config)    echo "CONFIG_ERROR" ;;
    backup)    echo "BACKUP_FAILED" ;;
    *)         echo "UNKNOWN_ERROR" ;;
  esac
}

# ── Tratamento de erros ───────────────────────────────────────
on_error() {
  local exit_code=$?
  local line_no=$1
  local command="$2"

  metrics_stop_timer
  
  local stage="${CURRENT_STAGE:-backup}"
  local code
  code=$(get_error_code "$stage")

  # Gerar ID de execução de erro final
  metrics_generate_execution_id "error"

  local duration
  duration=$(metrics_get_duration)
  local files
  files=$(metrics_get_total_files)
  local size
  size=$(metrics_get_backup_size)
  local storage_used
  storage_used=$(metrics_get_storage_used)

  local details="Erro na linha ${line_no} ao executar: ${command}"

  log_error "Erro no estágio [${stage}] com código [${code}] (linha ${line_no}): ${command}"
  notify_error "$stage" "$code" "$details" "$duration" "$files" "$size" "$storage_used" "$BACKUP_START_TIME" "$BACKUP_END_TIME" "$EXECUTION_ID"

  # Limpar pasta temporária
  [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR" && log_info "Tmp limpo após erro: $TEMP_DIR"

  exit "$exit_code"
}
trap 'on_error ${LINENO} "$BASH_COMMAND"' ERR

# ── Cleanup normal no final ──────────────────────────────────
cleanup() {
  # Limpar pasta temporária
  [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR" && log_info "Tmp limpo: $TEMP_DIR"
}
trap cleanup EXIT SIGINT SIGTERM

# ── Main ──────────────────────────────────────────────────────
main() {
  metrics_start_timer
  collect_system_info
  metrics_generate_execution_id "pending"

  log_success "═══════════════════════════════════════════════"
  log_success "  Autoniza Backup Manager - Iniciando Backup"
  log_success "═══════════════════════════════════════════════"

  # ── 1. Carregar configurações ──────────────────────────────
  CURRENT_STAGE="config"
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
  CURRENT_STAGE="backup"
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
    CURRENT_STAGE="backup"
    "$pre_hook"
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
      
      CURRENT_STAGE="postgres"
      backup_postgres "$pg_container" "$pg_db" "$pg_user" "$pg_output"
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
      
      CURRENT_STAGE="mysql"
      backup_mysql "$my_container" "$my_db" "$my_user" "$my_pass" "$my_output"
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
      
      CURRENT_STAGE="redis"
      backup_redis "$rd_container" "$rd_output"
    done
  fi

  # ── 8. Verificar dumps criados ─────────────────────────────
  log_step "Verificando dumps..."
  CURRENT_STAGE="backup"
  local dump_files
  dump_files="$(find "$TEMP_DIR" -type f 2>/dev/null)"
  if [[ -n "$dump_files" ]]; then
    while IFS= read -r f; do
      if [[ ! -s "$f" ]]; then
        log_warn "Arquivo de dump vazio detectado: $f"
      fi
    done <<< "$dump_files"
  fi

  # ── 9. Inicializar repositório Restic ──────────────────────
  CURRENT_STAGE="restic"
  restic_init_if_needed

  # ── 10. Executar restic backup ─────────────────────────────
  log_step "Executando Restic backup..."
  local restic_source="$TEMP_DIR"
  local restic_out=""

  # Incluir pastas adicionais do YAML
  local folders_count
  folders_count="$(yq eval '.folders | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
  if [[ "$folders_count" -gt 0 ]]; then
    local folder_args=()
    for i in $(seq 0 $((folders_count - 1))); do
      local folder_path
      folder_path="$(yq eval ".folders[$i]" "$BACKUP_YAML")"
      folder_args+=("$folder_path")
    done

    log_info "Incluindo pastas do sistema: ${folder_args[*]}"
    restic_out=$(restic backup \
      --tag "automatic" \
      --tag "server:${SERVER_NAME}" \
      --tag "env:${SERVER_ENV}" \
      --host "$(hostname)" \
      "${folder_args[@]}" \
      "$restic_source")
  else
    restic_out=$(restic backup \
      --tag "automatic" \
      --tag "server:${SERVER_NAME}" \
      --tag "env:${SERVER_ENV}" \
      --host "$(hostname)" \
      "$restic_source")
  fi

  # Salvar saída no log e parsear métricas
  log_info "Saída do Restic:"
  echo "$restic_out" >> "$LOG_FILE"
  metrics_parse_restic_output "$restic_out"

  # ── 11. Aplicar retenção ───────────────────────────────────
  CURRENT_STAGE="retention"
  restic_apply_retention "$RET_DAILY" "$RET_WEEKLY" "$RET_MONTHLY"

  # ── 12. Verificar integridade ──────────────────────────────
  if [[ "$CHECK_ENABLED" == "true" ]]; then
    CURRENT_STAGE="check"
    restic_verify "$READ_SUBSET"
  fi

  # ── 13. Executar post-backup hook ──────────────────────────
  local post_hook="${BACKUP_ROOT}/hooks/post-backup.sh"
  if [[ -f "$post_hook" && -x "$post_hook" ]]; then
    log_step "Executando post-backup hook..."
    CURRENT_STAGE="backup"
    "$post_hook"
  fi

  # ── 14. Gerar relatórios locais ─────────────────────────────
  CURRENT_STAGE="backup"
  metrics_stop_timer
  local elapsed
  elapsed=$(metrics_get_duration)
  local snapshot
  snapshot=$(metrics_get_snapshot_id)
  local files
  files=$(metrics_get_total_files)
  local size
  size=$(metrics_get_backup_size)
  local storage_used
  storage_used=$(metrics_get_storage_used)

  local text_report="${REPORT_DIR}/backup_$(date_compact).txt"
  local html_report="${REPORT_DIR}/backup_$(date_compact).html"
  
  local details="Arquivos: $files\nTamanho: $size\nArmazenado: $storage_used"
  generate_text_report "$text_report" "success" "$snapshot" "$elapsed" "$details"
  generate_html_report "$html_report" "success" "$snapshot" "$elapsed" "$details"

  # Regenerar ID da execução com o snapshot real
  metrics_generate_execution_id "$snapshot"

  # ── 15. Notificar via webhook ───────────────────────────────
  CURRENT_STAGE="notify"
  notify_success "$snapshot" "$elapsed" "$files" "$size" "$storage_used" "$BACKUP_START_TIME" "$BACKUP_END_TIME" "$EXECUTION_ID"

  # ── 16. Resumo final ──────────────────────────────────────
  echo ""
  log_success "═══════════════════════════════════════════════"
  log_success "  Backup Finalizado com Sucesso"
  log_success "═══════════════════════════════════════════════"
  log_info "Status:    success"
  log_info "Snapshot:  ${snapshot}"
  log_info "Duração:   ${elapsed}"
  log_info "Relatório: ${text_report}"
  log_info "HTML:      ${html_report}"
  echo ""
}

main "$@"
