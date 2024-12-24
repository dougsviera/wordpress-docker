#!/bin/bash

set -e

# Atualizar pacotes e instalar dependências
sudo dnf update -y
sudo dnf install -y docker nfs-utils
sudo systemctl start docker
sudo systemctl enable docker

# Adicionar o usuário ao grupo docker
sudo usermod -aG docker $USER

# Instalar o Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose"

if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose não encontrado. Instalando..."
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_PATH
    sudo chmod +x $DOCKER_COMPOSE_PATH
fi

# Criar diretório da aplicação
APP_DIR="/app"
sudo mkdir -p $APP_DIR

# Criar o arquivo docker-compose.yml
COMPOSE_FILE="$APP_DIR/compose.yml"
cat <<EOF | sudo tee $COMPOSE_FILE > /dev/null
version: '3.7'
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: database.cvyesuwsi0x0.us-east-1.rds.amazonaws.com
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: password
      WORDPRESS_DB_NAME: wordpressdb
    volumes:
      - /mnt/efs:/var/www/html
EOF

# Criar o ponto de montagem do EFS
EFS_MOUNT_POINT="/mnt/efs"
sudo mkdir -p $EFS_MOUNT_POINT
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-001b7051e49e1d14f.efs.us-east-1.amazonaws.com:/ $EFS_MOUNT_POINT

# Subir os containers com o docker-compose
docker-compose -f /app/compose.yml up -d

# Criar o arquivo de serviço systemd para o docker-compose
sudo tee /etc/systemd/system/wordpress-docker.service > /dev/null <<EOF
[Unit]
Description=Start WordPress Docker Containers
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
WorkingDirectory=/app
ExecStart=$DOCKER_COMPOSE_PATH up -d
ExecStop=$DOCKER_COMPOSE_PATH down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Definir permissões adequadas para o arquivo de serviço
sudo chmod 644 /etc/systemd/system/wordpress-docker.service

# Recarregar o daemon do systemd e habilitar o serviço
sudo systemctl daemon-reload
sudo systemctl enable wordpress-docker.service
sudo systemctl start wordpress-docker.service


