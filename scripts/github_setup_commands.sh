#!/bin/bash

# GitHub Repository Setup Commands
# This script provides commands to set up the GitHub repository
# It reads the GitHub username from the setup configuration

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$PROJECT_DIR/venv"

# Function to extract GitHub username from config
get_github_user() {
    CONFIG_FILE="$PROJECT_DIR/setup_config.yaml"
    if [ -f "$CONFIG_FILE" ]; then
        # Try to use venv Python if available for better YAML parsing
        if [ -f "$VENV_DIR/bin/python" ]; then
            GITHUB_USER=$("$VENV_DIR/bin/python" -c "import yaml; config = yaml.safe_load(open('$CONFIG_FILE')); print(config.get('user', {}).get('github_username', ''))" 2>/dev/null)
        fi
        
        # Fallback to grep if Python method fails
        if [ -z "$GITHUB_USER" ]; then
            GITHUB_USER=$(grep "github_username:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"' | tr -d "'")
        fi
        
        if [ -z "$GITHUB_USER" ]; then
            echo "Error: GitHub username not found in setup_config.yaml"
            echo "Please run 'make config' first"
            exit 1
        fi
    else
        echo "Error: setup_config.yaml not found"
        echo "Please run 'make config' first"
        exit 1
    fi
}

# Get the GitHub username from config
get_github_user

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              GITHUB REPOSITORY SETUP COMMANDS               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "GitHub User: $GITHUB_USER"
echo ""
echo "Run these commands to set up the GitHub repository:"
echo ""
echo "1. Authenticate GitHub CLI (if not done):"
echo "   gh auth login"
echo ""
echo "2. Create the GitHub repository:"
echo "   gh repo create ${GITHUB_USER}/legion-dev-oneclick-setup --public --description 'One-click automated setup for Legion development environment'"
echo ""
echo "3. Add remote origin:"
echo "   git remote add origin https://github.com/${GITHUB_USER}/legion-dev-oneclick-setup.git"
echo ""
echo "4. Push the current branch:"
echo "   git push -u origin \$(git branch --show-current)"
echo ""
echo "5. Create a Pull Request:"
echo "   gh pr create --title 'feat: Your feature description' --body 'Describe your changes'"
echo ""
echo "6. Merge the PR (squash and merge):"
echo "   gh pr merge --squash --delete-branch"
echo ""
echo "7. Update local main branch:"
echo "   git checkout master"
echo "   git pull origin master"
echo ""
echo "8. Create new development branch:"
echo "   git checkout -b feature/new-development"
echo "   git push -u origin feature/new-development"