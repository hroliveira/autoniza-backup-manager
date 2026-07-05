#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_BACKUP_LIB_LOADED:-}" ]] && return 0
ABM_BACKUP_LIB_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Backup Core Orchestrator
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
CONFIG_DIR="${BACKUP_ROOT}/config"
LIB_DIR="${BACKUP_ROOT}/lib"
LOG_DIR="${BACKUP_ROOT}/logs"
TMP_DIR="${BACKUP_ROOT}/tmp"
DUMP_DIR="${BACKUP_ROOT}/dumps"
REPORT_DIR="${BACKUP_ROOT}/reports"

run_backup() {
  metrics_start_timer
  collect_system_info
  metrics_generate_execution_id "pending"

  log_success "═══════════════════════════════════════════════"
  log_success "  Autoniza Backup Manager - Iniciando Backup"
  log_success "═══════════════════════════════════════════════"

  # ── 1. Carregar e Validar Configurações ──────────────────────
  CURRENT_STAGE="config"
  log_step "Carregando configurações..."
  require_command "yq"
  require_command "jq"
  require_command "restic"

  # Garantir carregamento das configurações da lib/config.sh
  load_config

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
  apply_retention_policy "$RET_DAILY" "$RET_WEEKLY" "$RET_MONTHLY"

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
