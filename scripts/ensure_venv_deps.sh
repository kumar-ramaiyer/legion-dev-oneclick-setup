#!/bin/bash

# Ensure Virtual Environment Dependencies Script
# This script ensures all required Python packages are installed in the virtual environment

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

echo -e "${BLUE}Checking virtual environment dependencies...${NC}"

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Virtual environment not found. Creating...${NC}"
    "$SCRIPT_DIR/setup_venv.sh" create
fi

# Required packages
REQUIRED_PACKAGES=(
    "PyYAML"
    "mysql-connector-python"
    "requests"
    "gdown"
    "python-dotenv"
    "psutil"
)

# Additional packages that might be needed
OPTIONAL_PACKAGES=(
    "docker-compose"
    "localstack"
    "pipx"
)

echo -e "${BLUE}Checking required packages...${NC}"

# Check and install required packages
for package in "${REQUIRED_PACKAGES[@]}"; do
    if "$VENV_DIR/bin/python" -c "import ${package//-/_}" 2>/dev/null; then
        echo -e "${GREEN}✅${NC} $package is installed"
    else
        echo -e "${YELLOW}Installing $package...${NC}"
        if [ "$package" = "PyYAML" ]; then
            # Special handling for PyYAML on Python 3.13
            "$VENV_DIR/bin/pip" install --no-build-isolation "$package" 2>/dev/null || \
            "$VENV_DIR/bin/pip" install "$package"
        else
            "$VENV_DIR/bin/pip" install "$package"
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅${NC} $package installed successfully"
        else
            echo -e "${RED}❌${NC} Failed to install $package"
        fi
    fi
done

echo ""
echo -e "${BLUE}Checking optional packages...${NC}"

# Check optional packages (don't fail if they can't be installed)
for package in "${OPTIONAL_PACKAGES[@]}"; do
    if "$VENV_DIR/bin/python" -c "import ${package//-/_}" 2>/dev/null; then
        echo -e "${GREEN}✅${NC} $package is installed"
    else
        echo -e "${YELLOW}⚠️${NC} $package is not installed (optional)"
    fi
done

echo ""
echo -e "${GREEN}Dependency check complete!${NC}"

# Show pip list
echo ""
echo -e "${BLUE}Installed packages in virtual environment:${NC}"
"$VENV_DIR/bin/pip" list --format=columns

echo ""
echo -e "${GREEN}✅ Virtual environment is ready for use${NC}"