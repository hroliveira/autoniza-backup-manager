#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Notificações via Webhook
# ═══════════════════════════════════════════════════════════════

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logger.sh
source "${SCRIPT_DIR}/logger.sh"

# ── Enviar notificação via webhook ────────────────────────────
# Uso: send_notification <status> <message> [snapshot_id] [duration]
send_notification() {
  local status="$1"        # success | error
  local message="$2"
  local snapshot="${3:-}"
  local duration="${4:-}"

  local webhook_url
  webhook_url="$(yq eval '.notifications.webhook_url' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "")"
  local enabled
  enabled="$(yq eval '.notifications.enabled' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "false")"

  if [[ "$enabled" != "true" || -z "$webhook_url" ]]; then
    log_info "Notificações desabilitadas. Pulando envio."
    return 0
  fi

  local server_name
  local server_env
  server_name="$(yq eval '.server.name' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "unknown")"
  server_env="$(yq eval '.server.environment' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "unknown")"

  local payload
  payload="$(cat <<EOF
{
  "status": "$status",
  "server": "$server_name",
  "environment": "$server_env",
  "snapshot": "$snapshot",
  "duration": "$duration",
  "message": "$message",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)"

  log_step "Enviando notificação para webhook..."
  if curl -s -S -X POST -H "Content-Type: application/json" -d "$payload" "$webhook_url" &>/dev/null; then
    log_success "Notificação enviada com sucesso."
    return 0
  else
    log_error "Falha ao enviar notificação para: $webhook_url"
    return 1
  fi
}
