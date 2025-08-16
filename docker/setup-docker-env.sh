#!/bin/bash
# Setup Legion Docker Development Environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Legion Docker Environment Setup                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if running on Mac or Linux
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Step 1: Update hosts file
echo -e "${YELLOW}Step 1: Updating /etc/hosts file...${NC}"
HOSTS_ENTRIES="
# Legion Development Environment
127.0.0.1 legion.local
127.0.0.1 kibana.legion.local
127.0.0.1 mail.legion.local
127.0.0.1 tracing.legion.local
127.0.0.1 localstack.legion.local
127.0.0.1 health.legion.local
"

# Check if entries already exist
if grep -q "legion.local" /etc/hosts; then
    echo -e "${GREEN}✓ Host entries already exist${NC}"
else
    echo "Adding host entries (requires sudo)..."
    echo "$HOSTS_ENTRIES" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}✓ Host entries added${NC}"
fi

# Step 2: Login to JFrog
echo -e "${YELLOW}Step 2: JFrog Docker Registry Login...${NC}"
if docker login legiontech.jfrog.io 2>/dev/null; then
    echo -e "${GREEN}✓ Already logged in to JFrog${NC}"
else
    echo "Please login to JFrog Artifactory:"
    docker login legiontech.jfrog.io
fi

# Step 3: Create necessary directories
echo -e "${YELLOW}Step 3: Creating directories...${NC}"
mkdir -p logs
chmod 777 logs  # Caddy needs write access

# Step 4: Pull latest images
echo -e "${YELLOW}Step 4: Pulling Docker images...${NC}"
docker-compose pull

# Step 5: Start services
echo -e "${YELLOW}Step 5: Starting Docker services...${NC}"
docker-compose up -d

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 5

# Check service health
echo -e "${YELLOW}Checking service health...${NC}"
docker-compose ps

# Step 6: Trust Caddy's local certificate (Mac only)
if [[ "$OS" == "macos" ]]; then
    echo -e "${YELLOW}Step 6: Trusting development certificate...${NC}"
    
    # Export Caddy's root certificate
    docker exec legion-caddy cat /data/caddy/pki/authorities/local/root.crt > caddy-root.crt
    
    # Add to macOS keychain
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain caddy-root.crt
    rm caddy-root.crt
    
    echo -e "${GREEN}✓ Development certificate trusted${NC}"
elif [[ "$OS" == "linux" ]]; then
    echo -e "${YELLOW}Step 6: Trusting development certificate...${NC}"
    
    # Export Caddy's root certificate
    docker exec legion-caddy cat /data/caddy/pki/authorities/local/root.crt > caddy-root.crt
    
    # Add to Linux certificate store
    sudo cp caddy-root.crt /usr/local/share/ca-certificates/caddy-local.crt
    sudo update-ca-certificates
    rm caddy-root.crt
    
    echo -e "${GREEN}✓ Development certificate trusted${NC}"
fi

# Step 7: Display access information
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo "  Main App:        https://legion.local"
echo "  Mail UI:         https://mail.legion.local"
echo "  Tracing:         https://tracing.legion.local"
echo "  Health Check:    https://health.legion.local/services"
echo ""
echo -e "${BLUE}Direct Service Ports:${NC}"
echo "  MySQL:           localhost:3306"
echo "  Elasticsearch:   localhost:9200"
echo "  Redis Master:    localhost:6379"
echo "  Redis Slave:     localhost:6380"
echo "  LocalStack:      localhost:4566"
echo "  MailHog SMTP:    localhost:1025"
echo "  MailHog UI:      localhost:8025"
echo "  Jaeger UI:       localhost:16686"
echo ""
echo -e "${BLUE}Backend/Frontend Configuration:${NC}"
echo "  Backend runs on: host.docker.internal:8080 (localhost:8080)"
echo "  Frontend runs on: host.docker.internal:3000 (localhost:3000)"
echo "  Access via:      https://legion.local (proxied through Caddy)"
echo ""
echo -e "${YELLOW}Commands:${NC}"
echo "  View logs:       docker-compose logs -f [service]"
echo "  Stop all:        docker-compose down"
echo "  Restart:         docker-compose restart [service]"
echo "  Clean volumes:   docker-compose down -v"
echo ""
echo -e "${GREEN}✨ Legion Docker environment is ready!${NC}"