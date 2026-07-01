#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Logger
# ═══════════════════════════════════════════════════════════════
# Funções de logging com timestamp e cores para terminal.


# ── Cores ─────────────────────────────────────────────────────
readonly RESET="\033[0m"
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[1;33m"
readonly BLUE="\033[0;34m"
readonly BOLD="\033[1m"

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
  echo -e "${BLUE}[INFO]${RESET}  $(_timestamp) - $msg"
  echo "[INFO]  $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_warn() {
  _init_log_file
  local msg="$*"
  echo -e "${YELLOW}[WARN]${RESET}  $(_timestamp) - $msg" >&2
  echo "[WARN]  $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_error() {
  _init_log_file
  local msg="$*"
  echo -e "${RED}[ERROR]${RESET} $(_timestamp) - $msg" >&2
  echo "[ERROR] $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_success() {
  _init_log_file
  local msg="$*"
  echo -e "${GREEN}[OK]${RESET}    $(_timestamp) - $msg"
  echo "[OK]    $(_timestamp) - $msg" >> "$LOG_FILE"
}

log_step() {
  local msg="$*"
  echo -e "${BOLD}[➜]${RESET} $msg"
  echo "[STEP]  $(_timestamp) - $msg" >> "$LOG_FILE"
}
