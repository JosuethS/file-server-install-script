#!/bin/bash

# Update and upgrade existing packages
echo "Updating and upgrading existing packages..."
sudo apt update && sudo apt upgrade -y

echo "System update and upgrade complete!"

# Install dependencies
echo "Installing required dependencies for Docker..."
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

# Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable Docker repository
echo "Setting up Docker repository..."
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
echo "Installing Docker..."
sudo apt update
sudo apt install docker-ce -y

# Start and enable Docker service
echo "Starting and enabling Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker installation
echo "Verifying Docker installation..."
sudo docker --version

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Set execute permissions for Docker Compose binary
echo "Setting execute permissions for Docker Compose..."
sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose installation
echo "Verifying Docker Compose installation..."
docker-compose --version

echo "Docker and Docker Compose installation complete!"

# Create Docker file structure for FileBrowser
echo "Creating FileBrowser directory structure..."

# Create the required directories
mkdir -p ~/docker/FileBrowser/Files

# Move into the FileBrowser directory
cd ~/docker/FileBrowser

# Create a docker-compose.yml file for FileBrowser, binding to IP and port 8080
echo "Creating docker-compose.yml for FileBrowser..."
cat <<EOL > docker-compose.yml
version: '3.3'

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser
    ports:
      - "0.0.0.0:8080:80"  # Bind the container to IP 0.0.0.0 and port 8080
    volumes:
      - ./Files:/srv
      - ./filebrowser.db:/database/filebrowser.db
      - ./settings.json:/config/settings.json
    environment:
      - PUID=1000
      - PGID=1000
    restart: unless-stopped
EOL

# Create an initial empty settings.json (you can customize this file later)
echo "Creating empty settings.json file..."
cat <<EOL > settings.json
{
  "address": ":80",
  "port": 80,
  "noauth": false,
  "database": "/database/filebrowser.db",
  "log": "/dev/stdout"
}
EOL

# Start the FileBrowser container using Docker Compose
echo "Starting FileBrowser using Docker Compose..."
sudo docker-compose up -d

echo "FileBrowser is now installed and running on IP 0.0.0.0 and port 8080!"

# Install Nginx as reverse proxy
echo "Installing Nginx..."
sudo apt install nginx -y

# Disable the default Nginx site configuration to avoid the default page
echo "Disabling default Nginx site configuration..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-available/default

# Prompt user for the domain name
read -p "Enter your domain name (e.g., files.dreamindex.org): " DOMAIN_NAME

# Create Nginx configuration file for FileBrowser
echo "Creating Nginx configuration file for FileBrowser..."

cat <<EOL | sudo tee /etc/nginx/sites-available/filebrowser
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://localhost:8080;  # Pointing to port 8080 now
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Create a symlink to enable the site
echo "Enabling Nginx site configuration..."
sudo ln -s /etc/nginx/sites-available/filebrowser /etc/nginx/sites-enabled/

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t

# Restart Nginx to apply changes
echo "Restarting Nginx..."
sudo systemctl restart nginx

echo "FileBrowser is now accessible at http://$DOMAIN_NAME!"

# Install Snapd for Certbot
echo "Installing Snapd..."
sudo apt install snapd -y

# Install Certbot using Snap
echo "Installing Certbot..."
sudo snap install --classic certbot

# Create a symbolic link for certbot
echo "Creating symbolic link for certbot..."
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Request SSL certificate for Nginx using Certbot
echo "Requesting SSL certificate for your domain..."
sudo certbot --nginx -d $DOMAIN_NAME

# Set up auto-renewal for Certbot
echo "Setting up auto-renewal for Certbot..."
sudo certbot renew --dry-run

echo "SSL certificate installed and auto-renewal is enabled!"

echo "FileBrowser with SSL is now set up and running!"