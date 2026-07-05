#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_METRICS_LOADED:-}" ]] && return 0
ABM_METRICS_LOADED=1

# ── Variáveis globais de métricas ─────────────────────────────
ABM_METRICS_START=""
ABM_METRICS_END=""
ABM_METRICS_SNAPSHOT_ID=""
ABM_METRICS_FILES=0
ABM_METRICS_SIZE="0 B"
ABM_METRICS_STORAGE_USED="0 B"

BACKUP_START_TIME=""
BACKUP_END_TIME=""
EXECUTION_ID=""

# ── Iniciar o temporizador e registrar data/hora de início ────
metrics_start_timer() {
  ABM_METRICS_START=$(date +%s.%N 2>/dev/null || date +%s)
  BACKUP_START_TIME=$(date --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
}

# ── Parar o temporizador e registrar data/hora de término ─────
metrics_stop_timer() {
  ABM_METRICS_END=$(date +%s.%N 2>/dev/null || date +%s)
  BACKUP_END_TIME=$(date --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
}

# ── Gerar ID de Execução único ────────────────────────────────
metrics_generate_execution_id() {
  local suffix="${1:-error}"
  # Remover qualquer caractere inválido ou nulo
  if [[ -z "$suffix" || "$suffix" == "null" ]]; then
    suffix="error"
  fi
  local date_prefix
  date_prefix=$(date '+%Y%m%d-%H%M%S')
  EXECUTION_ID="${date_prefix}-${suffix}"
}

# ── Obter a duração formatada ─────────────────────────────────
metrics_get_duration() {
  local start="${ABM_METRICS_START:-0}"
  local end="${ABM_METRICS_END:-0}"
  if [[ "$start" == "0" || "$end" == "0" ]]; then
    echo "0s"
    return 0
  fi
  if [[ "$start" == *.* && "$end" == *.* ]]; then
    local diff
    diff=$(awk "BEGIN {printf \"%.2f\", $end - $start}" 2>/dev/null || echo "0.00")
    echo "${diff}s"
  elif [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]]; then
    echo "$((end - start))s"
  else
    echo "0s"
  fi
}

# ── Parsear a saída do restic backup ──────────────────────────
metrics_parse_restic_output() {
  local output="$1"

  # Extrair Snapshot ID (ex: snapshot fe47ac43 saved)
  ABM_METRICS_SNAPSHOT_ID=$(echo "$output" | sed -n -E 's/.*snapshot ([a-f0-9]+) saved.*/\1/p' | head -n 1)

  # Extrair arquivos processados (Files: X new, Y changed, Z unmodified)
  local new_files
  new_files=$(echo "$output" | sed -n -E 's/.*[[:space:]]+([0-9]+) new.*/\1/p' | head -n 1)
  [[ -z "$new_files" ]] && new_files=0

  local changed_files
  changed_files=$(echo "$output" | sed -n -E 's/.*,?[[:space:]]+([0-9]+) changed.*/\1/p' | head -n 1)
  [[ -z "$changed_files" ]] && changed_files=0

  local unmodified_files
  unmodified_files=$(echo "$output" | sed -n -E 's/.*,?[[:space:]]+([0-9]+) unmodified.*/\1/p' | head -n 1)
  [[ -z "$unmodified_files" ]] && unmodified_files=0

  ABM_METRICS_FILES=$((new_files + changed_files + unmodified_files))

  # Extrair tamanho adicionado (Added to the repository: 3.463 MiB ...)
  local size_added
  size_added=$(echo "$output" | sed -n -E 's/.*Added to the repository:[[:space:]]*([0-9.]+[[:space:]]*[a-zA-Z]+).*/\1/p' | head -n 1)
  if [[ -n "$size_added" ]]; then
    ABM_METRICS_SIZE="$size_added"
  else
    ABM_METRICS_SIZE="0 B"
  fi

  # Extrair tamanho armazenado (Added to the repository: ... (870.539 KiB stored))
  local size_stored
  size_stored=$(echo "$output" | sed -n -E 's/.*Added to the repository:.* \(([0-9.]+[[:space:]]*[a-zA-Z]+) stored\).*/\1/p' | head -n 1)
  if [[ -n "$size_stored" ]]; then
    ABM_METRICS_STORAGE_USED="$size_stored"
  else
    ABM_METRICS_STORAGE_USED="0 B"
  fi
}

# ── Getters das métricas ──────────────────────────────────────
metrics_get_snapshot_id() {
  echo "${ABM_METRICS_SNAPSHOT_ID:-}"
}

metrics_get_total_files() {
  echo "${ABM_METRICS_FILES:-0}"
}

metrics_get_backup_size() {
  echo "${ABM_METRICS_SIZE:-0 B}"
}

metrics_get_storage_used() {
  echo "${ABM_METRICS_STORAGE_USED:-0 B}"
}
