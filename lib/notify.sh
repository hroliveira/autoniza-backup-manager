#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_NOTIFY_LOADED:-}" ]] && return 0
ABM_NOTIFY_LOADED=1

# ── Enviar payload JSON para o webhook ─────────────────────────
send_webhook() {
  local json="$1"

  local yaml_file="${BACKUP_ROOT:-/opt/autoniza-backup}/config/backup.yaml"
  local enabled
  enabled="$(yq eval '.notifications.enabled' "$yaml_file" 2>/dev/null || echo "false")"
  local webhook_url
  webhook_url="$(yq eval '.notifications.webhook_url' "$yaml_file" 2>/dev/null || echo "")"

  if [[ "$enabled" != "true" || -z "$webhook_url" ]]; then
    log_info "Notificações via webhook desabilitadas ou URL vazia."
    return 0
  fi

  log_step "Enviando notificação webhook..."
  if curl -s -S -X POST -H "Content-Type: application/json" -d "$json" "$webhook_url" &>/dev/null; then
    log_success "Notificação webhook enviada com sucesso."
  else
    log_warn "Falha ao enviar notificação para o webhook (verifique a URL ou conectividade)."
  fi
  return 0
}

# ── Notificação de Sucesso ────────────────────────────────────
notify_success() {
  local snapshot="$1"
  local duration="$2"
  local files="$3"
  local size="$4"
  local storage_used="$5"

  local yaml_file="${BACKUP_ROOT:-/opt/autoniza-backup}/config/backup.yaml"
  local server_name
  server_name="$(yq eval '.server.name' "$yaml_file" 2>/dev/null || echo "unknown")"
  local server_env
  server_env="$(yq eval '.server.environment' "$yaml_file" 2>/dev/null || echo "unknown")"

  local repo_url="${RESTIC_REPOSITORY:-}"
  local repository_name="${repo_url##*/}"

  local hostname_val
  hostname_val="$(hostname)"
  local timestamp_val
  timestamp_val="$(date --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Garantir que files seja numérico para o jq
  if [[ ! "$files" =~ ^[0-9]+$ ]]; then
    files=0
  fi

  local payload
  payload=$(jq -n \
    --arg status "success" \
    --arg server "$server_name" \
    --arg env "$server_env" \
    --arg host "$hostname_val" \
    --arg snap "$snapshot" \
    --arg repo "$repository_name" \
    --arg dur "$duration" \
    --argjson files "$files" \
    --arg sz "$size" \
    --arg su "$storage_used" \
    --arg msg "Backup concluído com sucesso." \
    --arg ts "$timestamp_val" \
    '{
      status: $status,
      server: $server,
      environment: $env,
      hostname: $host,
      snapshot: $snap,
      repository: $repo,
      duration: $dur,
      files: $files,
      size: $sz,
      storage_used: $su,
      message: $msg,
      timestamp: $ts
    }')

  send_webhook "$payload"
}

# ── Notificação de Erro ───────────────────────────────────────
notify_error() {
  local stage="$1"
  local code="$2"
  local details="$3"
  local duration="$4"

  local yaml_file="${BACKUP_ROOT:-/opt/autoniza-backup}/config/backup.yaml"
  local server_name
  server_name="$(yq eval '.server.name' "$yaml_file" 2>/dev/null || echo "unknown")"
  local server_env
  server_env="$(yq eval '.server.environment' "$yaml_file" 2>/dev/null || echo "unknown")"

  local repo_url="${RESTIC_REPOSITORY:-}"
  local repository_name="${repo_url##*/}"

  local hostname_val
  hostname_val="$(hostname)"
  local timestamp_val
  timestamp_val="$(date --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

  local payload
  payload=$(jq -n \
    --arg status "error" \
    --arg server "$server_name" \
    --arg env "$server_env" \
    --arg host "$hostname_val" \
    --arg repo "$repository_name" \
    --arg dur "$duration" \
    --arg msg "Falha ao executar o backup." \
    --arg stage "$stage" \
    --arg code "$code" \
    --arg details "$details" \
    --arg ts "$timestamp_val" \
    '{
      status: $status,
      server: $server,
      environment: $env,
      hostname: $host,
      snapshot: null,
      repository: $repo,
      duration: $dur,
      message: $msg,
      error: {
        stage: $stage,
        code: $code,
        details: $details
      },
      timestamp: $ts
    }')

  send_webhook "$payload"
}
