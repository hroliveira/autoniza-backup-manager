#!/usr/bin/env bash
set -Eeuo pipefail
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Desinstalação (v2.0.0)
# ═══════════════════════════════════════════════════════════════

RESET="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BOLD="\033[1m"

INSTALL_DIR="/opt/autoniza-backup"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Autoniza Backup Manager - Desinstalação               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo -e "${YELLOW}⚠ O diretório ${INSTALL_DIR} não existe. Nada a desinstalar.${RESET}"
  exit 0
fi

echo -e "${RED}⚠ ATENÇÃO: Isso removerá o Autoniza Backup Manager.${RESET}"
echo ""
echo "Opções:"
echo "  1 - Remover apenas os scripts e CLI (mantém configurações e dados)"
echo "  2 - Remover tudo (scripts, configurações, logs, dumps e CLI global)"
echo "  3 - Cancelar"
echo ""

read -rp "Escolha uma opção (1/2/3): " option

case "$option" in
  1)
    echo -e "${YELLOW}[INFO]${RESET} Removendo scripts e CLI..."
    rm -f "${INSTALL_DIR}/backup.sh"
    rm -f "${INSTALL_DIR}/restore.sh"
    rm -f "${INSTALL_DIR}/update.sh"
    rm -f "${INSTALL_DIR}/uninstall.sh"
    rm -rf "${INSTALL_DIR}/lib"
    rm -rf "${INSTALL_DIR}/bin"
    rm -rf "${INSTALL_DIR}/hooks"
    rm -rf "${INSTALL_DIR}/docs"
    rm -rf "${INSTALL_DIR}/examples"
    
    # Remover link simbólico
    if [[ -L /usr/local/bin/abm ]]; then
      rm -f /usr/local/bin/abm
      echo -e "${GREEN}[OK]${RESET} Link simbólico /usr/local/bin/abm removido."
    fi
    
    echo -e "${GREEN}[OK]${RESET} Scripts e CLI removidos. Configurações preservadas em:"
    echo -e "   ${INSTALL_DIR}/config/"
    echo -e "   ${INSTALL_DIR}/logs/"
    echo -e "   ${INSTALL_DIR}/reports/"
    echo -e "   ${INSTALL_DIR}/dumps/"
    ;;
  2)
    echo -e "${RED}⚠ Isso irá apagar TODOS os dados, incluindo backups locais!${RESET}"
    read -rp "Tem certeza? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
      echo -e "${YELLOW}⚠ Desinstalação cancelada.${RESET}"
      exit 0
    fi
    echo -e "${YELLOW}[INFO]${RESET} Removendo ${INSTALL_DIR}..."
    rm -rf "$INSTALL_DIR"
    
    # Remover link simbólico
    if [[ -L /usr/local/bin/abm ]]; then
      rm -f /usr/local/bin/abm
      echo -e "${GREEN}[OK]${RESET} Link simbólico /usr/local/bin/abm removido."
    fi
    echo -e "${GREEN}[OK]${RESET} Autoniza Backup Manager removido completamente."
    ;;
  *)
    echo -e "${YELLOW}⚠ Desinstalação cancelada.${RESET}"
    exit 0
    ;;
esac

echo ""
echo -e "${GREEN}✅ Desinstalação concluída.${RESET}"
