#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if venv exists, if not create it
if [ ! -d "$SCRIPT_DIR/venv" ]; then
    echo "Virtual environment not found. Creating it first..."
    "$SCRIPT_DIR/setup_venv.sh" create
fi

# Activate and run the config script
source "$SCRIPT_DIR/venv/bin/activate"

# Use the venv's python directly to ensure it works
"$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/create_config_simple.py" "$@"
