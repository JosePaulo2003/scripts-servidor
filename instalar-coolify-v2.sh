#!/usr/bin/env bash
set -Eeuo pipefail

LOG="/var/log/instalar-coolify.log"
exec > >(tee -a "$LOG") 2>&1

erro() {
    echo
    echo "ERRO: $1"
    echo "Consulte o log em: $LOG"
    exit 1
}

aviso() {
    echo "AVISO: $1"
}

echo "========================================"
echo " Diagnóstico e instalação do Coolify"
echo "========================================"
echo "Log: $LOG"

if [ "$(id -u)" -ne 0 ]; then
    erro "execute com: sudo bash instalar-coolify-v2.sh"
fi

echo "[1/9] Identificando o sistema..."

[ -f /etc/os-release ] || erro "arquivo /etc/os-release não encontrado."
# shellcheck disable=SC1091
source /etc/os-release

case "${ID:-}" in
    ubuntu|debian)
        ;;
    *)
        aviso "Sistema detectado: ${PRETTY_NAME:-desconhecido}."
        aviso "O procedimento foi preparado para Ubuntu ou Debian."
        ;;
esac

echo "Sistema: ${PRETTY_NAME:-desconhecido}"
echo "Kernel: $(uname -r)"
echo "Arquitetura: $(uname -m)"

echo "[2/9] Verificando rede e DNS..."

ip route | grep -q '^default ' || erro "nenhuma rota padrão foi encontrada."

if ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
    aviso "O teste ICMP para 1.1.1.1 falhou. Isso pode ser bloqueio de ping."
fi

if ! getent hosts cdn.coollabs.io >/dev/null 2>&1; then
    erro "não foi possível resolver cdn.coollabs.io. Verifique o DNS da VM."
fi

echo "Rede e DNS disponíveis."

echo "[3/9] Verificando recursos..."

CPU="$(nproc)"
RAM_MB="$(awk '/MemTotal/ {printf "%.0f", $2 / 1024}' /proc/meminfo)"
DISCO_GB="$(df --output=avail -BG / | tail -1 | tr -dc '0-9')"

echo "CPU: ${CPU} núcleo(s)"
echo "RAM: ${RAM_MB} MB"
echo "Disco livre em /: ${DISCO_GB} GB"

if [ "$CPU" -lt 2 ]; then
    aviso "Menos de 2 núcleos disponíveis."
fi

if [ "$RAM_MB" -lt 1900 ]; then
    erro "menos de aproximadamente 2 GB de RAM disponíveis."
fi

if [ "$DISCO_GB" -lt 25 ]; then
    erro "menos de 25 GB livres no disco raiz."
fi

echo "[4/9] Atualizando pacotes e instalando dependências..."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get full-upgrade -y
apt-get install -y \
    curl \
    ca-certificates \
    openssh-server \
    iproute2 \
    dnsutils

echo "[5/9] Configurando SSH..."

systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh
systemctl is-active --quiet ssh || erro "o serviço SSH não iniciou."

echo "SSH ativo."

echo "[6/9] Tratando o QEMU Guest Agent como opcional..."

if dpkg-query -W -f='${Status}' qemu-guest-agent 2>/dev/null | grep -q "install ok installed"; then
    if systemctl start qemu-guest-agent >/dev/null 2>&1; then
        echo "QEMU Guest Agent iniciado."
    else
        aviso "QEMU Guest Agent não iniciou."
        aviso "Isso não impede a instalação do Coolify."
        aviso "No Proxmox, habilite VM > Options > QEMU Guest Agent para utilizá-lo."
    fi
else
    echo "QEMU Guest Agent não está instalado; continuando normalmente."
fi

echo "[7/9] Verificando portas necessárias..."

PORTAS_OCUPADAS=()

for PORTA in 80 443 8000; do
    if ss -H -lnt "( sport = :$PORTA )" 2>/dev/null | grep -q .; then
        PORTAS_OCUPADAS+=("$PORTA")
    fi
done

if [ "${#PORTAS_OCUPADAS[@]}" -gt 0 ]; then
    echo "Portas ocupadas: ${PORTAS_OCUPADAS[*]}"
    ss -lntp | grep -E ':80|:443|:8000' || true
    erro "libere as portas acima antes de instalar o Coolify."
fi

echo "Portas 80, 443 e 8000 disponíveis."

echo "[8/9] Verificando instalações conflitantes..."

if command -v snap >/dev/null 2>&1 && snap list docker >/dev/null 2>&1; then
    erro "Docker instalado via Snap detectado. Remova com: sudo snap remove docker"
fi

if command -v docker >/dev/null 2>&1; then
    echo "Docker já está instalado:"
    docker --version || true
else
    echo "Docker ainda não está instalado; o instalador oficial cuidará disso."
fi

echo "[9/9] Baixando e executando o instalador oficial..."

INSTALLER="/tmp/coolify-install.sh"

curl --fail --silent --show-error --location \
    https://cdn.coollabs.io/coolify/install.sh \
    --output "$INSTALLER"

[ -s "$INSTALLER" ] || erro "o instalador baixado está vazio."

chmod 700 "$INSTALLER"
bash "$INSTALLER"

echo
echo "========================================"
echo " Verificação final"
echo "========================================"

if command -v docker >/dev/null 2>&1; then
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
else
    aviso "O comando Docker não foi encontrado após a instalação."
fi

IP_VM="$(hostname -I | awk '{print $1}')"

echo
echo "Endereço provável do painel:"
echo "http://${IP_VM}:8000"
echo
echo "Log completo:"
echo "$LOG"
echo
echo "Crie imediatamente o primeiro usuário administrador."
