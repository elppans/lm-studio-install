#!/usr/bin/env bash
# shellcheck disable=SC2034

#
# LM Studio - Automatic Hardware Configuration (AHC)
# Multi-distro installer/configurator
#
# Supported families:
#   Debian/Ubuntu and derivatives
#   Fedora/RHEL and derivatives
#   openSUSE
#   Arch/Manjaro and derivatives
#
# Design goals:
#   - Never blindly install the "fuse" package on modern systems.
#   - Never accept package-manager transactions that remove existing packages.
#   - Detect hardware and calculate conservative Minimum/Recommended profiles.
#   - Use LM Studio's own --estimate-only when a model is available.
#
# License: MIT
#

set -u
set -o pipefail


SCRIPT_NAME="$(basename "$0")"
LM_MODEL_DEFAULT="qwen/qwen3-1.7b"
LM_CONTEXT_DEFAULT=2048
LM_PARALLEL_DEFAULT=1
LM_REASONING_DEFAULT="off"
LM_APPIMAGE="${LM_APPIMAGE:-$HOME/.local/opt/lm-studio/LM-Studio.AppImage}"
LMS=""

# ---------- UI ----------
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'

ok()   { printf "${C_GREEN}[ OK ]${C_RESET} %s\n" "$*"; }
info() { printf "${C_CYAN}[INFO]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

pause() {
    printf "\nPressione ENTER para continuar..."
    read -r _
}

# ---------- OS ----------
detect_os() {
    OS_ID="unknown"
    OS_LIKE=""
    OS_NAME="Unknown"
    OS_VERSION=""

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
        OS_NAME="${PRETTY_NAME:-$NAME}"
        OS_VERSION="${VERSION_ID:-}"
    fi

    case "$OS_ID $OS_LIKE" in
        *debian*|*ubuntu*|*linuxmint*|*pop*|*elementary*|*zorin*)
            DISTRO_FAMILY="debian" ;;
        *fedora*|*rhel*|*centos*|*rocky*|*almalinux*)
            DISTRO_FAMILY="fedora" ;;
        *suse*|*opensuse*)
            DISTRO_FAMILY="suse" ;;
        *arch*|*manjaro*|*endeavouros*|*garuda*)
            DISTRO_FAMILY="arch" ;;
        *)
            DISTRO_FAMILY="unknown" ;;
    esac
}

# ---------- Hardware ----------
get_ram_kib() {
    awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null
}

get_available_kib() {
    awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null
}

human_gib() {
    awk -v kib="${1:-0}" 'BEGIN { printf "%.1f GiB", kib/1024/1024 }'
}

detect_hardware() {
    ARCH="$(uname -m)"
    KERNEL="$(uname -r)"
    CPU="$(lscpu 2>/dev/null | awk -F: '/Architecture:/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
    [[ -n "$CPU" ]] || CPU="$ARCH"

    THREADS="$(nproc 2>/dev/null || echo 1)"
    RAM_KIB="$(get_ram_kib)"
    AVAIL_KIB="$(get_available_kib)"
    RAM_GIB="$(human_gib "$RAM_KIB")"
    AVAIL_GIB="$(human_gib "$AVAIL_KIB")"

    AVX="no"
    AVX2="no"
    if grep -qw avx /proc/cpuinfo 2>/dev/null; then AVX="yes"; fi
    if grep -qw avx2 /proc/cpuinfo 2>/dev/null; then AVX2="yes"; fi

    SWAP_TOTAL_KIB="$(awk '/SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null)"
    SWAP_FREE_KIB="$(awk '/SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null)"
    SWAP_USED_KIB=$(( ${SWAP_TOTAL_KIB:-0} - ${SWAP_FREE_KIB:-0} ))
    SWAP_TOTAL_GIB="$(human_gib "${SWAP_TOTAL_KIB:-0}")"
    SWAP_USED_GIB="$(human_gib "${SWAP_USED_KIB:-0}")"

    GPU="Não detectada"
    if have lspci; then
        GPU="$(lspci 2>/dev/null | awk '/VGA compatible controller|3D controller|Display controller/ {print; exit}')"
        [[ -n "$GPU" ]] || GPU="Não detectada"
    fi

    VULKAN="no"
    VULKAN_DETAIL="não detectado"
    if have vulkaninfo; then
        if vulkaninfo --summary >/dev/null 2>&1; then
            VULKAN="yes"
            VULKAN_DETAIL="$(vulkaninfo --summary 2>/dev/null | awk -F: '/deviceName/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
            [[ -n "$VULKAN_DETAIL" ]] || VULKAN_DETAIL="disponível"
        fi
    elif [[ -e /usr/share/vulkan/icd.d || -e /etc/vulkan/icd.d ]]; then
        # Do not claim that Vulkan works merely because ICD files exist.
        VULKAN_DETAIL="ICD presente; vulkaninfo não instalado"
    fi

    FUSE_STATUS="não verificado"
    if [[ -e /dev/fuse ]]; then
        if have fusermount3 || have fusermount; then
            FUSE_STATUS="disponível"
        else
            FUSE_STATUS="/dev/fuse presente; utilitário não encontrado"
        fi
    else
        FUSE_STATUS="não disponível"
    fi
}

show_banner() {
    printf "\n"
    printf "%s\n" "============================================================"
    printf "%s\n" " LM STUDIO - AUTOMATIC HARDWARE CONFIGURATION (AHC)"
    printf "%s\n" "============================================================"
    printf " Sistema       : %s\n" "$OS_NAME"
    printf " Família       : %s\n" "$DISTRO_FAMILY"
    printf " Arquitetura   : %s\n" "$ARCH"
    printf " Kernel        : %s\n" "$KERNEL"
    printf " CPU           : %s\n" "$CPU"
    printf " Threads       : %s\n" "$THREADS"
    printf " AVX / AVX2    : %s / %s\n" "$AVX" "$AVX2"
    printf " RAM           : %s\n" "$RAM_GIB"
    printf " RAM disponível: %s\n" "$AVAIL_GIB"
    printf " Swap          : %s / %s usada\n" "$SWAP_USED_GIB" "$SWAP_TOTAL_GIB"
    printf " GPU           : %s\n" "$GPU"
    printf " Vulkan        : %s\n" "$VULKAN"
    printf " FUSE          : %s\n" "$FUSE_STATUS"
    printf "%s\n" "============================================================"
}

# ---------- Package manager ----------
pkg_manager() {
    case "$DISTRO_FAMILY" in
        debian) echo "apt" ;;
        fedora) echo "dnf" ;;
        suse) echo "zypper" ;;
        arch) echo "pacman" ;;
        *) echo "" ;;
    esac
}

pkg_installed() {
    local p="$1"
    case "$DISTRO_FAMILY" in
        debian) dpkg-query -W -f='${Status}\n' "$p" 2>/dev/null | grep -q '^install ok installed$' ;;
        fedora) rpm -q "$p" >/dev/null 2>&1 ;;
        suse) rpm -q "$p" >/dev/null 2>&1 ;;
        arch) pacman -Q "$p" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

pkg_available() {
    local p="$1"
    case "$DISTRO_FAMILY" in
        debian) apt-cache show "$p" >/dev/null 2>&1 ;;
        fedora) dnf info "$p" >/dev/null 2>&1 ;;
        suse) zypper --non-interactive info "$p" >/dev/null 2>&1 ;;
        arch) pacman -Si "$p" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

safe_install() {
    local packages=("$@")
    [[ ${#packages[@]} -gt 0 ]] || return 0

    info "Dependências solicitadas: ${packages[*]}"

    case "$DISTRO_FAMILY" in
        debian)
            sudo apt-get update
            # --no-remove is deliberate: the transaction must fail instead of
            # removing an existing package to resolve a conflict.
            sudo apt-get --no-remove install -y "${packages[@]}" || \
                die "APT recusou a operação sem remoções. Nenhuma instalação destrutiva será tentada."
            ;;
        fedora)
            sudo dnf install -y "${packages[@]}" || \
                die "DNF não conseguiu instalar as dependências."
            ;;
        suse)
            sudo zypper --non-interactive install "${packages[@]}" || \
                die "Zypper não conseguiu instalar as dependências."
            ;;
        arch)
            sudo pacman -Sy --needed --noconfirm "${packages[@]}" || \
                die "Pacman não conseguiu instalar as dependências."
            ;;
        *) die "Distribuição não suportada para instalação automática de pacotes." ;;
    esac
}

ensure_dependencies() {
    local missing=()
    local p

    # These are genuinely useful to AHC. We intentionally do NOT install the
    # generic "fuse" package.
    case "$DISTRO_FAMILY" in
        debian)
            for p in ca-certificates curl pciutils file; do
                pkg_installed "$p" || missing+=("$p")
            done

            # AppImages commonly need FUSE 2 libraries. Prefer the distro's
            # available compatibility library; never replace fuse3 with fuse.
            if ! pkg_installed libfuse2 && ! pkg_installed libfuse2t64; then
                if pkg_available libfuse2t64; then
                    missing+=("libfuse2t64")
                elif pkg_available libfuse2; then
                    missing+=("libfuse2")
                fi
            fi
            ;;
        fedora)
            for p in ca-certificates curl pciutils file; do
                pkg_installed "$p" || missing+=("$p")
            done
            if ! pkg_installed fuse-libs && pkg_available fuse-libs; then
                missing+=("fuse-libs")
            fi
            ;;
        suse)
            for p in ca-certificates curl pciutils file; do
                pkg_installed "$p" || missing+=("$p")
            done
            if ! pkg_installed fuse-libs && pkg_available fuse-libs; then
                missing+=("fuse-libs")
            fi
            ;;
        arch)
            for p in ca-certificates curl pciutils file; do
                pkg_installed "$p" || missing+=("$p")
            done
            if ! pkg_installed fuse2 && ! pkg_installed fuse3; then
                if pkg_available fuse2; then
                    missing+=("fuse2")
                elif pkg_available fuse3; then
                    missing+=("fuse3")
                fi
            fi
            ;;
        *)
            warn "Família de distribuição não reconhecida; dependências serão apenas verificadas."
            ;;
    esac

    if [[ ${#missing[@]} -gt 0 ]]; then
        info "Dependências ausentes: ${missing[*]}"
        safe_install "${missing[@]}"
    else
        ok "Dependências básicas já estão disponíveis."
    fi

    # Re-detect FUSE after package installation.
    detect_hardware
    if [[ "$FUSE_STATUS" == "não disponível" ]]; then
        warn "FUSE não está disponível. O AHC não instalará o pacote genérico 'fuse' automaticamente."
        warn "Se o AppImage reclamar de FUSE, execute o diagnóstico exibido pelo script."
    else
        ok "Suporte FUSE detectado: $FUSE_STATUS"
    fi
}

# ---------- LM Studio / lms ----------
find_lms() {
    if have lms; then
        LMS="$(command -v lms)"
        return 0
    fi

    if [[ -x "$HOME/.lmstudio/bin/lms" ]]; then
        LMS="$HOME/.lmstudio/bin/lms"
        return 0
    fi

    # Some installations may expose it elsewhere in ~/.lmstudio.
    local found
    found="$(find "$HOME/.lmstudio" -type f -name lms -perm -u+x 2>/dev/null | head -n1)"
    if [[ -n "$found" ]]; then
        LMS="$found"
        return 0
    fi

    return 1
}

ensure_lms() {
    if find_lms; then
        ok "LM Studio CLI encontrado: $LMS"
        "$LMS" --version 2>/dev/null || true
        return 0
    fi

    if [[ -x "$LM_APPIMAGE" ]]; then
        info "LM Studio AppImage encontrado em: $LM_APPIMAGE"
        warn "O CLI 'lms' ainda não está disponível."
        warn "Abra o LM Studio pelo menos uma vez e inicialize/instale o CLI conforme a versão instalada."
        return 1
    fi

    warn "LM Studio/CLI não foi encontrado."
    warn "A página oficial de download do LM Studio deve ser usada para obter o AppImage."
    return 1
}

# ---------- Profiles ----------
# Conservative heuristics. These are starting points, not guarantees.
calculate_profiles() {
    local ram_gib_int=$(( RAM_KIB / 1024 / 1024 ))
    local avail_gib_int=$(( AVAIL_KIB / 1024 / 1024 ))

    MIN_MODEL="$LM_MODEL_DEFAULT"
    REC_MODEL="$LM_MODEL_DEFAULT"
    MIN_CONTEXT=2048
    REC_CONTEXT=2048
    MIN_PARALLEL=1
    REC_PARALLEL=1
    MIN_REASONING="off"
    REC_REASONING="on"

    # 8 GiB machines: stay conservative. 16 GiB: allow a larger baseline.
    if (( ram_gib_int >= 16 )); then
        REC_MODEL="qwen/qwen3-4b"
        REC_CONTEXT=4096
    elif (( ram_gib_int >= 12 )); then
        REC_MODEL="qwen/qwen3-4b"
        REC_CONTEXT=2048
    elif (( ram_gib_int >= 8 )); then
        REC_MODEL="qwen/qwen3-4b"
        REC_CONTEXT=2048
    fi

    # If currently available memory is very low, don't recommend increasing
    # model/context merely because total RAM is large.
    if (( avail_gib_int < 2 )); then
        REC_MODEL="$LM_MODEL_DEFAULT"
        REC_CONTEXT=2048
        REC_REASONING="off"
    fi

    # Without AVX2 on x86_64, keep the recommendation conservative.
    if [[ "$ARCH" == "x86_64" && "$AVX2" != "yes" ]]; then
        REC_MODEL="$LM_MODEL_DEFAULT"
        REC_CONTEXT=2048
        REC_REASONING="off"
    fi
}

show_profiles() {
    printf "\n"
    printf "%s\n" "Perfis calculados:"
    printf "\n"
    printf "  [1] MÍNIMO\n"
    printf "      Modelo:   %s\n" "$MIN_MODEL"
    printf "      Contexto: %s\n" "$MIN_CONTEXT"
    printf "      Parallel: %s\n" "$MIN_PARALLEL"
    printf "      GPU:      Auto\n"
    printf "      Reasoning: OFF\n"
    printf "\n"
    printf "  [2] RECOMENDADO\n"
    printf "      Modelo:   %s\n" "$REC_MODEL"
    printf "      Contexto: %s\n" "$REC_CONTEXT"
    printf "      Parallel: %s\n" "$REC_PARALLEL"
    printf "      GPU:      Auto\n"
    printf "      Reasoning: %s\n" "${REC_REASONING^^}"
    printf "\n"
    printf "  [3] PERSONALIZADO\n"
    printf "      Escolha manualmente modelo/contexto/parallel/reasoning.\n"
    printf "\n"
}

choose_profile() {
    local choice
    read -r -p "Escolha [1-3] [2]: " choice
    choice="${choice:-2}"

    case "$choice" in
        1)
            MODEL="$MIN_MODEL"
            CONTEXT="$MIN_CONTEXT"
            PARALLEL="$MIN_PARALLEL"
            REASONING="$MIN_REASONING"
            ;;
        2)
            MODEL="$REC_MODEL"
            CONTEXT="$REC_CONTEXT"
            PARALLEL="$REC_PARALLEL"
            REASONING="$REC_REASONING"
            ;;
        3)
            read -r -p "Modelo [$REC_MODEL]: " MODEL
            MODEL="${MODEL:-$REC_MODEL}"
            read -r -p "Contexto [$REC_CONTEXT]: " CONTEXT
            CONTEXT="${CONTEXT:-$REC_CONTEXT}"
            read -r -p "Parallel [$REC_PARALLEL]: " PARALLEL
            PARALLEL="${PARALLEL:-$REC_PARALLEL}"
            read -r -p "Reasoning (on/off) [$REC_REASONING]: " REASONING
            REASONING="${REASONING:-$REC_REASONING}"
            ;;
        *)
            warn "Opção inválida; usando RECOMENDADO."
            MODEL="$REC_MODEL"
            CONTEXT="$REC_CONTEXT"
            PARALLEL="$REC_PARALLEL"
            REASONING="$REC_REASONING"
            ;;
    esac

    [[ "$CONTEXT" =~ ^[0-9]+$ ]] || die "Contexto inválido."
    [[ "$PARALLEL" =~ ^[0-9]+$ ]] || die "Parallel inválido."
    [[ "$REASONING" == "on" || "$REASONING" == "off" ]] || die "Reasoning deve ser on ou off."

    info "Perfil selecionado: $MODEL | Contexto: $CONTEXT | Parallel: $PARALLEL | Reasoning: $REASONING"
}

# ---------- Model management ----------
model_exists() {
    "$LMS" ls 2>/dev/null | grep -Fq "$MODEL"
}

download_model() {
    local answer
    read -r -p "Baixar/configurar $MODEL Q4_K_M agora? [S/n] " answer
    answer="${answer:-S}"

    case "$answer" in
        [sS][iI][mM]|[sS]|"")
            info "Baixando/selecionando modelo GGUF..."
            # --select intentionally lets the user choose another quantization.
            "$LMS" get "$MODEL" --gguf --select || die "Falha ao baixar/selecionar o modelo."
            ;;
        *)
            warn "Download ignorado pelo usuário."
            ;;
    esac
}

estimate_model() {
    info "Estimando consumo com contexto $CONTEXT..."
    if "$LMS" load "$MODEL" --context-length "$CONTEXT" --parallel "$PARALLEL" --estimate-only; then
        ok "Estimativa concluída pelo LM Studio."
    else
        warn "Não foi possível estimar o modelo. Verifique se ele está baixado e se o runtime está funcional."
        return 1
    fi
}

load_model() {
    local answer
    read -r -p "Carregar o modelo agora? [S/n] " answer
    answer="${answer:-S}"

    case "$answer" in
        [sS][iI][mM]|[sS]|"")
            "$LMS" load "$MODEL" \
                --context-length "$CONTEXT" \
                --parallel "$PARALLEL" \
                -y || die "Falha ao carregar o modelo."

            ok "Modelo carregado."
            ;;
        *)
            info "Carregamento ignorado pelo usuário."
            ;;
    esac
}

quick_test() {
    local answer
    read -r -p "Executar teste rápido de chat? [S/n] " answer
    answer="${answer:-S}"

    case "$answer" in
        [sS][iI][mM]|[sS]|"")
            printf "\n[INFO] Teste rápido:\n"
            "$LMS" chat "$MODEL" \
                --dont-fetch-catalog \
                --stats \
                --reasoning "$REASONING" \
                -p "Explique em uma frase o que é Linux." || \
                warn "O teste de chat retornou erro."
            ;;
        *) info "Teste ignorado pelo usuário." ;;
    esac
}

# ---------- Diagnostics ----------
show_runtime() {
    if "$LMS" runtime survey >/tmp/lmstudio-ahc-runtime.$$ 2>&1; then
        printf "\n[INFO] Runtime / hardware detectado pelo LM Studio:\n"
        cat /tmp/lmstudio-ahc-runtime.$$
    else
        warn "Não foi possível executar 'lms runtime survey'."
    fi
    rm -f /tmp/lmstudio-ahc-runtime.$$
}

show_swap_warning() {
    if (( SWAP_TOTAL_KIB > 0 )); then
        local pct=$(( SWAP_USED_KIB * 100 / SWAP_TOTAL_KIB ))
        if (( pct >= 80 )); then
            warn "Swap está ${pct}% utilizada. Feche aplicativos desnecessários antes de carregar modelos."
        fi
    fi

    if (( AVAIL_KIB < 1024 * 1024 )); then
        warn "RAM disponível está abaixo de 1 GiB. Evite modelos maiores até liberar memória."
    fi
}

main() {
    detect_os
    detect_hardware
    show_banner

    [[ "$ARCH" == "x86_64" || "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] || \
        warn "Arquitetura $ARCH pode não ser suportada pela versão Linux do LM Studio."

    if [[ "$ARCH" == "x86_64" && "$AVX2" != "yes" ]]; then
        warn "CPU x86_64 sem AVX2 detectado. A versão Linux do LM Studio normalmente usa AVX2."
    fi

    show_swap_warning

    if [[ "$DISTRO_FAMILY" == "unknown" ]]; then
        die "Distribuição não suportada automaticamente: $OS_NAME"
    fi

    ensure_dependencies

    if ! ensure_lms; then
        printf "\n"
        warn "O AHC pode continuar somente com diagnóstico de hardware, mas não pode configurar modelos sem o CLI."
        exit 2
    fi

    if "$LMS" ls >/dev/null 2>&1; then
        printf "\n[INFO] Modelos instalados:\n"
        "$LMS" ls
    fi

    calculate_profiles
    show_profiles
    choose_profile

    if ! model_exists; then
        download_model
    else
        ok "Modelo $MODEL já está instalado."
    fi

    if ! model_exists; then
        warn "Modelo $MODEL não aparece em 'lms ls'."
        warn "A configuração do modelo foi interrompida para evitar carregar algo inexistente."
        exit 3
    fi

    estimate_model
    load_model
    quick_test

    printf "\n"
    ok "AHC concluído."
    printf "LM Studio AppImage: %s\n" "$LM_APPIMAGE"
    printf "CLI:                 %s\n" "$LMS"
    printf "Modelo:              %s\n" "$MODEL"
    printf "Contexto:             %s\n" "$CONTEXT"
    printf "Parallel:             %s\n" "$PARALLEL"
    printf "Reasoning:            %s\n" "$REASONING"
}

main "$@"
