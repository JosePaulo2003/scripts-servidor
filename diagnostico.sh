sudo bash -c '
ARQ="/tmp/diagnostico-coolify-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "===== DATA ====="
  date

  echo
  echo "===== SISTEMA ====="
  hostnamectl
  cat /etc/os-release
  uname -a

  echo
  echo "===== REDE ====="
  ip -br addr
  ip route
  cat /etc/resolv.conf

  echo
  echo "===== TESTES DE CONECTIVIDADE ====="
  ping -c 4 1.1.1.1 || true
  getent hosts cdn.coollabs.io || true
  curl -Iv --connect-timeout 20 https://cdn.coollabs.io/coolify/install.sh || true

  echo
  echo "===== PORTAS ====="
  ss -lntp

  echo
  echo "===== DOCKER ====="
  docker version 2>&1 || true
  docker ps -a 2>&1 || true

  echo
  echo "===== SERVIÇOS ====="
  systemctl status docker --no-pager 2>&1 || true
  systemctl status ssh --no-pager 2>&1 || true
  systemctl status qemu-guest-agent --no-pager 2>&1 || true

  echo
  echo "===== JOURNAL DOCKER ====="
  journalctl -u docker --no-pager -n 300 2>&1 || true

  echo
  echo "===== JOURNAL QEMU AGENT ====="
  journalctl -u qemu-guest-agent --no-pager -n 200 2>&1 || true

  echo
  echo "===== LOG DO SCRIPT ====="
  cat /var/log/instalar-coolify.log 2>&1 || true

  echo
  echo "===== LOGS COOLIFY ====="
  find /data/coolify -type f -name "*.log" -maxdepth 5 -print 2>/dev/null || true
} > "$ARQ" 2>&1

chmod 644 "$ARQ"
echo "Arquivo criado em: $ARQ"
'
