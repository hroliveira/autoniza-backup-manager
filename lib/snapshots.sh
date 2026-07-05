#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_SNAPSHOTS_LOADED:-}" ]] && return 0
ABM_SNAPSHOTS_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Snapshots Library
# ═══════════════════════════════════════════════════════════════

list_snapshots_table() {
  log_step "Listando snapshots do Restic..."
  echo ""
  # Tentar listar em formato de tabela elegante. Se restic falhar, retornar erro.
  if ! restic snapshots; then
    log_error "Erro ao obter os snapshots do Restic."
    return 1
  fi
  echo ""
}

find_snapshot() {
  local search_id="$1"
  if [[ -z "$search_id" ]]; then
    return 1
  fi
  
  # Buscar nas saídas JSON do restic
  local exists
  exists="$(restic snapshots --json 2>/dev/null | jq -r --arg id "$search_id" '.[] | select(.id == $id or .short_id == $id) | .id' | head -n 1)"
  
  if [[ -n "$exists" ]]; then
    echo "$exists"
    return 0
  else
    return 1
  fi
}

validate_snapshot() {
  local check_id="$1"
  if find_snapshot "$check_id" &>/dev/null; then
    return 0
  else
    log_error "Snapshot ID '$check_id' não encontrado ou é inválido."
    return 1
  fi
}

# Retorna uma lista legível de snapshots (ID, Data, Host, Paths) para menus interativos
get_snapshots_list() {
  restic snapshots --json 2>/dev/null | jq -r '.[] | "\(.short_id) | \(.time | sub("\\.[0-9]+"; "")) | \(.hostname) | \(.paths | join(", "))"'
}
