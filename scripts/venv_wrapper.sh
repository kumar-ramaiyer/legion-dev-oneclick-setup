#!/bin/bash

# Virtual Environment Wrapper Script
# This script ensures all Python commands run within the virtual environment

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠️${NC} Virtual environment not found. Creating it now..."
    "$SCRIPT_DIR/setup_venv.sh" create
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌${NC} Failed to create virtual environment"
        exit 1
    fi
fi

# Check if we're already in the virtual environment
if [ "$VIRTUAL_ENV" != "$VENV_DIR" ]; then
    # Activate the virtual environment
    source "$VENV_DIR/bin/activate"
    echo -e "${GREEN}✅${NC} Virtual environment activated: $VENV_DIR"
fi

# Execute the command passed as arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [arguments...]"
    echo "Example: $0 python legion_dev_setup.py --verbose"
    exit 1
fi

# Run the command with all arguments
exec "$@"