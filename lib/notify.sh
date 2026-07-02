#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_NOTIFY_LOADED:-}" ]] && return 0
ABM_NOTIFY_LOADED=1

# ── Configurações de arquivo local ────────────────────────────
yaml_file="${BACKUP_ROOT:-/opt/autoniza-backup}/config/backup.yaml"

# ── Enviar payload JSON para o webhook ─────────────────────────
send_webhook() {
  local json="$1"

  local enabled
  enabled="$(yq eval '.notifications.enabled' "$yaml_file" 2>/dev/null || echo "false")"
  local webhook_url
  webhook_url="$(yq eval '.notifications.webhook_url' "$yaml_file" 2>/dev/null || echo "")"

  if [[ "$enabled" != "true" || -z "$webhook_url" ]]; then
    log_info "Notificações via webhook desabilitadas ou URL vazia."
    return 0
  fi

  log_step "Enviando notificação webhook para o n8n..."
  if curl -s -S -X POST -H "Content-Type: application/json" -d "$json" "$webhook_url" &>/dev/null; then
    log_success "Notificação webhook enviada com sucesso."
  else
    log_warn "Falha ao enviar notificação para o webhook."
  fi
  return 0
}

# ── Gancho para modificar o payload antes de enviar ───────────
hook_modify_payload() {
  local payload="$1"
  local hook_script="${BACKUP_ROOT:-/opt/autoniza-backup}/hooks/modify-payload.sh"
  if [[ -f "$hook_script" && -x "$hook_script" ]]; then
    local modified_payload
    modified_payload=$(echo "$payload" | "$hook_script" 2>/dev/null)
    if [[ -n "$modified_payload" ]]; then
      payload="$modified_payload"
    fi
  fi
  echo "$payload"
}

# ── Construir payload de sucesso ──────────────────────────────
build_success_payload() {
  local snapshot="$1"
  local duration="$2"
  local files="$3"
  local size="$4"
  local storage_used="$5"
  local started_at="$6"
  local finished_at="$7"
  local exec_id="$8"

  local server_name
  server_name="$(yq eval '.server.name' "$yaml_file" 2>/dev/null || echo "unknown")"
  local server_env
  server_env="$(yq eval '.server.environment' "$yaml_file" 2>/dev/null || echo "unknown")"
  local repo_url="${RESTIC_REPOSITORY:-}"
  local repository_name="${repo_url##*/}"
  local hostname_val
  hostname_val="$(hostname)"
  local timestamp_val="$finished_at"

  if [[ ! "$files" =~ ^[0-9]+$ ]]; then
    files=0
  fi

  jq -n \
    --arg status "success" \
    --arg server "$server_name" \
    --arg env "$server_env" \
    --arg host "$hostname_val" \
    --arg repo "$repository_name" \
    --arg snap "$snapshot" \
    --arg dur "$duration" \
    --argjson files "$files" \
    --arg sz "$size" \
    --arg su "$storage_used" \
    --arg exec_id "$exec_id" \
    --arg started "$started_at" \
    --arg finished "$finished_at" \
    --arg os "${SYSTEM_OS:-null}" \
    --arg kernel "${SYSTEM_KERNEL:-null}" \
    --arg docker "${SYSTEM_DOCKER:-null}" \
    --arg restic "${SYSTEM_RESTIC:-null}" \
    --arg abm "${SYSTEM_ABM:-null}" \
    --arg msg "Backup concluído com sucesso." \
    --arg ts "$timestamp_val" \
    '{
      status: $status,
      server: $server,
      environment: $env,
      hostname: $host,
      repository: $repo,
      snapshot: (if $snap == "null" or $snap == "" then null else $snap end),
      metrics: {
        duration: $dur,
        files: $files,
        size: $sz,
        storage_used: $su
      },
      execution: {
        id: $exec_id,
        started_at: $started,
        finished_at: $finished
      },
      system: {
        os: (if $os == "null" then null else $os end),
        kernel: (if $kernel == "null" then null else $kernel end),
        docker: (if $docker == "null" then null else $docker end),
        restic: (if $restic == "null" then null else $restic end),
        abm: (if $abm == "null" then null else $abm end)
      },
      message: $msg,
      timestamp: $ts
    }'
}

# ── Construir payload de erro ─────────────────────────────────
build_error_payload() {
  local stage="$1"
  local code="$2"
  local details="$3"
  local duration="$4"
  local files="$5"
  local size="$6"
  local storage_used="$7"
  local started_at="$8"
  local finished_at="$9"
  local exec_id="${10}"

  local server_name
  server_name="$(yq eval '.server.name' "$yaml_file" 2>/dev/null || echo "unknown")"
  local server_env
  server_env="$(yq eval '.server.environment' "$yaml_file" 2>/dev/null || echo "unknown")"
  local repo_url="${RESTIC_REPOSITORY:-}"
  local repository_name="${repo_url##*/}"
  local hostname_val
  hostname_val="$(hostname)"
  local timestamp_val="$finished_at"

  if [[ ! "$files" =~ ^[0-9]+$ ]]; then
    files=0
  fi

  jq -n \
    --arg status "error" \
    --arg server "$server_name" \
    --arg env "$server_env" \
    --arg host "$hostname_val" \
    --arg repo "$repository_name" \
    --arg dur "$duration" \
    --argjson files "$files" \
    --arg sz "$size" \
    --arg su "$storage_used" \
    --arg exec_id "$exec_id" \
    --arg started "$started_at" \
    --arg finished "$finished_at" \
    --arg os "${SYSTEM_OS:-null}" \
    --arg kernel "${SYSTEM_KERNEL:-null}" \
    --arg docker "${SYSTEM_DOCKER:-null}" \
    --arg restic "${SYSTEM_RESTIC:-null}" \
    --arg abm "${SYSTEM_ABM:-null}" \
    --arg stage "$stage" \
    --arg code "$code" \
    --arg details "$details" \
    --arg msg "Falha ao executar o backup." \
    --arg ts "$timestamp_val" \
    '{
      status: $status,
      server: $server,
      environment: $env,
      hostname: $host,
      repository: $repo,
      snapshot: null,
      metrics: {
        duration: $dur,
        files: $files,
        size: $sz,
        storage_used: $su
      },
      execution: {
        id: $exec_id,
        started_at: $started,
        finished_at: $finished
      },
      system: {
        os: (if $os == "null" then null else $os end),
        kernel: (if $kernel == "null" then null else $kernel end),
        docker: (if $docker == "null" then null else $docker end),
        restic: (if $restic == "null" then null else $restic end),
        abm: (if $abm == "null" then null else $abm end)
      },
      error: {
        stage: $stage,
        code: $code,
        details: $details
      },
      message: $msg,
      timestamp: $ts
    }'
}

# ── Notificação de Sucesso ────────────────────────────────────
notify_success() {
  local snapshot="$1"
  local duration="$2"
  local files="$3"
  local size="$4"
  local storage_used="$5"
  local started_at="$6"
  local finished_at="$7"
  local exec_id="$8"

  local payload
  payload=$(build_success_payload "$snapshot" "$duration" "$files" "$size" "$storage_used" "$started_at" "$finished_at" "$exec_id")
  payload=$(hook_modify_payload "$payload")

  send_webhook "$payload"
}

# ── Notificação de Erro ───────────────────────────────────────
notify_error() {
  local stage="$1"
  local code="$2"
  local details="$3"
  local duration="$4"
  local files="$5"
  local size="$6"
  local storage_used="$7"
  local started_at="$8"
  local finished_at="$9"
  local exec_id="${10}"

  local payload
  payload=$(build_error_payload "$stage" "$code" "$details" "$duration" "$files" "$size" "$storage_used" "$started_at" "$finished_at" "$exec_id")
  payload=$(hook_modify_payload "$payload")

  send_webhook "$payload"
}
