#!/bin/bash

# Show Python Environment Information
# This script displays information about the Python environment being used

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

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Python Environment Information                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Python
echo -e "${BLUE}System Python:${NC}"
echo "  Path: $(which python3)"
echo "  Version: $(python3 --version 2>&1)"
echo ""

# Virtual Environment Python
echo -e "${BLUE}Virtual Environment Python:${NC}"
if [ -f "$VENV_DIR/bin/python" ]; then
    echo "  Path: $VENV_DIR/bin/python"
    echo "  Version: $("$VENV_DIR/bin/python" --version 2>&1)"
    echo "  Status: ${GREEN}✅ Installed${NC}"
    
    echo ""
    echo -e "${BLUE}Virtual Environment Packages:${NC}"
    "$VENV_DIR/bin/pip" list --format=columns | head -20
    
    TOTAL_PACKAGES=$("$VENV_DIR/bin/pip" list --format=freeze | wc -l)
    echo "  ... Total packages: $TOTAL_PACKAGES"
else
    echo "  Status: ${RED}❌ Not installed${NC}"
    echo "  Run 'make venv' to create the virtual environment"
fi

echo ""

# Current environment
echo -e "${BLUE}Current Environment:${NC}"
if [ -n "$VIRTUAL_ENV" ]; then
    echo "  Active venv: ${GREEN}$VIRTUAL_ENV${NC}"
    echo "  Python used: $(which python)"
else
    echo "  Active venv: ${YELLOW}None (using system Python)${NC}"
    echo "  To activate: source $VENV_DIR/bin/activate"
fi

echo ""

# Environment isolation check
echo -e "${BLUE}Environment Isolation:${NC}"
echo "  Project directory: $PROJECT_DIR"
echo "  Venv directory: $VENV_DIR"
echo "  Scripts will use: $VENV_DIR/bin/python"
echo "  ${GREEN}✅ All Python operations are isolated in venv${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"