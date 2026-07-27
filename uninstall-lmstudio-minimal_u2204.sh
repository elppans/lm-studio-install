```bash
#!/usr/bin/env bash

# ============================================================
# LM Studio Minimal Uninstaller
# Ubuntu 22.04
#
# Remove as configurações criadas pelo:
# install-lmstudio-minimal_u2204.sh
#
# Por padrão:
# - Remove configurações de swappiness
# - Remove o lançador .desktop
# - Remove ~/LMStudio
# - NÃO remove ~/.lmstudio
# - NÃO remove modelos baixados pelo LM Studio
# - NÃO remove /swapfile automaticamente
#
# Modos:
#
#   ./uninstall-lmstudio-minimal_u2204.sh
#
#       Remove apenas as configurações do sistema e o
#       diretório ~/LMStudio.
#
#
#   ./uninstall-lmstudio-minimal_u2204.sh --remove-swap
#
#       Além da limpeza normal, oferece remover o /swapfile
#       criado pelo instalador.
#
#
#   ./uninstall-lmstudio-minimal_u2204.sh --full
#
#       Remove também ~/.lmstudio.
#
#       ATENÇÃO:
#       Isso pode apagar modelos baixados, configurações,
#       conversas e outros dados do LM Studio.
#
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Cores
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ------------------------------------------------------------
# Variáveis
# ------------------------------------------------------------

LM_DIR="$HOME/LMStudio"

LM_DATA_DIR="$HOME/.lmstudio"

DESKTOP_FILE="$HOME/.local/share/applications/lmstudio-minimal.desktop"

SYSCTL_FILE="/etc/sysctl.d/99-lmstudio-minimal.conf"

SWAPFILE="/swapfile"

REMOVE_SWAP=false

FULL_REMOVE=false

# ------------------------------------------------------------
# Funções
# ------------------------------------------------------------

msg() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# ------------------------------------------------------------
# Ajuda
# ------------------------------------------------------------

show_help() {

    echo
    echo "Uso:"
    echo
    echo "  $0"
    echo
    echo "Remoção padrão."
    echo
    echo "Remove:"
    echo "  - Configuração de swappiness"
    echo "  - Lançador do LM Studio"
    echo "  - Diretório ~/LMStudio"
    echo
    echo "Não remove:"
    echo "  - ~/.lmstudio"
    echo "  - Modelos baixados"
    echo "  - /swapfile"
    echo
    echo "------------------------------------------------------------"
    echo
    echo "  $0 --remove-swap"
    echo
    echo "Executa a remoção padrão e oferece remover o /swapfile."
    echo
    echo "------------------------------------------------------------"
    echo
    echo "  $0 --full"
    echo
    echo "Remove também:"
    echo "  ~/.lmstudio"
    echo
    echo "ATENÇÃO:"
    echo "Isso pode apagar modelos e dados do LM Studio."
    echo
    echo "------------------------------------------------------------"
    echo
    echo "  $0 --full --remove-swap"
    echo
    echo "Executa uma remoção completa incluindo:"
    echo "  - Configurações do projeto"
    echo "  - ~/LMStudio"
    echo "  - ~/.lmstudio"
    echo "  - /swapfile (mediante confirmação)"
    echo
}

# ------------------------------------------------------------
# Processar argumentos
# ------------------------------------------------------------

for ARG in "$@"; do

    case "$ARG" in

        --remove-swap)
            REMOVE_SWAP=true
            ;;

        --full)
            FULL_REMOVE=true
            ;;

        --help|-h)
            show_help
            exit 0
            ;;

        *)
            error "Opção desconhecida: $ARG"
            echo
            echo "Use:"
            echo "  $0 --help"
            exit 1
            ;;

    esac

done

# ------------------------------------------------------------
# Verificar root
# ------------------------------------------------------------

if [[ "$EUID" -eq 0 ]]; then

    error "Não execute este script como root."

    echo
    echo "Execute como seu usuário normal:"
    echo
    echo "  ./uninstall-lmstudio-minimal_u2204.sh"
    echo

    exit 1

fi

# ------------------------------------------------------------
# Verificar sudo
# ------------------------------------------------------------

if ! sudo -v; then

    error "Não foi possível obter privilégios sudo."

    exit 1

fi

# ------------------------------------------------------------
# Cabeçalho
# ------------------------------------------------------------

clear

echo
echo "============================================================"
echo "       LM STUDIO - DESINSTALAÇÃO / LIMPEZA"
echo "============================================================"
echo

echo "Usuário : $USER"
echo "Home    : $HOME"

echo

# ------------------------------------------------------------
# Mostrar modo
# ------------------------------------------------------------

if [[ "$FULL_REMOVE" == true ]]; then

    warn "MODO DE REMOÇÃO COMPLETA ATIVADO."

    echo
    echo "O diretório abaixo poderá ser removido:"
    echo
    echo "  $LM_DATA_DIR"
    echo
    echo "Esse diretório pode conter:"
    echo
    echo "  - Modelos de IA"
    echo "  - Configurações"
    echo "  - Conversas"
    echo "  - Cache"
    echo "  - Logs"
    echo "  - Outros dados do LM Studio"
    echo

fi

if [[ "$REMOVE_SWAP" == true ]]; then

    warn "A opção --remove-swap foi ativada."

    echo
    echo "O script poderá remover:"
    echo
    echo "  $SWAPFILE"
    echo

fi

# ------------------------------------------------------------
# Confirmação geral
# ------------------------------------------------------------

echo
read -rp "Deseja continuar? [s/N]: " RESPONSE

if [[ ! "$RESPONSE" =~ ^[Ss]$ ]]; then

    echo
    msg "Operação cancelada."

    exit 0

fi

# ------------------------------------------------------------
# Remover configuração de swappiness
# ------------------------------------------------------------

echo
echo "============================================================"
echo "REMOVENDO CONFIGURAÇÃO DE SWAPPINESS"
echo "============================================================"
echo

if [[ -f "$SYSCTL_FILE" ]]; then

    msg "Removendo:"
    echo "  $SYSCTL_FILE"

    sudo rm -f "$SYSCTL_FILE"

    sudo sysctl --system >/dev/null

    ok "Configuração de swappiness removida."

else

    msg "Arquivo de configuração não encontrado."

    echo "  $SYSCTL_FILE"

fi

# ------------------------------------------------------------
# Remover lançador do menu
# ------------------------------------------------------------

echo
echo "============================================================"
echo "REMOVENDO LANÇADOR"
echo "============================================================"
echo

if [[ -f "$DESKTOP_FILE" ]]; then

    msg "Removendo:"
    echo "  $DESKTOP_FILE"

    rm -f "$DESKTOP_FILE"

    ok "Lançador removido."

else

    msg "Lançador não encontrado."

fi

# ------------------------------------------------------------
# Atualizar banco de aplicações
# ------------------------------------------------------------

if command -v update-desktop-database >/dev/null 2>&1; then

    update-desktop-database \
        "$HOME/.local/share/applications" \
        >/dev/null 2>&1 || true

fi

# ------------------------------------------------------------
# Remover diretório ~/LMStudio
# ------------------------------------------------------------

echo
echo "============================================================"
echo "REMOVENDO DIRETÓRIO DO PROJETO"
echo "============================================================"
echo

if [[ -d "$LM_DIR" ]]; then

    echo
    echo "O seguinte diretório será removido:"
    echo
    echo "  $LM_DIR"
    echo

    echo "Esse diretório pode conter:"
    echo
    echo "  - LM Studio AppImage"
    echo "  - Scripts auxiliares"
    echo "  - Configurações criadas pelo projeto"
    echo

    read -rp "Remover $LM_DIR? [s/N]: " RESPONSE

    if [[ "$RESPONSE" =~ ^[Ss]$ ]]; then

        rm -rf -- "$LM_DIR"

        ok "Diretório $LM_DIR removido."

    else

        warn "Diretório $LM_DIR mantido."

    fi

else

    msg "Diretório $LM_DIR não encontrado."

fi

# ------------------------------------------------------------
# Remover dados completos do LM Studio
# ------------------------------------------------------------

if [[ "$FULL_REMOVE" == true ]]; then

    echo
    echo "============================================================"
    echo "REMOÇÃO DOS DADOS DO LM STUDIO"
    echo "============================================================"
    echo

    if [[ -d "$LM_DATA_DIR" ]]; then

        warn "ATENÇÃO: ESTA OPERAÇÃO É DESTRUTIVA."

        echo
        echo "O diretório abaixo será removido:"
        echo
        echo "  $LM_DATA_DIR"
        echo

        echo "Isso pode apagar:"
        echo
        echo "  - Modelos baixados"
        echo "  - Conversas"
        echo "  - Configurações"
        echo "  - Cache"
        echo "  - Logs"
        echo "  - Outros dados"
        echo

        read -rp "Digite REMOVER para confirmar: " CONFIRM

        if [[ "$CONFIRM" == "REMOVER" ]]; then

            rm -rf -- "$LM_DATA_DIR"

            ok "Dados do LM Studio removidos."

        else

            warn "Dados do LM Studio NÃO foram removidos."

        fi

    else

        msg "Diretório $LM_DATA_DIR não encontrado."

    fi

else

    echo
    echo "============================================================"
    echo "DADOS DO LM STUDIO"
    echo "============================================================"
    echo

    if [[ -d "$LM_DATA_DIR" ]]; then

        warn "O diretório de dados do LM Studio foi mantido."

        echo
        echo "Local:"
        echo
        echo "  $LM_DATA_DIR"
        echo

        echo "Isso preserva seus modelos, conversas e configurações."

        echo
        echo "Para remover posteriormente:"
        echo
        echo "  rm -rf ~/.lmstudio"
        echo

    else

        msg "Diretório ~/.lmstudio não encontrado."

    fi

fi

# ------------------------------------------------------------
# Remover swap
# ------------------------------------------------------------

if [[ "$REMOVE_SWAP" == true ]]; then

    echo
    echo "============================================================"
    echo "REMOÇÃO DO SWAP"
    echo "============================================================"
    echo

    if [[ -f "$SWAPFILE" ]]; then

        warn "ATENÇÃO: o swapfile será desativado e removido."

        echo
        echo "Arquivo:"
        echo
        echo "  $SWAPFILE"
        echo

        read -rp "Digite REMOVER para confirmar: " CONFIRM

        if [[ "$CONFIRM" == "REMOVER" ]]; then

            # Verificar se está ativo
            if swapon --show | grep -q "$SWAPFILE"; then

                msg "Desativando swap..."

                sudo swapoff "$SWAPFILE"

                ok "Swap desativado."

            else

                msg "Swapfile não está ativo."

            fi

            # Remover entrada do fstab
            if grep -qF "$SWAPFILE none swap sw 0 0" /etc/fstab; then

                msg "Removendo entrada do /etc/fstab..."

                sudo sed -i "\|^$SWAPFILE none swap sw 0 0$|d" /etc/fstab

                ok "Entrada removida do /etc/fstab."

            fi

            # Remover arquivo
            if [[ -f "$SWAPFILE" ]]; then

                sudo rm -f "$SWAPFILE"

                ok "Swapfile removido."

            fi

        else

            warn "Swapfile NÃO foi removido."

        fi

    else

        msg "Swapfile $SWAPFILE não encontrado."

    fi

else

    echo
    echo "Swapfile mantido."

    echo
    echo "Para removê-lo posteriormente, execute:"
    echo
    echo "  ./uninstall-lmstudio-minimal_u2204.sh --remove-swap"
    echo

fi

# ------------------------------------------------------------
# Resultado final
# ------------------------------------------------------------

echo
echo "============================================================"
echo "DESINSTALAÇÃO CONCLUÍDA"
echo "============================================================"
echo

ok "Processo finalizado."

echo
echo "Verifique o estado atual do swap com:"
echo
echo "  swapon --show"
echo

echo "Verifique o swappiness com:"
echo
echo "  cat /proc/sys/vm/swappiness"
echo

if [[ "$FULL_REMOVE" == false ]]; then

    echo
    echo "Os dados do LM Studio foram preservados em:"
    echo
    echo "  $LM_DATA_DIR"
    echo

fi

echo
echo "============================================================"
```
