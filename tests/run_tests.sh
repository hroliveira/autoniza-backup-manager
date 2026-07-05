#!/usr/bin/env bash
set -Eeuo pipefail

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Runner de Testes Unitários
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="${PROJECT_ROOT}/lib"

# Mocks para logs
log_info() { echo "[TEST-INFO] $*"; }
log_warn() { echo "[TEST-WARN] $*" >&2; }
log_error() { echo "[TEST-ERROR] $*" >&2; }
log_success() { echo "[TEST-SUCCESS] $*"; }
log_step() { echo "[TEST-STEP] $*"; }

# Carregar bibliotecas
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/metrics.sh"
source "${LIB_DIR}/system.sh"

test_yq_get() {
  log_step "Testando yq_get..."
  # Como yq_get depende de arquivos reais, podemos testar com mock simples
  # Mas podemos testar human_size e duration diretamente
}

test_human_size() {
  log_step "Testando human_size..."
  
  local res
  res=$(human_size 500)
  if [[ "$res" != "500B" ]]; then
    log_error "Erro no teste human_size (500B): obtido $res"
    exit 1
  fi

  res=$(human_size 1024)
  if [[ "$res" != "1KB" ]]; then
    log_error "Erro no teste human_size (1KB): obtido $res"
    exit 1
  fi

  res=$(human_size 1048576)
  if [[ "$res" != "1MB" ]]; then
    log_error "Erro no teste human_size (1MB): obtido $res"
    exit 1
  fi

  res=$(human_size 1073741824)
  if [[ "$res" != "1GB" ]]; then
    log_error "Erro no teste human_size (1GB): obtido $res"
    exit 1
  fi
  
  log_success "Teste human_size passou!"
}

test_duration() {
  log_step "Testando duration..."
  local res
  res=$(duration 0 3665) # 1h 1m 5s
  if [[ "$res" != "01:01:05" ]]; then
    log_error "Erro no teste duration: obtido $res, esperado 01:01:05"
    exit 1
  fi
  log_success "Teste duration passou!"
}

test_metrics() {
  log_step "Testando parse de métricas do restic..."
  local restic_mock="
open repository
lock repository
Files:           5 new,     10 changed,    100 unmodified
Added to the repository: 1.500 MiB (1.200 MiB stored)
processed 115 files, 2.50 GB in 0:02
snapshot abc12345 saved
"
  metrics_parse_restic_output "$restic_mock"
  
  local snap
  snap=$(metrics_get_snapshot_id)
  if [[ "$snap" != "abc12345" ]]; then
    log_error "Erro no parse de snapshot ID: obtido $snap, esperado abc12345"
    exit 1
  fi

  local files
  files=$(metrics_get_total_files)
  if [[ "$files" -ne 115 ]]; then
    log_error "Erro no parse de arquivos: obtido $files, esperado 115"
    exit 1
  fi

  local size
  size=$(metrics_get_backup_size)
  if [[ "$size" != "1.500 MiB" ]]; then
    log_error "Erro no parse do tamanho adicionado: obtido $size, esperado 1.500 MiB"
    exit 1
  fi

  local stored
  stored=$(metrics_get_storage_used)
  if [[ "$stored" != "1.200 MiB" ]]; then
    log_error "Erro no parse do tamanho armazenado: obtido $stored, esperado 1.200 MiB"
    exit 1
  fi

  log_success "Teste de métricas passou!"
}

main() {
  test_human_size
  test_duration
  test_metrics
  log_success "Todos os testes passaram com sucesso!"
}

main "$@"
