#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_CONFIG_LOADED:-}" ]] && return 0
ABM_CONFIG_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Config Loader & Validator
# ═══════════════════════════════════════════════════════════════

# Usar BACKUP_ROOT padrão ou o já existente
BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
CONFIG_DIR="${BACKUP_ROOT}/config"
CONFIG_ENV="${CONFIG_DIR}/config.env"
BACKUP_YAML="${CONFIG_DIR}/backup.yaml"

load_config() {
  local soft_mode=false
  if [[ "${1:-}" == "--soft" ]]; then
    soft_mode=true
  fi

  # Carregar config.env
  if [[ ! -f "$CONFIG_ENV" ]]; then
    if "$soft_mode"; then
      log_warn "Arquivo config.env não encontrado em $CONFIG_ENV"
      return 0
    else
      log_error "Arquivo config.env não encontrado em $CONFIG_ENV"
      exit 1
    fi
  fi
  
  # shellcheck source=config/config.env
  source "$CONFIG_ENV"

  # Validar envs obrigatórias para Restic
  if ! "$soft_mode"; then
    require_env "RESTIC_REPOSITORY"
    require_env "AWS_ACCESS_KEY_ID"
    require_env "AWS_SECRET_ACCESS_KEY"
    require_env "RESTIC_PASSWORD"
  fi

  export RESTIC_REPOSITORY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY RESTIC_PASSWORD

  # Validar backup.yaml
  if [[ ! -f "$BACKUP_YAML" ]]; then
    if "$soft_mode"; then
      log_warn "Arquivo backup.yaml não encontrado em $BACKUP_YAML"
      return 0
    else
      log_error "Arquivo backup.yaml não encontrado em $BACKUP_YAML"
      exit 1
    fi
  fi
  
  if "$soft_mode"; then
    if ! yq eval '.' "$BACKUP_YAML" &>/dev/null; then
      log_warn "Arquivo backup.yaml inválido."
      return 0
    fi
  else
    validate_yaml "$BACKUP_YAML"
  fi

  # Extrair variáveis do YAML com fallback para valores padrão
  SERVER_NAME="$(yq_get "$BACKUP_YAML" '.server.name' "unknown-server")"
  SERVER_ENV="$(yq_get "$BACKUP_YAML" '.server.environment' "production")"
  RET_DAILY="$(yq_get "$BACKUP_YAML" '.retention.daily' "7")"
  RET_WEEKLY="$(yq_get "$BACKUP_YAML" '.retention.weekly' "4")"
  RET_MONTHLY="$(yq_get "$BACKUP_YAML" '.retention.monthly' "12")"
  CHECK_ENABLED="$(yq_get "$BACKUP_YAML" '.checks.restic_check' "false")"
  READ_SUBSET="$(yq_get "$BACKUP_YAML" '.checks.read_data_subset' "")"
  WEBHOOK_URL="$(yq_get "$BACKUP_YAML" '.notifications.webhook_url' "")"

  export SERVER_NAME SERVER_ENV RET_DAILY RET_WEEKLY RET_MONTHLY CHECK_ENABLED READ_SUBSET WEBHOOK_URL
}
