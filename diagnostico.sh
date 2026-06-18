echo "=== IP ==="
ip -br addr

echo "=== ROTA ==="
ip route

echo "=== DNS ==="
cat /etc/resolv.conf

echo "=== TESTE GATEWAY ==="
GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
echo "Gateway: $GATEWAY"
ping -c 4 "$GATEWAY"

echo "=== TESTE INTERNET POR IP ==="
ping -c 4 1.1.1.1

echo "=== TESTE DNS ==="
getent hosts cdn.coollabs.io
getent hosts google.com

echo "=== TESTE HTTPS ==="
curl -Iv --connect-timeout 15 https://cdn.coollabs.io/coolify/install.sh

echo "=== TESTE HTTPS ALTERNATIVO ==="
curl -Iv --connect-timeout 15 https://github.com
