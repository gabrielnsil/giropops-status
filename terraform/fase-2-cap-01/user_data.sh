#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Bootstrap do Giropops Status numa EC2 Ubuntu recém-criada.
# Roda como root via cloud-init no primeiro boot da máquina.
#
# Variáveis interpoladas pelo Terraform (templatefile):
#   ${repo_url}    — URL HTTPS do repo
#   ${repo_branch} — branch a clonar (default: fase-2-cap-01)
#
# Log completo em /var/log/cloud-init-output.log
#   sudo tail -f /var/log/cloud-init-output.log
# ──────────────────────────────────────────────────────────────

set -euxo pipefail

# 1. Atualiza pacotes e instala dependências do sistema
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    redis-server \
    curl

# 2. Habilita e inicia o Redis (default: localhost:6379, sem auth)
systemctl enable redis-server
systemctl start redis-server

# 3. Cria usuário dedicado giropops (não-root)
if ! id -u giropops &>/dev/null; then
    useradd --create-home --shell /bin/bash giropops
fi

# 4. Clona o repositório dentro do home do giropops
APP_DIR="/home/giropops/app"
if [ ! -d "$APP_DIR" ]; then
    sudo -u giropops git clone --branch "${repo_branch}" "${repo_url}" "$APP_DIR"
fi

# 5. Cria venv e instala dependências Python
sudo -u giropops python3 -m venv "$APP_DIR/.venv"
sudo -u giropops "$APP_DIR/.venv/bin/pip" install --upgrade pip
sudo -u giropops "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

# 6. Cria unit do systemd pra rodar a aplicação no boot
cat > /etc/systemd/system/giropops-status.service <<'EOF'
[Unit]
Description=Giropops Status (Flask + Redis)
After=network.target redis-server.service
Requires=redis-server.service

[Service]
Type=simple
User=giropops
Group=giropops
WorkingDirectory=/home/giropops/app
Environment="REDIS_HOST=localhost"
Environment="REDIS_PORT=6379"
ExecStart=/home/giropops/app/.venv/bin/python /home/giropops/app/app.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 7. Recarrega systemd, habilita e inicia
systemctl daemon-reload
systemctl enable giropops-status.service
systemctl start giropops-status.service

# 8. Sanity check (não falha o boot se demorar — apenas loga)
sleep 5
systemctl status giropops-status.service --no-pager || true
ss -tlnp | grep -E ':5000|:6379' || true

echo "Bootstrap concluído. Acesse http://<IP>:5000"
