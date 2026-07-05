#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_RESTORE_LIB_LOADED:-}" ]] && return 0
ABM_RESTORE_LIB_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Restore Core Orchestrator
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
RESTORE_DIR="${BACKUP_ROOT}/restore"
TMP_DIR="${BACKUP_ROOT}/tmp"

# Enviar notificação de restore
notify_restore_status() {
  local status="$1"
  local snapshot_id="$2"
  local scope="$3"
  local details="$4"
  
  if [[ -n "${WEBHOOK_URL:-}" ]]; then
    log_info "Enviando webhook de notificação de restore ($status)..."
    local json_payload
    json_payload="$(jq -n \
      --arg status "$status" \
      --arg snapshot "$snapshot_id" \
      --arg scope "$scope" \
      --arg details "$details" \
      --arg server "$SERVER_NAME" \
      --arg env "$SERVER_ENV" \
      '{
        event: "restore",
        status: $status,
        snapshot_id: $snapshot,
        scope: $scope,
        details: $details,
        server: $server,
        environment: $env,
        timestamp: (now | strflocaltime("%Y-%m-%dT%H:%M:%S%z"))
      }')"
      
    curl -s -H "Content-Type: application/json" -d "$json_payload" "$WEBHOOK_URL" >/dev/null || log_warn "Falha ao enviar webhook."
  fi
}

# Executa o restore real
execute_restore() {
  local snapshot_id="$1"
  local restore_scope="$2" # db, files, volumes, all
  local dry_run="${3:-false}"
  local target_dir="${4:-}"

  # Se target_dir estiver vazio, usar pasta padrão
  if [[ -z "$target_dir" ]]; then
    target_dir="${RESTORE_DIR}/${snapshot_id}"
  fi

  log_success "═══════════════════════════════════════════════"
  log_success "  Autoniza Backup Manager - Iniciando Restauração"
  log_success "═══════════════════════════════════════════════"
  log_info "Snapshot:    ${snapshot_id}"
  log_info "Escopo:      ${restore_scope}"
  log_info "Destino Temporário/Extração: ${target_dir}"
  log_info "Dry-Run:     ${dry_run}"
  echo ""

  # Hook before_restore
  local before_hook="${BACKUP_ROOT}/hooks/before-restore.sh"
  if [[ "$dry_run" == "false" && -f "$before_hook" && -x "$before_hook" ]]; then
    log_step "Executando before_restore hook..."
    "$before_hook"
  fi

  if [[ "$dry_run" == "true" ]]; then
    log_success "--- DRY RUN - Nenhuma alteração real será feita ---"
    log_info "1. Extração simulada do snapshot Restic para: $target_dir"
    if [[ "$restore_scope" == "db" || "$restore_scope" == "all" ]]; then
      log_info "2. Banco: Simulação de restauração de dumps PostgreSQL, MySQL e Redis"
    fi
    if [[ "$restore_scope" == "files" || "$restore_scope" == "all" ]]; then
      log_info "3. Arquivos: Simulação de cópia dos arquivos do sistema"
    fi
    if [[ "$restore_scope" == "volumes" || "$restore_scope" == "all" ]]; then
      log_info "4. Docker Volumes: Simulação de restauração dos volumes"
    fi
    log_success "--- FIM DO DRY RUN ---"
    return 0
  fi

  # Executar extração do Restic
  ensure_dir "$target_dir"
  log_step "Extraindo arquivos do snapshot restic..."
  if ! restic restore "$snapshot_id" --target "$target_dir"; then
    log_error "Erro ao extrair o snapshot do Restic."
    notify_restore_status "fail" "$snapshot_id" "$restore_scope" "Erro na extração do restic"
    return 1
  fi

  # Restaurar Banco
  if [[ "$restore_scope" == "db" || "$restore_scope" == "all" ]]; then
    log_step "Restaurando bancos de dados..."
    # Buscar dumps extraídos no diretório temporário
    # Os dumps de banco ficam dentro de um subdiretório backup_xxxx no restic
    local temp_backup_path
    temp_backup_path="$(find "$target_dir" -type d -name "backup_*" | head -n 1 || true)"
    if [[ -n "$temp_backup_path" && -d "$temp_backup_path" ]]; then
      # PostgreSQL
      local pg_count
      pg_count="$(yq eval '.postgres | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
      if [[ "$pg_count" -gt 0 ]]; then
        for i in $(seq 0 $((pg_count - 1))); do
          local pg_name pg_container pg_db pg_user
          pg_name="$(yq eval ".postgres[$i].name" "$BACKUP_YAML")"
          pg_container="$(yq eval ".postgres[$i].container" "$BACKUP_YAML")"
          pg_db="$(yq eval ".postgres[$i].database" "$BACKUP_YAML")"
          pg_user="$(yq eval ".postgres[$i].user" "$BACKUP_YAML")"
          local pg_dump_file="${temp_backup_path}/${pg_name}_postgres.sql"
          
          if [[ -f "$pg_dump_file" ]]; then
            log_info "Restaurando Postgres [$pg_name] no container $pg_container..."
            if docker exec -i "$pg_container" psql -U "$pg_user" -d "$pg_db" < "$pg_dump_file" &>/dev/null; then
              log_success "Postgres [$pg_name] restaurado com sucesso."
            else
              log_warn "Falha ao restaurar banco Postgres [$pg_name] automaticamente."
            fi
          fi
        done
      fi

      # MySQL
      local mysql_count
      mysql_count="$(yq eval '.mysql | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
      if [[ "$mysql_count" -gt 0 ]]; then
        for i in $(seq 0 $((mysql_count - 1))); do
          local my_name my_container my_db my_user my_pass
          my_name="$(yq eval ".mysql[$i].name" "$BACKUP_YAML")"
          my_container="$(yq eval ".mysql[$i].container" "$BACKUP_YAML")"
          my_db="$(yq eval ".mysql[$i].database" "$BACKUP_YAML")"
          my_user="$(yq eval ".mysql[$i].user" "$BACKUP_YAML")"
          my_pass="$(yq eval ".mysql[$i].password" "$BACKUP_YAML")"
          local my_dump_file="${temp_backup_path}/${my_name}_mysql.sql"
          
          if [[ -f "$my_dump_file" ]]; then
            log_info "Restaurando MySQL [$my_name] no container $my_container..."
            if docker exec -i "$my_container" mysql -u "$my_user" -p"$my_pass" "$my_db" < "$my_dump_file" &>/dev/null; then
              log_success "MySQL [$my_name] restaurado com sucesso."
            else
              log_warn "Falha ao restaurar banco MySQL [$my_name] automaticamente."
            fi
          fi
        done
      fi

      # Redis
      local redis_count
      redis_count="$(yq eval '.redis | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
      if [[ "$redis_count" -gt 0 ]]; then
        for i in $(seq 0 $((redis_count - 1))); do
          local rd_name rd_container
          rd_name="$(yq eval ".redis[$i].name" "$BACKUP_YAML")"
          rd_container="$(yq eval ".redis[$i].container" "$BACKUP_YAML")"
          local rd_dump_file="${temp_backup_path}/${rd_name}_redis.rdb"
          
          if [[ -f "$rd_dump_file" ]]; then
            log_info "Aviso: Para restaurar o Redis [$rd_name], copie manualmente o arquivo RDB extraído para o volume do Redis e reinicie o container:"
            log_info "   cp $rd_dump_file /var/lib/docker/volumes/<redis_volume>/_data/dump.rdb"
          fi
        done
      fi
    else
      log_warn "Nenhum dump de banco encontrado na extração do backup."
    fi
  fi

  # Restaurar Arquivos / Folders
  if [[ "$restore_scope" == "files" || "$restore_scope" == "all" ]]; then
    log_step "Restaurando pastas do sistema..."
    # No restic, as pastas estão no caminho original relativo ao root da máquina.
    # Elas foram extraídas para $target_dir/<caminho_original>
    local folders_count
    folders_count="$(yq eval '.folders | length' "$BACKUP_YAML" 2>/dev/null || echo 0)"
    if [[ "$folders_count" -gt 0 ]]; then
      for i in $(seq 0 $((folders_count - 1))); do
        local folder_path
        folder_path="$(yq eval ".folders[$i]" "$BACKUP_YAML")"
        
        # O caminho extraído no disco temporário será $target_dir/$folder_path
        # Exemplo: /opt/autoniza-backup/restore/abc12345/var/www/html -> copia de volta para /var/www/html
        local extracted_folder="${target_dir}/${folder_path}"
        if [[ -d "$extracted_folder" ]]; then
          log_info "Restaurando pasta [$folder_path]..."
          mkdir -p "$(dirname "$folder_path")"
          cp -a "${extracted_folder}/." "$folder_path/"
          log_success "Pasta [$folder_path] restaurada com sucesso."
        fi
      done
    fi
  fi

  # Restaurar Docker Volumes
  if [[ "$restore_scope" == "volumes" || "$restore_scope" == "all" ]]; then
    log_step "Restaurando Docker Volumes..."
    # Se existirem volumes configurados ou se foram copiados no backup, realizar restauração.
    log_info "Docker Volumes restaurados no diretório temporário. Se necessário, copie-os para /var/lib/docker/volumes/"
  fi

  # Hook after_restore
  local after_hook="${BACKUP_ROOT}/hooks/after-restore.sh"
  if [[ -f "$after_hook" && -x "$after_hook" ]]; then
    log_step "Executando after_restore hook..."
    "$after_hook"
  fi

  log_success "Restauração finalizada com sucesso."
  notify_restore_status "success" "$snapshot_id" "$restore_scope" "Restore concluído com sucesso."
  return 0
}

# Fluxo interativo de restore
interactive_restore() {
  log_step "Buscando snapshots disponíveis..."
  echo ""
  
  # Listar últimos snapshots e ler para array
  local snaps
  snaps=$(restic snapshots --json 2>/dev/null || echo "[]")
  local snap_count
  snap_count=$(echo "$snaps" | jq '. | length')
  
  if [[ "$snap_count" -eq 0 ]]; then
    log_error "Nenhum snapshot encontrado."
    exit 1
  fi
  
  echo "Selecione o snapshot para restaurar:"
  local i
  for i in $(seq 0 $((snap_count - 1))); do
    local snap_id snap_time snap_host snap_paths
    snap_id=$(echo "$snaps" | jq -r ".[$i].short_id")
    snap_time=$(echo "$snaps" | jq -r ".[$i].time" | sub("\\.[0-9]+"; "") | tr -d 'TZ')
    snap_host=$(echo "$snaps" | jq -r ".[$i].hostname")
    snap_paths=$(echo "$snaps" | jq -r ".[$i].paths | join(\", \")")
    echo "$((i + 1))) ID: $snap_id | Data: $snap_time | Host: $snap_host | Caminhos: $snap_paths"
  done
  echo "$((snap_count + 1))) Informar Snapshot ID Manualmente"
  
  local option
  read -rp "Opção (1-$((snap_count + 1))): " option
  
  local selected_id=""
  if [[ "$option" -eq $((snap_count + 1)) ]]; then
    read -rp "Informe o Snapshot ID: " selected_id
  else
    local index=$((option - 1))
    if [[ "$index" -ge 0 && "$index" -lt "$snap_count" ]]; then
      selected_id=$(echo "$snaps" | jq -r ".[$index].short_id")
    else
      log_error "Opção inválida."
      exit 1
    fi
  fi
  
  # Validar snapshot selecionado
  if ! validate_snapshot "$selected_id"; then
    exit 1
  fi
  
  echo ""
  echo "O que você deseja restaurar do snapshot $selected_id?"
  echo "1) Apenas Bancos de Dados"
  echo "2) Apenas Arquivos do Sistema"
  echo "3) Apenas Volumes Docker"
  echo "4) Tudo (Bancos, Arquivos e Volumes)"
  read -rp "Opção (1-4): " scope_opt
  
  local scope="all"
  case "$scope_opt" in
    1) scope="db" ;;
    2) scope="files" ;;
    3) scope="volumes" ;;
    4) scope="all" ;;
    *) log_error "Opção inválida."; exit 1 ;;
  esac
  
  echo ""
  echo "--- RESUMO DA RESTAURAÇÃO ---"
  echo "Snapshot ID: $selected_id"
  echo "Escopo:      $scope"
  echo "Ação:        Esta operação irá restaurar os dados correspondentes."
  echo "-----------------------------"
  read -rp "Confirma a execução da restauração? (s/N): " confirm
  if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    log_info "Restauração cancelada pelo usuário."
    exit 0
  fi
  
  execute_restore "$selected_id" "$scope" "false" ""
}
