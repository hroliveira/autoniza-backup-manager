#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Instalação (v2.0.0)
# ═══════════════════════════════════════════════════════════════

RESET="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
BOLD="\033[1m"

INSTALL_DIR="/opt/autoniza-backup"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_USER="${SUDO_USER:-${USER}}"
RESTIC_VERSION="${RESTIC_VERSION:-0.18.0}"
YQ_VERSION="${YQ_VERSION:-4.45.4}"

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

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}⚠ Algumas operações requerem privilégios de root.${RESET}"
    echo -e "Reexecute com: ${BOLD}sudo bash install.sh${RESET}"
    echo ""
  fi
}

install_restic_pinned() {
  local url="https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"
  echo -e "${BLUE}[➜]${RESET} Instalando Restic ${RESTIC_VERSION} via release pinada..."
  wget -q "$url" -O /tmp/restic.bz2
  bunzip2 -f /tmp/restic.bz2
  mv /tmp/restic /usr/local/bin/restic
  chmod +x /usr/local/bin/restic
}

install_yq_pinned() {
  local url="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64"
  echo -e "${BLUE}[➜]${RESET} Instalando yq ${YQ_VERSION} via release pinada..."
  wget -q "$url" -O /usr/local/bin/yq
  chmod +x /usr/local/bin/yq
}

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
      if ! command -v restic &>/dev/null; then
        apt-get install -y -qq restic 2>/dev/null || {
          install_restic_pinned
        }
      fi
      if ! command -v yq &>/dev/null; then
        install_yq_pinned
      fi
      ;;
    rhel)
      yum install -y jq curl wget 2>/dev/null || dnf install -y jq curl wget 2>/dev/null
      if ! command -v restic &>/dev/null; then
        yum install -y restic 2>/dev/null || dnf install -y restic 2>/dev/null || {
          install_restic_pinned
        }
      fi
      if ! command -v yq &>/dev/null; then
        install_yq_pinned
      fi
      ;;
    arch)
      pacman -S --noconfirm jq restic yq curl wget 2>/dev/null || true
      ;;
    *)
      echo -e "${YELLOW}[WARN]${RESET} Distribuição não detectada. Tentando instalar via apt..."
      apt-get update -qq 2>/dev/null && apt-get install -y -qq jq restic curl wget 2>/dev/null || true
      if ! command -v yq &>/dev/null; then
        install_yq_pinned
      fi
      if ! command -v restic &>/dev/null; then
        install_restic_pinned
      fi
      ;;
  esac
  echo -e "${GREEN}[OK]${RESET} Dependências instaladas."
}

install_project() {
  echo ""
  echo -e "${BLUE}[➜]${RESET} Instalando Autoniza Backup Manager em ${INSTALL_DIR}..."

  mkdir -p "$INSTALL_DIR"
  mkdir -p "${INSTALL_DIR}/config"
  mkdir -p "${INSTALL_DIR}/bin"
  mkdir -p "${INSTALL_DIR}/lib"
  mkdir -p "${INSTALL_DIR}/hooks"
  mkdir -p "${INSTALL_DIR}/docs"
  mkdir -p "${INSTALL_DIR}/examples"
  mkdir -p "${INSTALL_DIR}/logs"
  mkdir -p "${INSTALL_DIR}/tmp"
  mkdir -p "${INSTALL_DIR}/dumps"
  mkdir -p "${INSTALL_DIR}/reports"
  mkdir -p "${INSTALL_DIR}/restore"

  echo -e "${BLUE}[➜]${RESET} Copiando arquivos..."

  cp -f "$PROJECT_DIR/backup.sh" "${INSTALL_DIR}/backup.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/restore.sh" "${INSTALL_DIR}/restore.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/update.sh" "${INSTALL_DIR}/update.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/uninstall.sh" "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true
  cp -f "$PROJECT_DIR/VERSION" "${INSTALL_DIR}/VERSION" 2>/dev/null || true
  cp -f "$PROJECT_DIR/CHANGELOG.md" "${INSTALL_DIR}/CHANGELOG.md" 2>/dev/null || true

  # Copiar abm CLI
  if [[ -f "$PROJECT_DIR/bin/abm" ]]; then
    cp -f "$PROJECT_DIR/bin/abm" "${INSTALL_DIR}/bin/abm"
    chmod +x "${INSTALL_DIR}/bin/abm"
    echo -e "${GREEN}[OK]${RESET} CLI abm instalada em ${INSTALL_DIR}/bin/abm"
  fi

  for lib in "$PROJECT_DIR"/lib/*.sh; do
    cp -f "$lib" "${INSTALL_DIR}/lib/" 2>/dev/null || true
  done

  for hook in "$PROJECT_DIR"/hooks/*.sh.example; do
    cp -f "$hook" "${INSTALL_DIR}/hooks/" 2>/dev/null || true
  done

  for doc in "$PROJECT_DIR"/docs/*.md; do
    cp -f "$doc" "${INSTALL_DIR}/docs/" 2>/dev/null || true
  done

  if [[ -d "$PROJECT_DIR/examples" ]]; then
    for ex in "$PROJECT_DIR"/examples/*; do
      cp -f "$ex" "${INSTALL_DIR}/examples/" 2>/dev/null || true
    done
  fi

  if [[ ! -f "${INSTALL_DIR}/config/config.env" ]]; then
    cp "$PROJECT_DIR/config/config.env.example" "${INSTALL_DIR}/config/config.env"
    echo -e "${GREEN}[OK]${RESET} config.env criado."
  fi

  if [[ ! -f "${INSTALL_DIR}/config/backup.yaml" ]]; then
    cp "$PROJECT_DIR/config/backup.yaml.example" "${INSTALL_DIR}/config/backup.yaml"
    echo -e "${GREEN}[OK]${RESET} backup.yaml criado."
  fi

  chmod +x "${INSTALL_DIR}"/*.sh 2>/dev/null || true
  chmod +x "${INSTALL_DIR}"/hooks/*.sh* 2>/dev/null || true

  # Link Simbólico
  if [[ $EUID -eq 0 ]]; then
    ln -sf "${INSTALL_DIR}/bin/abm" /usr/local/bin/abm
    echo -e "${GREEN}[OK]${RESET} CLI abm linkada globalmente em /usr/local/bin/abm"
  fi

  if [[ -n "$BACKUP_USER" ]]; then
    chown -R "$BACKUP_USER":"$BACKUP_USER" "$INSTALL_DIR" 2>/dev/null || true
  fi

  echo -e "${GREEN}[OK]${RESET} Instalação concluída em ${INSTALL_DIR}."
}

post_install() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║         Autoniza Backup Manager instalado com sucesso!       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo -e "${BOLD}📋 Comandos disponíveis:${RESET}"
  echo "  - ${BLUE}abm status${RESET}    : Verifica o status e resumo do servidor"
  echo "  - ${BLUE}abm doctor${RESET}    : Roda diagnósticos e avalia o Health Score"
  echo "  - ${BLUE}abm backup${RESET}    : Executa backup completo"
  echo "  - ${BLUE}abm restore${RESET}   : Entra no modo de restauração interativo"
  echo "  - ${BLUE}abm schedule${RESET}  : Gerencia agendamento Cron"
  echo ""
  echo -e "${BOLD}📋 Próximos passos:${RESET}"
  echo "  1. Ajuste as credenciais S3: ${BLUE}sudo nano ${INSTALL_DIR}/config/config.env${RESET}"
  echo "  2. Configure os escopos:     ${BLUE}sudo nano ${INSTALL_DIR}/config/backup.yaml${RESET}"
  echo "  3. Rode a checagem inicial:  ${BLUE}abm doctor${RESET}"
  echo ""
}

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║         Autoniza Backup Manager - Instalação v2             ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""

  check_root
  install_deps
  install_project
  post_install
}

main "$@"
