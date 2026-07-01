#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Atualização
# ═══════════════════════════════════════════════════════════════
# Atualiza os scripts do projeto mantendo configurações.
# ═══════════════════════════════════════════════════════════════


RESET="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"

INSTALL_DIR="/opt/autoniza-backup"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_USER="${SUDO_USER:-${USER}}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Autoniza Backup Manager - Atualização               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo -e "${YELLOW}⚠ O diretório ${INSTALL_DIR} não existe. Execute install.sh primeiro.${RESET}"
  echo -e "   ${BLUE}sudo bash install.sh${RESET}"
  exit 1
fi

echo -e "${BLUE}[➜]${RESET} Atualizando scripts em ${INSTALL_DIR}..."

# Backup de configurações existentes
if [[ -f "${INSTALL_DIR}/config/config.env" ]]; then
  cp "${INSTALL_DIR}/config/config.env" "${INSTALL_DIR}/config/config.env.bkp"
  echo -e "${GREEN}[OK]${RESET} Backup de config.env criado."
fi
if [[ -f "${INSTALL_DIR}/config/backup.yaml" ]]; then
  cp "${INSTALL_DIR}/config/backup.yaml" "${INSTALL_DIR}/config/backup.yaml.bkp"
  echo -e "${GREEN}[OK]${RESET} Backup de backup.yaml criado."
fi

# Copiar scripts principais
cp -f "$PROJECT_DIR/backup.sh" "${INSTALL_DIR}/backup.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/restore.sh" "${INSTALL_DIR}/restore.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/update.sh" "${INSTALL_DIR}/update.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/uninstall.sh" "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true

# Copiar bibliotecas
for lib in "$PROJECT_DIR"/lib/*.sh; do
  cp -f "$lib" "${INSTALL_DIR}/lib/" 2>/dev/null || true
done

# Copiar hooks exemplos (não sobrescrever hooks customizados sem .example)
for hook in "$PROJECT_DIR"/hooks/*.sh.example; do
  hook_name="$(basename "$hook")"
  if [[ ! -f "${INSTALL_DIR}/hooks/${hook_name%.example}" ]]; then
    cp -f "$hook" "${INSTALL_DIR}/hooks/" 2>/dev/null || true
  fi
done

# Copiar documentação e exemplos
for doc in "$PROJECT_DIR"/docs/*.md; do
  cp -f "$doc" "${INSTALL_DIR}/docs/" 2>/dev/null || true
done
for ex in "$PROJECT_DIR"/examples/*; do
  cp -f "$ex" "${INSTALL_DIR}/examples/" 2>/dev/null || true
done

chmod +x "${INSTALL_DIR}"/*.sh 2>/dev/null || true

if [[ -n "$BACKUP_USER" ]]; then
  chown -R "$BACKUP_USER":"$BACKUP_USER" "$INSTALL_DIR" 2>/dev/null || true
fi

echo -e "${GREEN}[OK]${RESET} Atualização concluída!"
echo -e "${YELLOW}[INFO]${RESET} Configurações existentes foram preservadas (backups criados como .bkp)."
