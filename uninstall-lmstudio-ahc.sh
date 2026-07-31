#!/usr/bin/env bash
# ============================================================
# LM Studio - AHC Uninstaller
# Removes files created by install-lmstudio-ahc.sh.
#
# By default, it DOES NOT delete ~/.lmstudio/models because
# model files can be large and may have been downloaded manually.
# ============================================================

set -Eeuo pipefail

APP_DIR="${HOME}/.local/opt/lm-studio"
BIN_LINK="${HOME}/.local/bin/lmstudio"
DESKTOP_FILE="${HOME}/.local/share/applications/lm-studio-ahc.desktop"
STATE_FILE="${HOME}/.lmstudio/ahc-profile.conf"

echo "LM Studio AHC - desinstalação"
echo
read -r -p "Remover o AppImage e o atalho criados pelo AHC? [S/n] " ans
ans="${ans:-S}"
[[ "$ans" =~ ^[SsYy]$ ]] || { echo "Cancelado."; exit 0; }

rm -rf "$APP_DIR"
rm -f "$BIN_LINK" "$DESKTOP_FILE" "$STATE_FILE"

echo
echo "Removido:"
echo "  $APP_DIR"
echo "  $BIN_LINK"
echo "  $DESKTOP_FILE"
echo
echo "Os modelos em ~/.lmstudio/models NÃO foram removidos."
echo "Se quiser removê-los manualmente, verifique antes:"
echo "  du -sh ~/.lmstudio/models 2>/dev/null || true"
echo
echo "Nenhuma alteração foi feita no swap, firewall, kernel ou serviços do sistema."
