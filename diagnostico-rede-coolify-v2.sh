#!/usr/bin/env bash
set -u

DATA="$(date +%Y%m%d-%H%M%S)"
ARQUIVO="/tmp/diagnostico-rede-coolify-v2-${DATA}.txt"

exec > >(tee "$ARQUIVO") 2>&1

secao() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

comando() {
    echo
    echo "+ $*"
    "$@" 2>&1 || true
}

secao "DIAGNÓSTICO COOLIFY V2"
echo "Data: $(date)"
echo "Arquivo: $ARQUIVO"

secao "SISTEMA"
comando hostnamectl
comando uname -a
comando cat /etc/os-release
comando uptime
comando nproc
comando free -h
comando df -h /

secao "INTERFACES E ROTAS"
comando ip -br address
comando ip route
comando ip rule
comando ip link show

secao "DNS"
comando cat /etc/resolv.conf
comando resolvectl status
comando getent ahosts cdn.coollabs.io
comando getent ahosts github.com
comando getent ahosts download.docker.com

secao "GATEWAY"
GATEWAY="$(ip route | awk '/^default/ {print $3; exit}')"
INTERFACE="$(ip route | awk '/^default/ {print $5; exit}')"

echo "Gateway detectado: ${GATEWAY:-não encontrado}"
echo "Interface detectada: ${INTERFACE:-não encontrada}"

if [ -n "${GATEWAY:-}" ]; then
    comando ping -c 6 -W 3 "$GATEWAY"
fi

secao "CONECTIVIDADE IPv4"
comando ping -4 -c 10 -W 3 1.1.1.1
comando ping -4 -c 10 -W 3 8.8.8.8
comando curl -4 -I -v --connect-timeout 20 --max-time 30 https://github.com
comando curl -4 -I -v --connect-timeout 20 --max-time 30 https://download.docker.com
comando curl -4 -I -v --connect-timeout 20 --max-time 30 https://cdn.coollabs.io
comando curl -4 -I -v --connect-timeout 20 --max-time 30 https://cdn.coollabs.io/coolify/install.sh

secao "CONECTIVIDADE IPv6"
comando ip -6 route
comando ping -6 -c 4 -W 3 2606:4700:4700::1111
comando curl -6 -I -v --connect-timeout 10 --max-time 20 https://cdn.coollabs.io

secao "TESTES DE PORTA TCP 443"
for HOST in github.com download.docker.com cdn.coollabs.io; do
    echo
    echo "Host: $HOST"
    timeout 15 bash -c "cat < /dev/null > /dev/tcp/$HOST/443" \
        && echo "TCP 443: conexão bem-sucedida" \
        || echo "TCP 443: falhou ou expirou"
done

secao "MTU"
if [ -n "${INTERFACE:-}" ]; then
    comando ip link show "$INTERFACE"
fi

for TAMANHO in 1472 1464 1452 1440 1420 1400 1380; do
    echo
    echo "Teste MTU com payload $TAMANHO:"
    ping -4 -c 3 -W 3 -M do -s "$TAMANHO" 1.1.1.1 2>&1 || true
done

secao "PORTAS LOCAIS"
comando ss -lntup

secao "FIREWALL DA VM"
comando ufw status verbose
comando iptables -S
comando iptables -t nat -S
comando nft list ruleset

secao "PROXY E VARIÁVEIS DE AMBIENTE"
env | grep -Ei '^(http|https|all|no)_proxy=' || echo "Nenhuma variável de proxy detectada."

secao "SERVIÇOS"
comando systemctl status ssh --no-pager
comando systemctl status systemd-resolved --no-pager
comando systemctl status qemu-guest-agent --no-pager
comando systemctl status docker --no-pager

secao "DOCKER"
comando docker version
comando docker info
comando docker ps -a

secao "JOURNAL DE REDE"
comando journalctl -u systemd-networkd --no-pager -n 200
comando journalctl -u NetworkManager --no-pager -n 200
comando journalctl -u systemd-resolved --no-pager -n 200

secao "LOGS ANTERIORES DO COOLIFY"
if [ -f /var/log/instalar-coolify.log ]; then
    comando tail -n 500 /var/log/instalar-coolify.log
else
    echo "/var/log/instalar-coolify.log não encontrado."
fi

secao "RESUMO AUTOMÁTICO"

if curl -4 -fsSI --connect-timeout 15 --max-time 25 https://github.com >/dev/null 2>&1; then
    echo "[OK] GitHub acessível por HTTPS/IPv4."
else
    echo "[FALHA] GitHub não acessível por HTTPS/IPv4."
fi

if curl -4 -fsSI --connect-timeout 15 --max-time 25 https://download.docker.com >/dev/null 2>&1; then
    echo "[OK] download.docker.com acessível por HTTPS/IPv4."
else
    echo "[FALHA] download.docker.com não acessível por HTTPS/IPv4."
fi

if curl -4 -fsSI --connect-timeout 15 --max-time 25 https://cdn.coollabs.io >/dev/null 2>&1; then
    echo "[OK] cdn.coollabs.io acessível por HTTPS/IPv4."
else
    echo "[FALHA] cdn.coollabs.io não acessível por HTTPS/IPv4."
fi

echo
echo "Diagnóstico concluído."
echo "Arquivo gerado:"
echo "$ARQUIVO"
echo
echo "Para conferir:"
echo "ls -lh \"$ARQUIVO\""
