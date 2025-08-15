#!/bin/bash
# Legion Dev Setup - Virtual Environment Activation Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/venv"

if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    echo "❌ Virtual environment not found. Run ./scripts/setup_venv.sh first."
    exit 1
fi

source "$VENV_DIR/bin/activate"
echo "✅ Legion dev setup virtual environment activated"
echo "💡 Run 'deactivate' to exit the virtual environment"
