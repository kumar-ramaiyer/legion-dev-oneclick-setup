#!/bin/bash

# Legion Development Environment Validation Script
# This script validates that the setup is working correctly

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

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Function to print colored output
print_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    ((PASS_COUNT++))
}

print_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    ((FAIL_COUNT++))
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
    ((WARN_COUNT++))
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_section() {
    echo ""
    echo "==================================================================="
    echo "$1"
    echo "==================================================================="
}

# Start validation
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Legion Development Environment Validation             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

# 1. Check configuration file
print_section "1. Configuration Files"

if [ -f "$PROJECT_DIR/setup_config.yaml" ]; then
    print_pass "setup_config.yaml exists"
    
    # Check for required fields
    if grep -q "github_username:" "$PROJECT_DIR/setup_config.yaml"; then
        GITHUB_USER=$(grep "github_username:" "$PROJECT_DIR/setup_config.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
        if [ -n "$GITHUB_USER" ]; then
            print_pass "GitHub username configured: $GITHUB_USER"
        else
            print_fail "GitHub username is empty"
        fi
    else
        print_fail "GitHub username not found in config"
    fi
else
    print_fail "setup_config.yaml not found"
fi

# 2. Check virtual environment
print_section "2. Python Virtual Environment"

if [ -d "$VENV_DIR" ]; then
    print_pass "Virtual environment directory exists"
    
    if [ -f "$VENV_DIR/bin/python" ]; then
        print_pass "Python executable found in venv"
        
        # Check Python version
        PYTHON_VERSION=$("$VENV_DIR/bin/python" --version 2>&1 | awk '{print $2}')
        print_info "Python version: $PYTHON_VERSION"
        
        # Check required packages using venv Python
        if "$VENV_DIR/bin/python" -c "import yaml" 2>/dev/null; then
            print_pass "PyYAML is installed"
        else
            print_fail "PyYAML is not installed"
        fi
        
        if "$VENV_DIR/bin/python" -c "import mysql.connector" 2>/dev/null; then
            print_pass "mysql-connector-python is installed"
        else
            print_fail "mysql-connector-python is not installed"
        fi
        
        if "$VENV_DIR/bin/python" -c "import requests" 2>/dev/null; then
            print_pass "requests is installed"
        else
            print_fail "requests is not installed"
        fi
        
        if "$VENV_DIR/bin/python" -c "import gdown" 2>/dev/null; then
            print_pass "gdown is installed"
        else
            print_fail "gdown is not installed"
        fi
    else
        print_fail "Python executable not found in venv"
    fi
else
    print_fail "Virtual environment not found"
fi

# 3. Check scripts directory
print_section "3. Scripts Organization"

SCRIPTS=(
    "scripts/setup_venv.sh"
    "scripts/activate_venv.sh"
    "scripts/create_config_venv.sh"
    "scripts/extract_gdrive_ids.py"
    "scripts/github_setup_commands.sh"
    "scripts/cleanup.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_pass "$script exists and is executable"
        else
            print_warn "$script exists but is not executable"
        fi
    else
        print_fail "$script not found"
    fi
done

# 4. Check documentation directory
print_section "4. Documentation Organization"

DOCS=(
    "docs/PR_DESCRIPTION.md"
    "docs/PR_MESSAGE.md"
    "docs/README_SETUP.md"
    "docs/README_UNIFIED.md"
    "docs/SETUP_GUIDE.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        print_pass "$doc exists"
    else
        print_fail "$doc not found"
    fi
done

# 5. Check main setup files
print_section "5. Main Setup Files"

MAIN_FILES=(
    "setup.sh"
    "legion_dev_setup.py"
    "create_config_simple.py"
    "Makefile"
    "README.md"
    "requirements.txt"
)

for file in "${MAIN_FILES[@]}"; do
    if [ -f "$file" ]; then
        if [[ "$file" == *.sh ]] && [ ! -x "$file" ]; then
            print_warn "$file exists but is not executable"
        else
            print_pass "$file exists"
        fi
    else
        print_fail "$file not found"
    fi
done

# 6. Check setup modules
print_section "6. Setup Modules"

MODULES=(
    "setup_modules/__init__.py"
    "setup_modules/config_resolver.py"
    "setup_modules/installer.py"
    "setup_modules/database_setup.py"
    "setup_modules/docker_container_setup.py"
    "setup_modules/git_github_setup.py"
    "setup_modules/jfrog_maven_setup.py"
    "setup_modules/progress_tracker.py"
    "setup_modules/validator.py"
)

for module in "${MODULES[@]}"; do
    if [ -f "$module" ]; then
        print_pass "$module exists"
    else
        print_fail "$module not found"
    fi
done

# 7. Check for hardcoded usernames
print_section "7. Hardcoded Username Check"

# Search for hardcoded kumar.ramaiyer or kumar-ramaiyer, excluding expected files
HARDCODED_FILES=$(grep -r "kumar\.ramaiyer\|kumar-ramaiyer" . \
    --exclude-dir=venv \
    --exclude-dir=.git \
    --exclude="*.log" \
    --exclude="setup_config.yaml" \
    --exclude="setup_config.yaml.backup*" \
    --exclude="ssh_public_key.txt" \
    --exclude="validate_setup.sh" \
    2>/dev/null | grep -v "Binary file" | grep -v "# Search for hardcoded")

if [ -z "$HARDCODED_FILES" ]; then
    print_pass "No hardcoded usernames found in code"
else
    print_warn "Found possible hardcoded usernames in code:"
    echo "$HARDCODED_FILES" | head -5
    print_info "These files should use configuration variables instead"
fi

# 8. Check Makefile targets
print_section "8. Makefile Targets"

MAKE_TARGETS=(
    "install"
    "config"
    "venv"
    "cleanup-env"
    "validate"
)

for target in "${MAKE_TARGETS[@]}"; do
    if make -n "$target" &>/dev/null; then
        print_pass "Makefile target '$target' is valid"
    else
        print_fail "Makefile target '$target' not found"
    fi
done

# 9. Summary
print_section "Validation Summary"

echo ""
echo -e "${BLUE}Results:${NC}"
echo -e "  ${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
echo -e "  ${RED}Failed:${NC} $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    if [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}✅ All validations passed!${NC}"
        echo "The setup is ready for end-to-end testing."
    else
        echo -e "${YELLOW}⚠️  Validation completed with warnings${NC}"
        echo "Review the warnings above before proceeding."
    fi
    echo ""
    echo "Next steps:"
    echo "1. Run 'make cleanup-env' to clean the environment"
    echo "2. Run 'make install' to test the complete setup"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $FAIL_COUNT errors${NC}"
    echo "Please fix the errors above before proceeding."
    exit 1
fi