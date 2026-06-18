#!/usr/bin/env bash
set -Eeuo pipefail

# Uso:
#   sudo bash criar-usuario-ssh.sh nome_do_usuario
#
# Exemplo:
#   sudo bash criar-usuario-ssh.sh joao

if [ "$(id -u)" -ne 0 ]; then
    echo "ERRO: execute como root ou com sudo."
    echo "Exemplo: sudo bash $0 joao"
    exit 1
fi

USUARIO="${1:-}"

if [ -z "$USUARIO" ]; then
    read -rp "Digite o nome do novo usuário: " USUARIO
fi

if ! [[ "$USUARIO" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "ERRO: nome de usuário inválido."
    echo "Use apenas letras minúsculas, números, _ e -."
    exit 1
fi

echo "========================================"
echo " Criação de usuário SSH"
echo " Usuário: $USUARIO"
echo "========================================"

# Instala e ativa o servidor SSH
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server sudo

systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh

# Cria o usuário, caso ainda não exista
if id "$USUARIO" >/dev/null 2>&1; then
    echo "AVISO: o usuário '$USUARIO' já existe."
else
    useradd \
        --create-home \
        --shell /bin/bash \
        --groups sudo \
        "$USUARIO"

    echo "Usuário '$USUARIO' criado."
fi

# Garante acesso ao grupo sudo
usermod -aG sudo "$USUARIO"

echo
echo "Defina a senha do usuário '$USUARIO':"
passwd "$USUARIO"

# Prepara o diretório SSH
HOME_USUARIO="$(getent passwd "$USUARIO" | cut -d: -f6)"
mkdir -p "$HOME_USUARIO/.ssh"
touch "$HOME_USUARIO/.ssh/authorized_keys"

chmod 700 "$HOME_USUARIO/.ssh"
chmod 600 "$HOME_USUARIO/.ssh/authorized_keys"
chown -R "$USUARIO:$USUARIO" "$HOME_USUARIO/.ssh"

# Copia chaves SSH do usuário que chamou sudo, quando existirem
USUARIO_ORIGEM="${SUDO_USER:-}"

if [ -n "$USUARIO_ORIGEM" ] && [ "$USUARIO_ORIGEM" != "root" ]; then
    HOME_ORIGEM="$(getent passwd "$USUARIO_ORIGEM" | cut -d: -f6)"
    CHAVES_ORIGEM="$HOME_ORIGEM/.ssh/authorized_keys"

    if [ -s "$CHAVES_ORIGEM" ]; then
        cat "$CHAVES_ORIGEM" >> "$HOME_USUARIO/.ssh/authorized_keys"
        sort -u "$HOME_USUARIO/.ssh/authorized_keys" \
            -o "$HOME_USUARIO/.ssh/authorized_keys"

        chmod 600 "$HOME_USUARIO/.ssh/authorized_keys"
        chown "$USUARIO:$USUARIO" "$HOME_USUARIO/.ssh/authorized_keys"

        echo "Chaves SSH de '$USUARIO_ORIGEM' copiadas para '$USUARIO'."
    fi
fi

# Valida configuração do SSH
sshd -t

IP_VM="$(hostname -I | awk '{print $1}')"

echo
echo "========================================"
echo " Usuário SSH configurado com sucesso"
echo "========================================"
echo "Usuário: $USUARIO"
echo "IP da VM: ${IP_VM:-não identificado}"
echo
echo "Teste de acesso:"
echo "ssh ${USUARIO}@${IP_VM:-IP_DA_VM}"
echo
echo "Grupos do usuário:"
id "$USUARIO"
echo
echo "Status do SSH:"
systemctl is-active ssh
