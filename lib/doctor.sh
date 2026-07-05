#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_DOCTOR_LOADED:-}" ]] && return 0
ABM_DOCTOR_LOADED=1

# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Doctor Library
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="${BACKUP_ROOT:-/opt/autoniza-backup}"

# Função para printar resultado formatado
print_check_result() {
  local name="$1"
  local status="$2" # PASS, WARNING, FAIL
  local detail="${3:-}"

  case "$status" in
    PASS)
      echo -e "${ABM_GREEN}✔${ABM_RESET} ${ABM_BOLD}${name}${ABM_RESET} : ${ABM_GREEN}PASS${ABM_RESET} ${detail}"
      ;;
    WARNING)
      echo -e "${ABM_YELLOW}⚠${ABM_RESET} ${ABM_BOLD}${name}${ABM_RESET} : ${ABM_YELLOW}WARNING${ABM_RESET} ${detail}"
      ;;
    FAIL)
      echo -e "${ABM_RED}✘${ABM_RESET} ${ABM_BOLD}${name}${ABM_RESET} : ${ABM_RED}FAIL${ABM_RESET} ${detail}"
      ;;
  esac
}

run_doctor() {
  log_step "Iniciando bateria de testes do sistema (abm doctor)..."
  echo ""

  local total_checks=20
  local score=0

  # Helper para adicionar ao score
  # PASS = +100, WARNING = +50, FAIL = 0
  add_score() {
    local res="$1"
    if [[ "$res" == "PASS" ]]; then
      score=$((score + 100))
    elif [[ "$res" == "WARNING" ]]; then
      score=$((score + 50))
    fi
  }

  # 1. Docker
  local r_docker="FAIL"
  if command -v docker &>/dev/null; then
    r_docker="PASS"
  fi
  print_check_result "Docker" "$r_docker"
  add_score "$r_docker"

  # 2. Docker daemon
  local r_dockerd="FAIL"
  if [[ "$r_docker" == "PASS" ]]; then
    if docker info &>/dev/null; then
      r_dockerd="PASS"
    else
      r_dockerd="FAIL"
    fi
  else
    r_dockerd="WARNING" # Docker não instalado, daemon ignorado
  fi
  print_check_result "Docker daemon" "$r_dockerd"
  add_score "$r_dockerd"

  # 3. Restic
  local r_restic="FAIL"
  if command -v restic &>/dev/null; then
    r_restic="PASS"
  fi
  print_check_result "Restic" "$r_restic"
  add_score "$r_restic"

  # 4. PostgreSQL
  local r_pg="PASS"
  # Se postgres estiver configurado no yaml, validar se existe container
  if [[ -f "${BACKUP_ROOT}/config/backup.yaml" ]]; then
    local pg_count
    pg_count="$(yq eval '.postgres | length' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo 0)"
    if [[ "$pg_count" -gt 0 ]]; then
      # Verificar se os containers do postgres estão rodando
      for i in $(seq 0 $((pg_count - 1))); do
        local pg_container
        pg_container="$(yq eval ".postgres[$i].container" "${BACKUP_ROOT}/config/backup.yaml")"
        if ! docker ps --filter "name=${pg_container}" --format '{{.Names}}' | grep -q "^${pg_container}$"; then
          r_pg="FAIL"
        fi
      done
    fi
  fi
  print_check_result "PostgreSQL" "$r_pg"
  add_score "$r_pg"

  # 5. MySQL
  local r_mysql="PASS"
  if [[ -f "${BACKUP_ROOT}/config/backup.yaml" ]]; then
    local mysql_count
    mysql_count="$(yq eval '.mysql | length' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo 0)"
    if [[ "$mysql_count" -gt 0 ]]; then
      for i in $(seq 0 $((mysql_count - 1))); do
        local my_container
        my_container="$(yq eval ".mysql[$i].container" "${BACKUP_ROOT}/config/backup.yaml")"
        if ! docker ps --filter "name=${my_container}" --format '{{.Names}}' | grep -q "^${my_container}$"; then
          r_mysql="FAIL"
        fi
      done
    fi
  fi
  print_check_result "MySQL" "$r_mysql"
  add_score "$r_mysql"

  # 6. Redis
  local r_redis="PASS"
  if [[ -f "${BACKUP_ROOT}/config/backup.yaml" ]]; then
    local redis_count
    redis_count="$(yq eval '.redis | length' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo 0)"
    if [[ "$redis_count" -gt 0 ]]; then
      for i in $(seq 0 $((redis_count - 1))); do
        local rd_container
        rd_container="$(yq eval ".redis[$i].container" "${BACKUP_ROOT}/config/backup.yaml")"
        if ! docker ps --filter "name=${rd_container}" --format '{{.Names}}' | grep -q "^${rd_container}$"; then
          r_redis="FAIL"
        fi
      done
    fi
  fi
  print_check_result "Redis" "$r_redis"
  add_score "$r_redis"

  # 7. Espaço em disco
  local r_disk="FAIL"
  local disk_pct
  # Obter porcentagem de uso do disco onde o backup está
  disk_pct=$(df -h "$BACKUP_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
  if [[ -n "$disk_pct" ]]; then
    if [[ "$disk_pct" -lt 80 ]]; then
      r_disk="PASS"
    elif [[ "$disk_pct" -lt 95 ]]; then
      r_disk="WARNING"
    else
      r_disk="FAIL"
    fi
  fi
  print_check_result "Espaço em disco" "$r_disk" "(${disk_pct:-0}% usado)"
  add_score "$r_disk"

  # 8. Cron
  local r_cron="FAIL"
  if systemctl is-active cron &>/dev/null || systemctl is-active crond &>/dev/null || pgrep cron &>/dev/null; then
    r_cron="PASS"
  fi
  print_check_result "Cron" "$r_cron"
  add_score "$r_cron"

  # 9. Permissões
  local r_perm="FAIL"
  if [[ -w "$BACKUP_ROOT" && -w "${BACKUP_ROOT}/logs" ]]; then
    r_perm="PASS"
  fi
  print_check_result "Permissões" "$r_perm"
  add_score "$r_perm"

  # 10. MinIO / S3 Connection
  local r_minio="FAIL"
  if [[ -n "${RESTIC_REPOSITORY:-}" ]]; then
    # Se repo é s3:, tentar conexão rápida de restic list ou teste dns/curl
    if [[ "$RESTIC_REPOSITORY" =~ ^s3: ]]; then
      # Testar se restic snapshots responde rápido
      if restic snapshots --quiet 2>/dev/null; then
        r_minio="PASS"
      else
        r_minio="FAIL"
      fi
    else
      r_minio="PASS" # Repo local ou não-S3, considerar PASS
    fi
  else
    r_minio="WARNING"
  fi
  print_check_result "MinIO" "$r_minio"
  add_score "$r_minio"

  # 11. Bucket
  local r_bucket="FAIL"
  if [[ "$r_minio" == "PASS" ]]; then
    r_bucket="PASS"
  else
    r_bucket="FAIL"
  fi
  print_check_result "Bucket" "$r_bucket"
  add_score "$r_bucket"

  # 12. Credenciais
  local r_creds="FAIL"
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" && -n "${RESTIC_PASSWORD:-}" ]]; then
    r_creds="PASS"
  else
    r_creds="FAIL"
  fi
  print_check_result "Credenciais" "$r_creds"
  add_score "$r_creds"

  # 13. Webhook
  local r_web="WARNING"
  if [[ -n "${WEBHOOK_URL:-}" ]]; then
    # Testar se webhook responde via curl
    if curl -s -I --connect-timeout 3 "$WEBHOOK_URL" &>/dev/null; then
      r_web="PASS"
    else
      r_web="FAIL"
    fi
  else
    r_web="WARNING" # Sem webhook configurado é um WARNING
  fi
  print_check_result "Webhook" "$r_web"
  add_score "$r_web"

  # 14. jq
  local r_jq="FAIL"
  if command -v jq &>/dev/null; then
    r_jq="PASS"
  fi
  print_check_result "jq" "$r_jq"
  add_score "$r_jq"

  # 15. yq
  local r_yq="FAIL"
  if command -v yq &>/dev/null || command -v yq-go &>/dev/null; then
    r_yq="PASS"
  fi
  print_check_result "yq" "$r_yq"
  add_score "$r_yq"

  # 16. curl
  local r_curl="FAIL"
  if command -v curl &>/dev/null; then
    r_curl="PASS"
  fi
  print_check_result "curl" "$r_curl"
  add_score "$r_curl"

  # 17. gzip
  local r_gzip="FAIL"
  if command -v gzip &>/dev/null; then
    r_gzip="PASS"
  fi
  print_check_result "gzip" "$r_gzip"
  add_score "$r_gzip"

  # 18. pg_dump
  local r_pgdump="FAIL"
  if command -v pg_dump &>/dev/null; then
    r_pgdump="PASS"
  else
    # Se postgres não for configurado no yaml, pg_dump ausente é apenas WARNING
    if [[ -f "${BACKUP_ROOT}/config/backup.yaml" ]]; then
      local pgc
      pgc="$(yq eval '.postgres | length' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo 0)"
      if [[ "$pgc" -eq 0 ]]; then
        r_pgdump="WARNING"
      fi
    else
      r_pgdump="WARNING"
    fi
  fi
  print_check_result "pg_dump" "$r_pgdump"
  add_score "$r_pgdump"

  # 19. mysqldump
  local r_mydump="FAIL"
  if command -v mysqldump &>/dev/null; then
    r_mydump="PASS"
  else
    if [[ -f "${BACKUP_ROOT}/config/backup.yaml" ]]; then
      local myc
      myc="$(yq eval '.mysql | length' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo 0)"
      if [[ "$myc" -eq 0 ]]; then
        r_mydump="WARNING"
      fi
    else
      r_mydump="WARNING"
    fi
  fi
  print_check_result "mysqldump" "$r_mydump"
  add_score "$r_mydump"

  # 20. redis-cli
  local r_rediscli="FAIL"
  if command -v redis-cli &>/dev/null; then
    r_rediscli="PASS"
  else
    if [[ -f "${BACKUP_ROOT}/config/backup.yaml" ]]; then
      local rdc
      rdc="$(yq eval '.redis | length' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo 0)"
      if [[ "$rdc" -eq 0 ]]; then
        r_rediscli="WARNING"
      fi
    else
      r_rediscli="WARNING"
    fi
  fi
  print_check_result "redis-cli" "$r_rediscli"
  add_score "$r_rediscli"

  # Calcular a pontuação de saúde total em porcentagem
  local health_score=$((score / total_checks))
  echo ""
  echo "═══════════════════════════════════════════════"
  if [[ "$health_score" -ge 90 ]]; then
    echo -e "Health Score: ${ABM_GREEN}${health_score}%${ABM_RESET}"
  elif [[ "$health_score" -ge 70 ]]; then
    echo -e "Health Score: ${ABM_YELLOW}${health_score}%${ABM_RESET}"
  else
    echo -e "Health Score: ${ABM_RED}${health_score}%${ABM_RESET}"
  fi
  echo "═══════════════════════════════════════════════"
  echo ""

  # Enviar notificação de status de saúde se configurado
  if [[ -n "${WEBHOOK_URL:-}" ]]; then
    notify_doctor "$health_score"
  fi
  
  if [[ "$health_score" -lt 70 ]]; then
    return 1
  fi
  return 0
}
