#!/bin/bash

set -e

sudo dnf update -y
sudo dnf install -y docker
sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker $USER
newgrp docker

DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose"
sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_PATH
sudo chmod +x $DOCKER_COMPOSE_PATH

APP_DIR="/app"
sudo mkdir -p $APP_DIR

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

EFS_MOUNT_POINT="/mnt/efs"
sudo mkdir -p $EFS_MOUNT_POINT
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-001b7051e49e1d14f.efs.us-east-1.amazonaws.com:/ $EFS_MOUNT_POINT

docker-compose -f /app/compose.yml up -d

