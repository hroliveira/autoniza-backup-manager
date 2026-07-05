#!/usr/bin/env bash
set -Eeuo pipefail

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Wrapper do backup v2
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${BACKUP_ROOT}/bin/abm" ]]; then
  exec "${BACKUP_ROOT}/bin/abm" backup "$@"
elif [[ -f "${SCRIPT_DIR}/bin/abm" ]]; then
  exec "${SCRIPT_DIR}/bin/abm" backup "$@"
elif command -v abm &>/dev/null; then
  exec abm backup "$@"
else
  echo "Erro: Executável principal 'abm' não encontrado." >&2
  exit 1
fi
