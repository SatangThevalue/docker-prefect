#!/bin/bash
# Script for setting up Docker, Docker Compose, Docker user group, and mkcert on Ubuntu
# Usage: sudo bash setup_docker.sh

set -e

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    libnss3-tools

# Add Docker’s official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
ARCH=$(dpkg --print-architecture)
RELEASE=$(lsb_release -cs)
echo \
  "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $RELEASE stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine, CLI, containerd, and Docker Compose plugin
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Install mkcert
if ! command -v mkcert &> /dev/null; then
  echo "Installing mkcert..."
  sudo apt-get install -y wget
  wget -O mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
  chmod +x mkcert
  sudo mv mkcert /usr/local/bin/
fi

# Create local CA if not exists
if [ ! -f "$HOME/.local/share/mkcert/rootCA.pem" ]; then
  mkcert -install
fi

# Print info
echo "\nDocker, Docker Compose, and mkcert installed successfully."
echo "User $USER added to docker group. Please log out and log in again to use Docker without sudo."
echo "Use mkcert to generate SSL certificates for local development."

# Generate SSL certificate for domain from .env (PREFECT_DOMAIN or fallback to localhost)
CERT_DIR="$(pwd)/certs"
DOMAIN=$(grep '^PREFECT_DOMAIN=' .env | cut -d '=' -f2 | tr -d '"')
if [ -z "$DOMAIN" ]; then
  DOMAIN=localhost
fi
mkdir -p "$CERT_DIR"
mkcert -cert-file "$CERT_DIR/fullchain.pem" -key-file "$CERT_DIR/privkey.pem" "$DOMAIN"
echo "\nSSL certificate generated for domain: $DOMAIN (output in ./certs)"

# Install No-IP Dynamic Update Client (DUC) 3.x
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

if [[ -z "$NOIP_HOSTNAME" || -z "$NOIP_USERNAME" || -z "$NOIP_PASSWORD" ]]; then
  echo "NOIP_HOSTNAME, NOIP_USERNAME, NOIP_PASSWORD must be set in .env for No-IP DUC setup. Skipping DUC install."
else
  echo "Installing No-IP Dynamic Update Client (DUC)..."
  wget --content-disposition https://www.noip.com/download/linux/latest
  tar xf noip-duc_*.tar.gz
  DUC_DIR=$(find . -type d -name 'noip-duc_*' | head -n 1)
  cd "$DUC_DIR/binaries"
  sudo apt install -y ./noip-duc_*_amd64.deb
  cd ../../
  # Add crontab entry for DUC (every 5 minutes)
  CRON_CMD="noip-duc -g $NOIP_HOSTNAME -u $NOIP_USERNAME -p $NOIP_PASSWORD"
  (crontab -l 2>/dev/null | grep -v 'noip-duc'; echo "*/5 * * * * $CRON_CMD") | crontab -
  echo "No-IP DUC installed and scheduled in crontab."
fi
