#!/bin/bash

# Legion Development Environment Cleanup Script
# This script removes all installed components to allow for fresh setup validation

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Safety confirmation
echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                    ⚠️  WARNING - CLEANUP MODE ⚠️                 ║${NC}"
echo -e "${RED}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${RED}║  This will remove ALL Legion development environment setup:    ║${NC}"
echo -e "${RED}║                                                                ║${NC}"
echo -e "${RED}║  • Docker containers (Elasticsearch, Redis, LocalStack)       ║${NC}"
echo -e "${RED}║  • MySQL databases (legiondb, legiondb0)                      ║${NC}"
echo -e "${RED}║  • Cloned repositories (~Development/legion)                  ║${NC}"
echo -e "${RED}║  • Configuration files (setup_config.yaml)                    ║${NC}"
echo -e "${RED}║  • Virtual environment (venv/)                                ║${NC}"
echo -e "${RED}║  • Setup logs and temp files                                  ║${NC}"
echo -e "${RED}║                                                                ║${NC}"
echo -e "${RED}║  Software like Java, Maven, Node.js will NOT be removed       ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirmation
if [ "$confirmation" != "yes" ]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

echo ""
echo -e "${BLUE}Starting cleanup process...${NC}"
echo ""

# 1. Stop and remove Docker containers
echo "==================================================================="
echo "Step 1: Cleaning up Docker containers"
echo "==================================================================="

if command -v docker &> /dev/null; then
    print_info "Stopping Legion Docker containers..."
    
    # Stop containers
    docker stop legion-elasticsearch 2>/dev/null && print_status "Stopped Elasticsearch container" || print_warning "Elasticsearch container not running"
    docker stop legion-redis-master 2>/dev/null && print_status "Stopped Redis master container" || print_warning "Redis master container not running"
    docker stop legion-redis-slave 2>/dev/null && print_status "Stopped Redis slave container" || print_warning "Redis slave container not running"
    docker stop legion-localstack 2>/dev/null && print_status "Stopped LocalStack container" || print_warning "LocalStack container not running"
    
    # Remove containers
    print_info "Removing Legion Docker containers..."
    docker rm legion-elasticsearch 2>/dev/null && print_status "Removed Elasticsearch container"
    docker rm legion-redis-master 2>/dev/null && print_status "Removed Redis master container"
    docker rm legion-redis-slave 2>/dev/null && print_status "Removed Redis slave container"
    docker rm legion-localstack 2>/dev/null && print_status "Removed LocalStack container"
    
    # Remove Docker network
    docker network rm legion-network 2>/dev/null && print_status "Removed Legion Docker network"
else
    print_warning "Docker not installed, skipping container cleanup"
fi

echo ""

# 2. Clean up MySQL databases
echo "==================================================================="
echo "Step 2: Cleaning up MySQL databases"
echo "==================================================================="

if command -v mysql &> /dev/null; then
    print_info "Removing Legion databases..."
    
    # Check if MySQL is running
    if mysql -u root -pmysql123 -e "SELECT 1" 2>/dev/null; then
        mysql -u root -pmysql123 -e "DROP DATABASE IF EXISTS legiondb;" 2>/dev/null && print_status "Removed legiondb database"
        mysql -u root -pmysql123 -e "DROP DATABASE IF EXISTS legiondb0;" 2>/dev/null && print_status "Removed legiondb0 database"
    else
        print_warning "MySQL not accessible, skipping database cleanup"
        print_info "You may need to manually remove databases if MySQL is configured differently"
    fi
else
    print_warning "MySQL not installed, skipping database cleanup"
fi

echo ""

# 3. Remove cloned repositories
echo "==================================================================="
echo "Step 3: Removing cloned repositories"
echo "==================================================================="

REPO_PATHS=(
    "$HOME/Development/legion/code/enterprise"
    "$HOME/Development/legion/code/console-ui"
)

for repo_path in "${REPO_PATHS[@]}"; do
    if [ -d "$repo_path" ]; then
        print_info "Removing $repo_path..."
        rm -rf "$repo_path"
        print_status "Removed $(basename $repo_path) repository"
    else
        print_warning "Repository not found: $repo_path"
    fi
done

# Clean up empty directories
if [ -d "$HOME/Development/legion/code" ]; then
    rmdir "$HOME/Development/legion/code" 2>/dev/null
    rmdir "$HOME/Development/legion" 2>/dev/null
    rmdir "$HOME/Development" 2>/dev/null
fi

echo ""

# 4. Remove configuration files
echo "==================================================================="
echo "Step 4: Removing configuration files"
echo "==================================================================="

# Project configuration
if [ -f "$PROJECT_DIR/setup_config.yaml" ]; then
    cp "$PROJECT_DIR/setup_config.yaml" "$PROJECT_DIR/setup_config.yaml.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    rm -f "$PROJECT_DIR/setup_config.yaml"
    print_status "Removed setup_config.yaml (backup created)"
else
    print_warning "setup_config.yaml not found"
fi

# Legion setup directory
if [ -d "$HOME/.legion_setup" ]; then
    print_info "Removing Legion setup directory..."
    rm -rf "$HOME/.legion_setup"
    print_status "Removed ~/.legion_setup directory"
else
    print_warning "~/.legion_setup directory not found"
fi

echo ""

# 5. Clean up virtual environment
echo "==================================================================="
echo "Step 5: Cleaning up Python virtual environment"
echo "==================================================================="

if [ -d "$VENV_DIR" ]; then
    print_info "Removing virtual environment..."
    rm -rf "$VENV_DIR"
    print_status "Removed virtual environment"
else
    print_warning "Virtual environment not found"
fi

echo ""

# 6. Clean up Maven settings (optional)
echo "==================================================================="
echo "Step 6: Maven settings cleanup (optional)"
echo "==================================================================="

read -p "Do you want to remove Maven settings.xml? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$HOME/.m2/settings.xml" ]; then
        cp "$HOME/.m2/settings.xml" "$HOME/.m2/settings.xml.backup.$(date +%Y%m%d_%H%M%S)"
        rm -f "$HOME/.m2/settings.xml"
        print_status "Removed Maven settings.xml (backup created)"
    else
        print_warning "Maven settings.xml not found"
    fi
else
    print_info "Keeping Maven settings.xml"
fi

echo ""

# 7. Clean up SSH keys (optional)
echo "==================================================================="
echo "Step 7: SSH key cleanup (optional)"
echo "==================================================================="

read -p "Do you want to remove Legion SSH keys? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$HOME/.ssh/id_ed25519_legion" ]; then
        rm -f "$HOME/.ssh/id_ed25519_legion"
        rm -f "$HOME/.ssh/id_ed25519_legion.pub"
        print_status "Removed Legion SSH keys"
    else
        print_warning "Legion SSH keys not found"
    fi
else
    print_info "Keeping SSH keys"
fi

echo ""

# 8. Summary
echo "==================================================================="
echo "                        CLEANUP COMPLETE!"
echo "==================================================================="
echo ""
print_status "Development environment has been cleaned"
print_info "The following have been removed:"
echo "  • Docker containers and network"
echo "  • MySQL databases (legiondb, legiondb0)"
echo "  • Cloned repositories"
echo "  • Configuration files"
echo "  • Virtual environment"
echo "  • Setup logs and temp files"
echo ""
print_info "The following were NOT removed (still installed):"
echo "  • Java, Maven, Node.js, Yarn, Docker, MySQL"
echo "  • Homebrew packages"
echo "  • System-wide Python packages"
echo ""
print_status "You can now run './setup.sh' for a fresh installation"
echo ""
echo "==================================================================="