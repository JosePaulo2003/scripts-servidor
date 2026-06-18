#!/usr/bin/env bash

set -Eeuo pipefail

echo "========================================"
echo " Preparação e instalação do Coolify"
echo "========================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: execute este script com sudo:"
    echo "sudo bash instalar-coolify.sh"
    exit 1
fi

echo "[1/7] Verificando sistema operacional..."

if [ ! -f /etc/os-release ]; then
    echo "ERRO: não foi possível identificar o sistema operacional."
    exit 1
fi

source /etc/os-release
echo "Sistema detectado: ${PRETTY_NAME:-desconhecido}"

echo "[2/7] Atualizando os pacotes..."
apt update
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y

echo "[3/7] Instalando dependências..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    curl \
    ca-certificates \
    openssh-server \
    qemu-guest-agent

echo "[4/7] Ativando serviços necessários..."
systemctl enable --now ssh
systemctl enable --now qemu-guest-agent

echo "[5/7] Verificando portas..."

PORTAS_OCUPADAS=""

for PORTA in 80 443 8000; do
    if ss -lnt | awk '{print $4}' | grep -Eq "[:.]${PORTA}$"; then
        PORTAS_OCUPADAS="${PORTAS_OCUPADAS} ${PORTA}"
    fi
done

if [ -n "$PORTAS_OCUPADAS" ]; then
    echo "ERRO: as seguintes portas estão ocupadas:${PORTAS_OCUPADAS}"
    ss -lntp | grep -E ':80|:443|:8000' || true
    exit 1
fi

echo "Portas 80, 443 e 8000 disponíveis."

echo "[6/7] Verificando Docker via Snap..."

if command -v snap >/dev/null 2>&1 && snap list docker >/dev/null 2>&1; then
    echo "ERRO: Docker instalado via Snap foi detectado."
    echo "Remova-o com:"
    echo "sudo snap remove docker"
    exit 1
fi

echo "[7/7] Baixando e executando o instalador oficial..."

curl -fsSL https://cdn.coollabs.io/coolify/install.sh \
    -o /tmp/coolify-install.sh

chmod +x /tmp/coolify-install.sh
bash /tmp/coolify-install.sh

echo
echo "========================================"
echo " Instalação concluída"
echo "========================================"

echo
echo "Containers encontrados:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true

IP_VM="$(hostname -I | awk '{print $1}')"

echo
echo "Acesse o painel pelo endereço:"
echo "http://${IP_VM}:8000"
echo
echo "Crie imediatamente o primeiro usuário administrador."
