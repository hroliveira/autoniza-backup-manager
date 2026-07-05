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

test_shell_syntax() {
  log_step "Validando sintaxe shell..."

  bash -n "${PROJECT_ROOT}/bin/abm"
  local file
  for file in "${PROJECT_ROOT}"/lib/*.sh "${PROJECT_ROOT}"/*.sh; do
    bash -n "$file"
  done

  log_success "Sintaxe shell válida."
}

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

test_cli_help() {
  log_step "Testando smoke da CLI help..."

  local output
  output="$(BACKUP_ROOT="$PROJECT_ROOT" "${PROJECT_ROOT}/bin/abm" help)"
  if [[ "$output" != *"Uso: abm"* || "$output" != *"--apply"* ]]; then
    log_error "Help da CLI não contém o conteúdo esperado."
    exit 1
  fi

  log_success "Smoke da CLI help passou!"
}

test_restore_dry_run() {
  log_step "Testando restore dry-run seguro..."

  local tmp_bin output
  tmp_bin="$(mktemp -d)"
  cat > "${tmp_bin}/restic" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "snapshots" && "$2" == "--json" ]]; then
  printf '%s\n' '[{"id":"abcdef1234567890","short_id":"abcdef12","time":"2026-01-02T03:04:05.000000000Z","hostname":"test","paths":["/data"]}]'
  exit 0
fi
echo "restic mock: comando inesperado $*" >&2
exit 1
EOF
  chmod +x "${tmp_bin}/restic"

  output="$(PATH="${tmp_bin}:$PATH" BACKUP_ROOT="$PROJECT_ROOT" "${PROJECT_ROOT}/bin/abm" restore --snapshot abcdef12 --dry-run)"
  rm -rf "$tmp_bin"

  if [[ "$output" != *"DRY RUN"* || "$output" != *"Nenhuma alteração será feita"* ]]; then
    log_error "Restore dry-run não apresentou mensagem segura esperada."
    exit 1
  fi

  log_success "Restore dry-run seguro passou!"
}

test_restore_apply_requires_confirmation() {
  log_step "Testando bloqueio de --apply sem confirmação..."

  local tmp_bin output status
  tmp_bin="$(mktemp -d)"
  cat > "${tmp_bin}/restic" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "snapshots" && "$2" == "--json" ]]; then
  printf '%s\n' '[{"id":"abcdef1234567890","short_id":"abcdef12","time":"2026-01-02T03:04:05.000000000Z","hostname":"test","paths":["/data"]}]'
  exit 0
fi
echo "restic mock: comando inesperado $*" >&2
exit 1
EOF
  chmod +x "${tmp_bin}/restic"

  set +e
  output="$(PATH="${tmp_bin}:$PATH" BACKUP_ROOT="$PROJECT_ROOT" "${PROJECT_ROOT}/bin/abm" restore --snapshot abcdef12 --apply 2>&1 </dev/null)"
  status=$?
  set -e
  rm -rf "$tmp_bin"

  if [[ "$status" -eq 0 || "$output" != *"Confirmação interativa indisponível"* ]]; then
    log_error "--apply sem confirmação não foi bloqueado como esperado."
    exit 1
  fi

  log_success "--apply sem confirmação foi bloqueado."
}

main() {
  test_shell_syntax
  test_human_size
  test_duration
  test_metrics
  test_cli_help
  test_restore_dry_run
  test_restore_apply_requires_confirmation
  log_success "Todos os testes passaram com sucesso!"
}

main "$@"
