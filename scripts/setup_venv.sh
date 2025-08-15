#!/bin/bash

# Virtual Environment Setup Script for Legion Development Setup
# This script manages the Python virtual environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/venv"

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
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        print_status "Python $PYTHON_VERSION found"
        return 0
    else
        print_error "Python 3 is not installed"
        echo "Please install Python 3.7 or later"
        return 1
    fi
}

# Function to create virtual environment
create_venv() {
    print_status "Creating Python virtual environment at $VENV_DIR..."
    
    if [[ -d "$VENV_DIR" ]]; then
        print_warning "Virtual environment already exists at $VENV_DIR"
        read -p "Do you want to recreate it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
        else
            print_status "Using existing virtual environment"
            return 0
        fi
    fi
    
    python3 -m venv "$VENV_DIR"
    
    if [[ $? -eq 0 ]]; then
        print_status "Virtual environment created successfully"
        
        # Upgrade pip
        print_status "Upgrading pip..."
        "$VENV_DIR/bin/python" -m pip install --upgrade pip --quiet
        
        # Install requirements if requirements.txt exists
        if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
            print_status "Installing requirements..."
            "$VENV_DIR/bin/pip" install -r "$PROJECT_DIR/requirements.txt"
        else
            print_warning "requirements.txt not found, skipping package installation"
        fi
        
        print_status "Virtual environment setup complete!"
        echo ""
        echo "To activate the virtual environment, run:"
        echo "  source $VENV_DIR/bin/activate"
        return 0
    else
        print_error "Failed to create virtual environment"
        return 1
    fi
}

# Function to clean virtual environment
clean_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        print_status "Removing virtual environment at $VENV_DIR..."
        rm -rf "$VENV_DIR"
        print_status "Virtual environment removed"
    else
        print_warning "No virtual environment found at $VENV_DIR"
    fi
}

# Function to activate virtual environment
activate_venv() {
    if [[ -d "$VENV_DIR" ]]; then
        print_status "Activating virtual environment..."
        source "$VENV_DIR/bin/activate"
        print_status "Virtual environment activated"
        echo "Python: $(which python)"
        echo "Pip: $(which pip)"
    else
        print_error "Virtual environment not found at $VENV_DIR"
        echo "Run '$0 create' to create it"
    fi
}

# Function to check status
check_status() {
    echo "Virtual Environment Status"
    echo "=========================="
    echo "Location: $VENV_DIR"
    
    if [[ -d "$VENV_DIR" ]]; then
        print_status "Virtual environment exists"
        
        # Check if activated
        if [[ "$VIRTUAL_ENV" == "$VENV_DIR" ]]; then
            print_status "Virtual environment is currently activated"
        else
            print_warning "Virtual environment is not activated"
        fi
        
        # Show installed packages
        echo ""
        echo "Installed packages:"
        "$VENV_DIR/bin/pip" list --format=columns 2>/dev/null || echo "Unable to list packages"
    else
        print_error "Virtual environment does not exist"
        echo "Run '$0 create' to create it"
    fi
}

# Main script logic
case "$1" in
    create)
        check_python && create_venv
        ;;
    clean)
        clean_venv
        ;;
    activate)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            print_error "This script must be sourced to activate the virtual environment"
            echo "Run: source $0 activate"
        else
            activate_venv
        fi
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {create|clean|activate|status}"
        echo ""
        echo "Commands:"
        echo "  create   - Create a new virtual environment"
        echo "  clean    - Remove the virtual environment"
        echo "  activate - Activate the virtual environment (must be sourced)"
        echo "  status   - Check virtual environment status"
        exit 1
        ;;
esac