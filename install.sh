#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Instalação
# ═══════════════════════════════════════════════════════════════
# Instala dependências, cria diretórios e configura o ambiente.
# ═══════════════════════════════════════════════════════════════


# ── Cores ─────────────────────────────────────────────────────
RESET="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
BOLD="\033[1m"

# ── Configurações ─────────────────────────────────────────────
INSTALL_DIR="/opt/autoniza-backup"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_USER="${SUDO_USER:-${USER}}"

# ── Detectar distribuição ────────────────────────────────────
detect_distro() {
  if [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/redhat-release ]]; then
    echo "rhel"
  else
    echo "unknown"
  fi
}

# ── Verificar se está rodando como root ──────────────────────
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}⚠ Algumas operações requerem privilégios de root.${RESET}"
    echo -e "Reexecute com: ${BOLD}sudo bash install.sh${RESET}"
    echo ""
  fi
}

# ── Instalar dependências ────────────────────────────────────
install_deps() {
  echo -e "${BLUE}[➜]${RESET} Verificando dependências..."

  local needs_install=false
  local missing=()

  for cmd in restic jq; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
      needs_install=true
    fi
  done

  # yq pode ser yq (Python) ou o binário go-yq
  if ! command -v yq &>/dev/null && ! command -v yq-go &>/dev/null; then
    missing+=("yq")
    needs_install=true
  fi

  if ! "$needs_install"; then
    echo -e "${GREEN}[OK]${RESET} Todas as dependências já estão instaladas."
    return 0
  fi

  echo -e "${YELLOW}[INFO]${RESET} Dependências faltando: ${missing[*]}"
  echo -e "${BLUE}[➜]${RESET} Instalando..."

  local distro
  distro="$(detect_distro)"

  case "$distro" in
    debian)
      apt-get update -qq
      apt-get install -y -qq jq curl wget 2>/dev/null

      # Restic
      if ! command -v restic &>/dev/null; then
        echo -e "${BLUE}[➜]${RESET} Instalando Restic..."
        apt-get install -y -qq restic 2>/dev/null || {
          wget -q https://github.com/restic/restic/releases/latest/download/restic_linux_amd64.bz2 -O /tmp/restic.bz2
          bunzip2 /tmp/restic.bz2
          mv /tmp/restic /usr/local/bin/restic
          chmod +x /usr/local/bin/restic
        }
      fi

      # yq (go-yq)
      if ! command -v yq &>/dev/null; then
        echo -e "${BLUE}[➜]${RESET} Instalando yq..."
        wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
        chmod +x /usr/local/bin/yq
      fi
      ;;
    rhel)
      yum install -y jq curl wget 2>/dev/null || dnf install -y jq curl wget 2>/dev/null
      if ! command -v restic &>/dev/null; then
        yum install -y restic 2>/dev/null || dnf install -y restic 2>/dev/null || {
          wget -q https://github.com/restic/restic/releases/latest/download/restic_linux_amd64.bz2 -O /tmp/restic.bz2
          bunzip2 /tmp/restic.bz2
          mv /tmp/restic /usr/local/bin/restic
          chmod +x /usr/local/bin/restic
        }
      fi
      if ! command -v yq &>/dev/null; then
        wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
        chmod +x /usr/local/bin/yq
      fi
      ;;
    arch)
      pacman -S --noconfirm jq restic yq curl wget 2>/dev/null || true
      ;;
    *)
      echo -e "${YELLOW}[WARN]${RESET} Distribuição não detectada. Tentando instalar via apt..."
      apt-get update -qq 2>/dev/null && apt-get install -y -qq jq restic curl wget 2>/dev/null || true
      if ! command -v yq &>/dev/null; then
        wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
        chmod +x /usr/local/bin/yq
      fi
      if ! command -v restic &>/dev/null; then
        wget -q https://github.com/restic/restic/releases/latest/download/restic_linux_amd64.bz2 -O /tmp/restic.bz2
        bunzip2 /tmp/restic.bz2
        mv /tmp/restic /usr/local/bin/restic
        chmod +x /usr/local/bin/restic
      fi
      ;;
  esac

  echo -e "${GREEN}[OK]${RESET} Dependências instaladas."
}

# ── Instalar projeto ─────────────────────────────────────────
install_project() {
  echo ""
  echo -e "${BLUE}[➜]${RESET} Instalando Autoniza Backup Manager em ${INSTALL_DIR}..."

  # Criar diretório principal
  mkdir -p "$INSTALL_DIR"
  mkdir -p "${INSTALL_DIR}/config"
  mkdir -p "${INSTALL_DIR}/lib"
  mkdir -p "${INSTALL_DIR}/hooks"
  mkdir -p "${INSTALL_DIR}/docs"
  mkdir -p "${INSTALL_DIR}/examples"
  mkdir -p "${INSTALL_DIR}/logs"
  mkdir -p "${INSTALL_DIR}/tmp"
  mkdir -p "${INSTALL_DIR}/dumps"
  mkdir -p "${INSTALL_DIR}/reports"
  mkdir -p "${INSTALL_DIR}/restore"

  # Copiar arquivos do projeto
  echo -e "${BLUE}[➜]${RESET} Copiando arquivos..."

  # Scripts principais
  cp -f "$PROJECT_DIR/backup.sh" "${INSTALL_DIR}/backup.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/restore.sh" "${INSTALL_DIR}/restore.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/update.sh" "${INSTALL_DIR}/update.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/uninstall.sh" "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true

  # Biblioteca
  for lib in "$PROJECT_DIR"/lib/*.sh; do
    cp -f "$lib" "${INSTALL_DIR}/lib/" 2>/dev/null || true
  done

  # Hooks exemplos
  for hook in "$PROJECT_DIR"/hooks/*.sh.example; do
    cp -f "$hook" "${INSTALL_DIR}/hooks/" 2>/dev/null || true
  done

  # Documentação
  for doc in "$PROJECT_DIR"/docs/*.md; do
    cp -f "$doc" "${INSTALL_DIR}/docs/" 2>/dev/null || true
  done

  # Exemplos
  for ex in "$PROJECT_DIR"/examples/*; do
    cp -f "$ex" "${INSTALL_DIR}/examples/" 2>/dev/null || true
  done

  # Configurações (não sobrescrever existentes)
  if [[ ! -f "${INSTALL_DIR}/config/config.env" ]]; then
    cp "$PROJECT_DIR/config/config.env.example" "${INSTALL_DIR}/config/config.env"
    echo -e "${GREEN}[OK]${RESET} config.env criado."
  else
    echo -e "${YELLOW}[INFO]${RESET} config.env já existe. Não foi sobrescrito."
  fi

  if [[ ! -f "${INSTALL_DIR}/config/backup.yaml" ]]; then
    cp "$PROJECT_DIR/config/backup.yaml.example" "${INSTALL_DIR}/config/backup.yaml"
    echo -e "${GREEN}[OK]${RESET} backup.yaml criado."
  else
    echo -e "${YELLOW}[INFO]${RESET} backup.yaml já existe. Não foi sobrescrito."
  fi

  # Tornar scripts executáveis
  chmod +x "${INSTALL_DIR}"/*.sh 2>/dev/null || true
  chmod +x "${INSTALL_DIR}"/hooks/*.sh* 2>/dev/null || true

  # Ajustar proprietário
  if [[ -n "$BACKUP_USER" ]]; then
    chown -R "$BACKUP_USER":"$BACKUP_USER" "$INSTALL_DIR" 2>/dev/null || true
  fi

  echo -e "${GREEN}[OK]${RESET} Instalação concluída em ${INSTALL_DIR}."
}

# ── Pós-instalação ───────────────────────────────────────────
post_install() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║            Autoniza Backup Manager instalado!                ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo -e "${BOLD}📋 Próximos passos:${RESET}"
  echo ""
  echo "  1. Configure o MinIO/S3:"
  echo "     ${BLUE}   sudo nano ${INSTALL_DIR}/config/config.env${RESET}"
  echo ""
  echo "  2. Configure os backups:"
  echo "     ${BLUE}   sudo nano ${INSTALL_DIR}/config/backup.yaml${RESET}"
  echo ""
  echo "  3. Teste o backup manualmente:"
  echo "     ${BLUE}   sudo ${INSTALL_DIR}/backup.sh${RESET}"
  echo ""
  echo "  4. Agende no cron (opcional):"
  echo "     Adicione ao crontab:"
  echo "     ${BLUE}   0 2 * * * ${INSTALL_DIR}/backup.sh >> ${INSTALL_DIR}/logs/cron.log 2>&1${RESET}"
  echo ""
  echo "  5. Veja a documentação completa:"
  echo "     ${BLUE}   cat ${INSTALL_DIR}/docs/INSTALL.md${RESET}"
  echo ""
  echo -e "${YELLOW}⚠ Lembre-se de preencher as credenciais no config.env antes de executar o backup!${RESET}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────
main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║         Autoniza Backup Manager - Instalação                ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  check_root
  install_deps
  install_project
  post_install
}

main "$@"
