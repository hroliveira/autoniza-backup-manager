#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Utilitários
# ═══════════════════════════════════════════════════════════════


# ── Carregar dependências ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logger.sh
source "${SCRIPT_DIR}/logger.sh"

# ── Validar se um comando existe ──────────────────────────────
require_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Comando não encontrado: $cmd. Instale-o antes de continuar."
    exit 1
  fi
}

# ── Validar se uma variável de ambiente está definida ─────────
require_env() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    log_error "Variável de ambiente '$var_name' não está definida."
    exit 1
  fi
}

# ── Validar arquivo YAML com yq ───────────────────────────────
validate_yaml() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "Arquivo YAML não encontrado: $file"
    exit 1
  fi
  if ! yq eval '.' "$file" &>/dev/null; then
    log_error "Arquivo YAML inválido: $file"
    exit 1
  fi
}

# ── Obter valor do YAML com fallback ─────────────────────────
yq_get() {
  local file="$1"
  local path="$2"
  local default="${3:-}"
  local value
  value="$(yq eval "$path" "$file" 2>/dev/null || true)"
  if [[ "$value" == "null" || -z "$value" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# ── Calcular duração entre dois timestamps ───────────────────
duration() {
  local start="$1"
  local end="$2"
  local elapsed=$((end - start))
  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  local seconds=$((elapsed % 60))
  printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}

# ── Criar diretório se não existir ────────────────────────────
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    log_info "Diretório criado: $dir"
  fi
}

# ── Tamanho de arquivo legível ───────────────────────────────
human_size() {
  local bytes="$1"
  if [[ "$bytes" -lt 1024 ]]; then
    echo "${bytes}B"
  elif [[ "$bytes" -lt 1048576 ]]; then
    echo "$((bytes / 1024))KB"
  elif [[ "$bytes" -lt 1073741824 ]]; then
    echo "$((bytes / 1048576))MB"
  else
    echo "$((bytes / 1073741824))GB"
  fi
}

# ── Timestamp ISO ─────────────────────────────────────────────
iso_timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

# ── Data compacta para pastas temporárias ────────────────────
date_compact() {
  date '+%Y%m%d_%H%M%S'
}
