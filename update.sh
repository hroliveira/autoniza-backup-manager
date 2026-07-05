#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Atualização (v2.0.0)
# ═══════════════════════════════════════════════════════════════

RESET="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"

INSTALL_DIR="/opt/autoniza-backup"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_USER="${SUDO_USER:-${USER}}"
UPDATE_ID="$(date '+%Y%m%d_%H%M%S')"
UPDATE_BACKUP_DIR="${INSTALL_DIR}/backups/update_${UPDATE_ID}"

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

for required in backup.sh restore.sh update.sh uninstall.sh VERSION bin/abm; do
  if [[ ! -e "${PROJECT_DIR}/${required}" ]]; then
    echo -e "${YELLOW}⚠ Arquivo obrigatório ausente no pacote: ${required}.${RESET}"
    exit 1
  fi
done

echo -e "${BLUE}[➜]${RESET} Atualizando scripts em ${INSTALL_DIR}..."

mkdir -p "$UPDATE_BACKUP_DIR/config" "$UPDATE_BACKUP_DIR/bin" "$UPDATE_BACKUP_DIR/lib" "$UPDATE_BACKUP_DIR/root"
echo -e "${GREEN}[OK]${RESET} Backup de rollback criado em ${UPDATE_BACKUP_DIR}."

# Backup de configurações e artefatos existentes
if [[ -f "${INSTALL_DIR}/config/config.env" ]]; then
  cp "${INSTALL_DIR}/config/config.env" "${UPDATE_BACKUP_DIR}/config/config.env"
  echo -e "${GREEN}[OK]${RESET} Backup de config.env criado."
fi
if [[ -f "${INSTALL_DIR}/config/backup.yaml" ]]; then
  cp "${INSTALL_DIR}/config/backup.yaml" "${UPDATE_BACKUP_DIR}/config/backup.yaml"
  echo -e "${GREEN}[OK]${RESET} Backup de backup.yaml criado."
fi
for file in backup.sh restore.sh update.sh uninstall.sh VERSION CHANGELOG.md; do
  [[ -f "${INSTALL_DIR}/${file}" ]] && cp "${INSTALL_DIR}/${file}" "${UPDATE_BACKUP_DIR}/root/" 2>/dev/null || true
done
[[ -f "${INSTALL_DIR}/bin/abm" ]] && cp "${INSTALL_DIR}/bin/abm" "${UPDATE_BACKUP_DIR}/bin/abm" 2>/dev/null || true
if [[ -d "${INSTALL_DIR}/lib" ]]; then
  cp -a "${INSTALL_DIR}/lib/." "${UPDATE_BACKUP_DIR}/lib/" 2>/dev/null || true
fi

# Garantir que a pasta bin existe
mkdir -p "${INSTALL_DIR}/bin"

# Copiar scripts principais e binários
cp -f "$PROJECT_DIR/backup.sh" "${INSTALL_DIR}/backup.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/restore.sh" "${INSTALL_DIR}/restore.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/update.sh" "${INSTALL_DIR}/update.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/uninstall.sh" "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true
cp -f "$PROJECT_DIR/VERSION" "${INSTALL_DIR}/VERSION" 2>/dev/null || true
cp -f "$PROJECT_DIR/CHANGELOG.md" "${INSTALL_DIR}/CHANGELOG.md" 2>/dev/null || true

# Copiar CLI abm
if [[ -f "$PROJECT_DIR/bin/abm" ]]; then
  cp -f "$PROJECT_DIR/bin/abm" "${INSTALL_DIR}/bin/abm"
  chmod +x "${INSTALL_DIR}/bin/abm"
  echo -e "${GREEN}[OK]${RESET} CLI abm copiada para ${INSTALL_DIR}/bin/abm"
fi

# Copiar bibliotecas
for lib in "$PROJECT_DIR"/lib/*.sh; do
  cp -f "$lib" "${INSTALL_DIR}/lib/" 2>/dev/null || true
done

# Copiar hooks exemplos
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
if [[ -d "$PROJECT_DIR/examples" ]]; then
  for ex in "$PROJECT_DIR"/examples/*; do
    cp -f "$ex" "${INSTALL_DIR}/examples/" 2>/dev/null || true
  done
fi

chmod +x "${INSTALL_DIR}"/*.sh 2>/dev/null || true

# Recriar link simbólico para a CLI se tiver privilégios de root
if [[ $EUID -eq 0 ]]; then
  if [[ -f "${INSTALL_DIR}/bin/abm" ]]; then
    ln -sf "${INSTALL_DIR}/bin/abm" /usr/local/bin/abm
    echo -e "${GREEN}[OK]${RESET} Link simbólico /usr/local/bin/abm atualizado."
  fi
fi

if [[ -n "$BACKUP_USER" ]]; then
  chown -R "$BACKUP_USER":"$BACKUP_USER" "$INSTALL_DIR" 2>/dev/null || true
fi

echo -e "${GREEN}[OK]${RESET} Atualização concluída com sucesso!"
echo -e "${BLUE}[INFO]${RESET} Rollback manual disponível em: ${UPDATE_BACKUP_DIR}"
