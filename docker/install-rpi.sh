#!/bin/bash
#
# Immich Raspberry Pi Installer (Lightweight Version)
# No machine learning, optimized for low resources
#
set -e

echo "=========================================="
echo "  Immich Raspberry Pi Installer"
echo "  (Lightweight - No ML)"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on ARM
if [[ $(uname -m) != "aarch64" ]] && [[ $(uname -m) != "arm64" ]]; then
    echo -e "${YELLOW}Warning: This script is optimized for Raspberry Pi (ARM64)${NC}"
fi

# Configuration
echo ""
echo -e "${YELLOW}Configuration:${NC}"
read -p "External HDD mount path for photos [/mnt/photos]: " PHOTO_PATH
PHOTO_PATH=${PHOTO_PATH:-/mnt/photos}

read -p "Database password [immich_db_pass]: " DB_PASS
DB_PASS=${DB_PASS:-immich_db_pass}

# Step 1: Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}Please log out and back in, then run this script again.${NC}"
    exit 0
fi

# Step 2: Create directories
echo -e "${GREEN}Creating directories...${NC}"
sudo mkdir -p "$PHOTO_PATH/immich-library"
sudo chown -R $USER:$USER "$PHOTO_PATH"
mkdir -p ./postgres-data

# Step 3: Create .env file
echo -e "${GREEN}Creating configuration...${NC}"
cat > .env << EOF
# Photos on external HDD
UPLOAD_LOCATION=${PHOTO_PATH}/immich-library

# Database on SD card
DB_DATA_LOCATION=./postgres-data

# Timezone
TZ=Asia/Kolkata

# Database
DB_PASSWORD=${DB_PASS}
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

# Disable ML
IMMICH_MACHINE_LEARNING_ENABLED=false
EOF

# Step 4: Build the custom server image
echo -e "${GREEN}Building Immich server (this may take 10-20 minutes on Pi)...${NC}"
cd ..
docker build -t immich-server-rpi:latest -f server/Dockerfile . --platform linux/arm64

# Step 5: Update compose file to use built image
cd docker
sed -i 's|build:|image: immich-server-rpi:latest\n    # build:|' docker-compose.rpi.yml 2>/dev/null || true

# Step 6: Start services
echo -e "${GREEN}Starting Immich...${NC}"
docker compose -f docker-compose.rpi.yml up -d

# Get IP address
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo -e "${GREEN}Immich is starting!${NC}"
echo "=========================================="
echo ""
echo "Access Immich at: http://${IP}:2283"
echo ""
echo "Photo storage: ${PHOTO_PATH}/immich-library"
echo "Database: ./postgres-data (on SD card)"
echo ""
echo "Commands:"
echo "  View logs:    docker compose -f docker-compose.rpi.yml logs -f"
echo "  Stop:         docker compose -f docker-compose.rpi.yml down"
echo "  Restart:      docker compose -f docker-compose.rpi.yml restart"
echo ""
echo -e "${YELLOW}Note: First startup may take a few minutes.${NC}"

