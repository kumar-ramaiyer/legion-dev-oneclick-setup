#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if venv exists, if not create it
if [ ! -d "$PROJECT_DIR/venv" ]; then
    echo "Virtual environment not found. Creating it first..."
    "$SCRIPT_DIR/setup_venv.sh" create
fi

# Activate and run the config script
source "$PROJECT_DIR/venv/bin/activate"

# Use the venv's python directly to ensure it works
"$PROJECT_DIR/venv/bin/python" "$PROJECT_DIR/create_config_simple.py" "$@"