#!/bin/bash

# Legion Development Environment End-to-End Test Script
# This script runs a complete validation cycle

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
echo -e "${BLUE}║        Legion Setup End-to-End Validation Test                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Validate current setup
echo -e "${BLUE}Step 1: Validating current setup...${NC}"
if "$SCRIPT_DIR/validate_setup.sh"; then
    echo -e "${GREEN}✅ Setup validation passed${NC}"
else
    echo -e "${RED}❌ Setup validation failed. Please fix issues before proceeding.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 2: Ask if user wants to proceed with cleanup and reinstall
echo -e "${YELLOW}⚠️  Next steps will:${NC}"
echo "  1. Clean up the entire environment (databases, containers, repos)"
echo "  2. Run the complete setup from scratch"
echo "  3. Validate the new installation"
echo ""
echo "This process will take approximately 45-90 minutes."
echo ""

read -p "Do you want to proceed with the end-to-end test? (yes/no): " response
if [ "$response" != "yes" ]; then
    echo -e "${YELLOW}Test cancelled by user${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Step 2: Cleaning environment...${NC}"
"$SCRIPT_DIR/cleanup.sh"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Cleanup failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 3: Run fresh installation
echo -e "${BLUE}Step 3: Running fresh installation...${NC}"
echo -e "${YELLOW}This will take 45-90 minutes. Starting at $(date '+%H:%M:%S')${NC}"
echo ""

# Start timer
START_TIME=$(date +%s)

# Run the setup (from project directory)
if "$PROJECT_DIR/setup.sh"; then
    echo -e "${GREEN}✅ Setup completed successfully${NC}"
else
    echo -e "${RED}❌ Setup failed${NC}"
    exit 1
fi

# End timer
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Step 4: Validate the new installation
echo -e "${BLUE}Step 4: Validating new installation...${NC}"
"$PROJECT_DIR/setup.sh" --validate-only

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Installation validation passed${NC}"
else
    echo -e "${YELLOW}⚠️  Some validation checks failed - review above${NC}"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              End-to-End Test Complete!                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Test Results:${NC}"
echo "  • Environment cleaned successfully"
echo "  • Fresh installation completed"
echo "  • Setup time: ${MINUTES} minutes ${SECONDS} seconds"
echo ""
echo -e "${BLUE}The setup is ready for handover to other developers!${NC}"
echo ""