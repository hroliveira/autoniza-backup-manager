#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_LOGGER_LOADED:-}" ]] && return 0
ABM_LOGGER_LOADED=1
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Logger
# ═══════════════════════════════════════════════════════════════
# Funções de logging com timestamp e cores para terminal.


# ── Cores ─────────────────────────────────────────────────────
readonly ABM_RESET="\033[0m"
readonly ABM_RED="\033[0;31m"
readonly ABM_GREEN="\033[0;32m"
readonly ABM_YELLOW="\033[1;33m"
readonly ABM_BLUE="\033[0;34m"
readonly ABM_BOLD="\033[1m"

# ── Arquivo de Log ───────────────────────────────────────────
LOG_FILE="${BACKUP_ROOT:-/opt/autoniza-backup}/logs/backup.log"

_init_log_file() {
  local log_dir
  log_dir="$(dirname "$LOG_FILE")"
  [[ -d "$log_dir" ]] || mkdir -p "$log_dir"
}

_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# ── Funções Públicas ─────────────────────────────────────────

log_info() {
  _init_log_file
  local msg="$*"
  echo -e "${ABM_BLUE}[INFO]${ABM_RESET}  $(_timestamp) - $msg"
  echo "[INFO]  $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_warn() {
  _init_log_file
  local msg="$*"
  echo -e "${ABM_YELLOW}[WARN]${ABM_RESET}  $(_timestamp) - $msg" >&2
  echo "[WARN]  $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_error() {
  _init_log_file
  local msg="$*"
  echo -e "${ABM_RED}[ERROR]${ABM_RESET} $(_timestamp) - $msg" >&2
  echo "[ERROR] $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_success() {
  _init_log_file
  local msg="$*"
  echo -e "${ABM_GREEN}[OK]${ABM_RESET}    $(_timestamp) - $msg"
  echo "[OK]    $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_step() {
  local msg="$*"
  echo -e "${ABM_BOLD}[➜]${ABM_RESET} $msg"
  echo "[STEP]  $(_timestamp) - $msg" >> "$LOG_FILE"
}
