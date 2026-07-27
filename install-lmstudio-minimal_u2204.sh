#!/usr/bin/env bash

# ============================================================
# LM Studio Minimal Setup
# Ubuntu 22.04
# Otimizado para notebooks com pouca RAM
#
# Hardware alvo:
# - Intel Core i3 / i5 de baixo consumo
# - 8 GB RAM
# - GPU integrada Intel
#
# Objetivo:
# - Mínimo de dependências
# - Mínimo consumo de RAM
# - Configuração conservadora
# - Sem serviços em background
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
CONFIG_DIR="$LM_DIR/config"
TOOLS_DIR="$LM_DIR/tools"

SWAPFILE="/swapfile"
SWAP_SIZE_GB=8

SYSCTL_FILE="/etc/sysctl.d/99-lmstudio-minimal.conf"

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

pause() {
    read -rp "Pressione ENTER para continuar..."
}

# ------------------------------------------------------------
# Verificar root
# ------------------------------------------------------------

if [[ "$EUID" -eq 0 ]]; then
    error "Não execute este script como root."
    echo
    echo "Execute como seu usuário normal:"
    echo
    echo "  ./install-lmstudio-minimal.sh"
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
# Verificar Ubuntu
# ------------------------------------------------------------

if [[ ! -f /etc/os-release ]]; then
    error "Não foi possível identificar o sistema operacional."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    warn "Este script foi desenvolvido para Ubuntu."
    warn "Sistema detectado: ${PRETTY_NAME:-desconhecido}"

    read -rp "Deseja continuar mesmo assim? [s/N]: " RESP

    if [[ ! "$RESP" =~ ^[Ss]$ ]]; then
        exit 0
    fi
fi

if [[ "${VERSION_ID:-}" != "22.04" ]]; then
    warn "Este script foi projetado para Ubuntu 22.04."
    warn "Versão detectada: ${VERSION_ID:-desconhecida}"

    read -rp "Deseja continuar? [s/N]: " RESP

    if [[ ! "$RESP" =~ ^[Ss]$ ]]; then
        exit 0
    fi
fi

# ------------------------------------------------------------
# Cabeçalho
# ------------------------------------------------------------

clear

echo
echo "============================================================"
echo "       LM STUDIO - CONFIGURAÇÃO MÍNIMA"
echo "============================================================"
echo
echo "Sistema : ${PRETTY_NAME:-desconhecido}"
echo "Kernel  : $(uname -r)"
echo

# ------------------------------------------------------------
# Detectar CPU
# ------------------------------------------------------------

CPU_MODEL=$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo)

# Fallback caso não seja possível obter o modelo
if [[ -z "$CPU_MODEL" ]]; then
    CPU_MODEL="Não identificado"
fi

CPU_CORES=$(nproc)

echo "CPU     : $CPU_MODEL"
echo "Threads : $CPU_CORES"

# ------------------------------------------------------------
# Detectar RAM
# ------------------------------------------------------------

RAM_MB=$(awk '/^MemTotal:/ {print int($2 / 1024)}' /proc/meminfo)
RAM_GB=$((RAM_MB / 1024))

echo "RAM     : aproximadamente ${RAM_GB} GB"

# ------------------------------------------------------------
# Detectar GPU
# ------------------------------------------------------------

echo
echo "GPU:"
lspci | grep -Ei "VGA|3D|Display" || echo "  Não identificada"

echo

# ------------------------------------------------------------
# Atualizar índices
# ------------------------------------------------------------

msg "Atualizando índice dos pacotes..."

sudo apt update

ok "Índice atualizado."

# ------------------------------------------------------------
# Instalar dependências mínimas
# ------------------------------------------------------------

msg "Instalando ferramentas básicas..."

sudo apt install -y \
    curl \
    wget \
    pciutils \
    procps \
    util-linux

ok "Dependências instaladas."

# ------------------------------------------------------------
# Criar diretórios
# ------------------------------------------------------------

msg "Criando estrutura do LM Studio..."

mkdir -p "$LM_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$TOOLS_DIR"

ok "Diretórios criados em: $LM_DIR"

# ------------------------------------------------------------
# Verificar SWAP
# ------------------------------------------------------------

echo
echo "============================================================"
echo "VERIFICAÇÃO DE SWAP"
echo "============================================================"

SWAP_TOTAL_KB=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
SWAP_TOTAL_GB=$((SWAP_TOTAL_KB / 1024 / 1024))

echo
echo "Swap atual: ${SWAP_TOTAL_GB} GB"
echo

if (( SWAP_TOTAL_GB >= 4 )); then

    ok "Já existe swap suficiente."

else

    warn "O sistema possui menos de 4 GB de swap."

    if swapon --show | grep -q "$SWAPFILE"; then

        warn "O $SWAPFILE já está ativo."

    elif [[ -f "$SWAPFILE" ]]; then

        warn "$SWAPFILE existe, mas não está ativo."

        read -rp "Deseja ativá-lo? [S/n]: " RESP

        if [[ ! "$RESP" =~ ^[Nn]$ ]]; then

            sudo chmod 600 "$SWAPFILE"

            sudo swapon "$SWAPFILE"

            ok "Swap ativado."

        fi

    else

        echo
        echo "Será criado:"
        echo
        echo "  Arquivo : $SWAPFILE"
        echo "  Tamanho : ${SWAP_SIZE_GB} GB"
        echo
        echo "Isso NÃO aumenta a velocidade do LM Studio."
        echo "Serve apenas como proteção contra falta de memória."
        echo

        read -rp "Criar swap de ${SWAP_SIZE_GB} GB? [S/n]: " RESP

        if [[ ! "$RESP" =~ ^[Nn]$ ]]; then

            msg "Criando swap..."

            sudo fallocate -l "${SWAP_SIZE_GB}G" "$SWAPFILE"

            sudo chmod 600 "$SWAPFILE"

            sudo mkswap "$SWAPFILE"

            sudo swapon "$SWAPFILE"

            if ! grep -qF "$SWAPFILE none swap sw 0 0" /etc/fstab; then
                echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
            fi

            ok "Swap de ${SWAP_SIZE_GB} GB criado."

        else

            warn "Swap não foi alterado."

        fi
    fi
fi

# ------------------------------------------------------------
# Configurar swappiness
# ------------------------------------------------------------

echo
echo "============================================================"
echo "CONFIGURAÇÃO DE MEMÓRIA"
echo "============================================================"

msg "Configurando vm.swappiness=10..."

echo "vm.swappiness=10" | sudo tee "$SYSCTL_FILE" >/dev/null

sudo sysctl --system >/dev/null

CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)

ok "Swappiness atual: $CURRENT_SWAPPINESS"

# ------------------------------------------------------------
# Criar arquivo de configuração recomendada
# ------------------------------------------------------------

msg "Criando configuração recomendada..."

cat > "$CONFIG_DIR/recomendacoes.txt" <<'EOF'
============================================================
LM STUDIO - CONFIGURAÇÃO MÍNIMA RECOMENDADA
============================================================

Hardware alvo:
- Intel Core i3-1005G1
- 2 núcleos / 4 threads
- 8 GB RAM
- GPU integrada Intel

CONFIGURAÇÃO RECOMENDADA
------------------------------------------------------------

Modelo:
    1B a 2B

Formato:
    GGUF

Quantização:
    Q4_K_M

Context Length:
    2048

CPU Threads:
    2

GPU Offload:
    Auto

GPU Layers:
    Auto

============================================================
OBSERVAÇÕES
============================================================

1. Comece com um modelo 1B ou 2B.

2. Prefira Q4_K_M para equilibrar:
   - memória
   - velocidade
   - qualidade

3. Não comece com modelos 7B/8B usando apenas 8 GB RAM.

4. Não aumente o contexto acima de 2048 inicialmente.

5. Teste primeiro GPU Offload em Auto.

6. Se o sistema ficar lento, teste CPU.

7. Evite deixar outros programas pesados abertos.

8. Evite navegador com muitas abas durante a inferência.

============================================================
EOF

ok "Arquivo criado:"
echo "$CONFIG_DIR/recomendacoes.txt"

# ------------------------------------------------------------
# Criar script de diagnóstico
# ------------------------------------------------------------

msg "Criando ferramenta de diagnóstico..."

cat > "$TOOLS_DIR/lmstudio-info.sh" <<'EOF'
#!/usr/bin/env bash

echo
echo "============================================================"
echo "LM STUDIO - DIAGNÓSTICO DO SISTEMA"
echo "============================================================"
echo

echo "SISTEMA"
echo "------------------------------------------------------------"
cat /etc/os-release | grep -E 'PRETTY_NAME|VERSION_ID'
echo "Kernel: $(uname -r)"

echo
echo "CPU"
echo "------------------------------------------------------------"
lscpu | grep -E 'Model name|CPU\(s\)|Core|Thread' | head -10

echo
echo "MEMÓRIA"
echo "------------------------------------------------------------"
free -h

echo
echo "SWAP"
echo "------------------------------------------------------------"
swapon --show

echo
echo "SWAPPINESS"
echo "------------------------------------------------------------"
cat /proc/sys/vm/swappiness

echo
echo "GPU"
echo "------------------------------------------------------------"
lspci | grep -Ei "VGA|3D|Display" || echo "GPU não identificada"

echo
echo "USO ATUAL"
echo "------------------------------------------------------------"
uptime

echo
echo "PROCESSOS COM MAIOR CONSUMO DE RAM"
echo "------------------------------------------------------------"

ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -10

echo
echo "============================================================"
EOF

chmod +x "$TOOLS_DIR/lmstudio-info.sh"

ok "Diagnóstico criado."

# ------------------------------------------------------------
# Criar script de inicialização
# ------------------------------------------------------------

msg "Criando script de inicialização..."

cat > "$TOOLS_DIR/lmstudio-start.sh" <<'EOF'
#!/usr/bin/env bash

LM_DIR="$HOME/LMStudio"

APPIMAGE=$(find "$LM_DIR" -maxdepth 1 -type f \
    -iname "*.AppImage" \
    -print -quit)

if [[ -z "$APPIMAGE" ]]; then

    echo
    echo "LM Studio AppImage não encontrado."
    echo
    echo "Baixe o AppImage oficial do LM Studio e coloque-o em:"
    echo
    echo "  $LM_DIR"
    echo
    exit 1

fi

chmod +x "$APPIMAGE"

exec "$APPIMAGE"
EOF

chmod +x "$TOOLS_DIR/lmstudio-start.sh"

ok "Script de inicialização criado."

# ------------------------------------------------------------
# Criar arquivo desktop
# ------------------------------------------------------------

msg "Criando lançador no menu..."

mkdir -p "$HOME/.local/share/applications"

cat > "$HOME/.local/share/applications/lmstudio-minimal.desktop" <<EOF
[Desktop Entry]
Name=LM Studio
Comment=Local AI - Minimal Configuration
Exec=$TOOLS_DIR/lmstudio-start.sh
Icon=application-x-executable
Terminal=false
Type=Application
Categories=Development;Utility;
StartupNotify=true
EOF

chmod +x "$HOME/.local/share/applications/lmstudio-minimal.desktop"

ok "Lançador criado."

# ------------------------------------------------------------
# Criar script de remoção da configuração
# ------------------------------------------------------------

cat > "$TOOLS_DIR/remove-lmstudio-tuning.sh" <<'EOF'
#!/usr/bin/env bash

echo "Este script remove apenas as configurações feitas"
echo "pelo install-lmstudio-minimal.sh."
echo

sudo rm -f /etc/sysctl.d/99-lmstudio-minimal.conf

sudo sysctl --system >/dev/null

echo
echo "Configuração de swappiness removida."
echo
echo "ATENÇÃO:"
echo "O swapfile /swapfile NÃO foi removido automaticamente."
echo "Isso é proposital para evitar perda acidental de dados."
echo
EOF

chmod +x "$TOOLS_DIR/remove-lmstudio-tuning.sh"

# ------------------------------------------------------------
# Resultado final
# ------------------------------------------------------------

echo
echo "============================================================"
echo "CONFIGURAÇÃO CONCLUÍDA"
echo "============================================================"
echo

ok "LM Studio minimal preparado."

echo
echo "Diretório:"
echo "  $LM_DIR"

echo
echo "Configuração:"
echo "  $CONFIG_DIR/recomendacoes.txt"

echo
echo "Diagnóstico:"
echo "  $TOOLS_DIR/lmstudio-info.sh"

echo
echo "Iniciar LM Studio:"
echo "  $TOOLS_DIR/lmstudio-start.sh"

echo
echo "============================================================"
echo "PRÓXIMO PASSO"
echo "============================================================"
echo

echo "Baixe o LM Studio para Linux no site oficial."
echo
echo "Depois coloque o arquivo .AppImage em:"
echo
echo "  $LM_DIR"
echo
echo "Então execute:"
echo
echo "  $TOOLS_DIR/lmstudio-start.sh"
echo

echo "Configuração inicial recomendada:"
echo
echo "  Modelo          : 1B–2B"
echo "  Quantização     : Q4_K_M"
echo "  Context Length  : 2048"
echo "  CPU Threads     : 2"
echo "  GPU Offload     : Auto"
echo "  GPU Layers      : Auto"
echo

echo "============================================================"
