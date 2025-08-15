#!/bin/bash

# Virtual Environment Setup Script for Legion Development Setup
# This script manages the Python virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to check if Python 3 is installed
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        # Check if it's Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            PYTHON_CMD="python"
        else
            print_error "Python 3 is required but not found"
            exit 1
        fi
    else
        print_error "Python is not installed. Please install Python 3.7 or later"
        exit 1
    fi
    
    print_status "Found Python: $($PYTHON_CMD --version)"
}

# Function to create virtual environment
create_venv() {
    if [ -d "$VENV_DIR" ]; then
        print_warning "Virtual environment already exists at $VENV_DIR"
        read -p "Do you want to recreate it? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing virtual environment"
            return 0
        fi
        rm -rf "$VENV_DIR"
    fi
    
    print_status "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    
    if [ ! -d "$VENV_DIR" ]; then
        print_error "Failed to create virtual environment"
        exit 1
    fi
    
    # Activate the virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip --quiet
    
    # Install required packages
    print_status "Installing required packages..."
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
    else
        # Install core packages if requirements.txt doesn't exist
        pip install PyYAML mysql-connector-python requests gdown --quiet
    fi
    
    print_status "Virtual environment created successfully!"
}

# Function to activate virtual environment
activate_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        print_error "Virtual environment not found. Creating it now..."
        create_venv
    fi
    
    print_status "Virtual environment is ready at: $VENV_DIR"
    echo "To activate it manually, run: source $VENV_DIR/bin/activate"
}

# Function to clean virtual environment
clean_venv() {
    if [ -d "$VENV_DIR" ]; then
        print_warning "Removing virtual environment at $VENV_DIR"
        rm -rf "$VENV_DIR"
        print_status "Virtual environment removed"
    else
        print_status "No virtual environment to clean"
    fi
}

# Function to show virtual environment status
show_status() {
    echo "Virtual Environment Status"
    echo "=========================="
    
    if [ -d "$VENV_DIR" ]; then
        print_status "Virtual environment exists at: $VENV_DIR"
        
        # Check if it's activated
        if [ -n "$VIRTUAL_ENV" ]; then
            print_status "Virtual environment is currently activated"
        else
            print_warning "Virtual environment exists but is not activated"
        fi
        
        # Show installed packages
        echo ""
        echo "Installed packages:"
        if [ -f "$VENV_DIR/bin/pip" ]; then
            "$VENV_DIR/bin/pip" list 2>/dev/null | grep -E "(PyYAML|mysql-connector|requests|gdown)" || echo "  Core packages not installed"
        fi
    else
        print_error "Virtual environment does not exist"
        echo "Run './setup_venv.sh create' to create it"
    fi
}

# Main script logic
main() {
    check_python
    
    case "${1:-create}" in
        create)
            create_venv
            ;;
        activate)
            activate_venv
            ;;
        clean)
            clean_venv
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 {create|activate|clean|status}"
            echo ""
            echo "Commands:"
            echo "  create   - Create virtual environment and install dependencies"
            echo "  activate - Show activation instructions"
            echo "  clean    - Remove virtual environment"
            echo "  status   - Show virtual environment status"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"