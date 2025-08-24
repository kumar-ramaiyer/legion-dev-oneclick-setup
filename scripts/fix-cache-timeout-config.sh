#!/bin/bash

# ============================================================================
# Fix Cache Timeout Configuration  
# ============================================================================
# Problems:
# 1. "PLT_TASK cache for enterprise X is not ready after 10 minutes"
# 2. Cache bootstrap timeout hardcoded in Java code
#
# Solution: 
# 1. Add scheduled_task_cache_timeout property to config (60 minutes)
# 2. Java code already modified to read this property
#
# Impact: Prevents cache timeout errors for large enterprises
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Cache Timeout Configuration Fix                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Set paths
LEGION_ROOT="${LEGION_ROOT:-$HOME/Development/legion/code}"
ENTERPRISE_ROOT="$LEGION_ROOT/enterprise"
CONFIG_FILE="$ENTERPRISE_ROOT/config/src/main/resources/templates/application/local/local.values.yml"

# Function to check if config file exists
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
        echo "Please ensure the enterprise repository is cloned"
        exit 1
    fi
    echo -e "${GREEN}✓ Config file found${NC}"
}

# Function to backup config
backup_config() {
    BACKUP_FILE="$CONFIG_FILE.backup.cache_timeout.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Config backed up to: $BACKUP_FILE${NC}"
}

# Function to apply cache timeout settings
apply_cache_timeout_settings() {
    echo -e "${BLUE}Applying cache timeout settings...${NC}"
    
    # Check if settings already exist
    if grep -q "scheduled_task_cache_timeout:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Cache timeout setting already exists, updating...${NC}"
        
        # Update existing value
        sed -i.bak 's/scheduled_task_cache_timeout:.*/scheduled_task_cache_timeout: 60  # Cache timeout in minutes for scheduled tasks/' "$CONFIG_FILE"
    else
        echo -e "${BLUE}Adding new cache timeout setting...${NC}"
        
        # Add new setting at the end of the file
        cat >> "$CONFIG_FILE" << 'EOF'

# Custom configuration for scheduled task cache timeout (v15)
# This property is read by EnterpriseScheduledTaskManager using @Value annotation
scheduled_task_cache_timeout: 60  # Cache timeout in minutes for scheduled tasks
EOF
    fi
    
    # Clean up backup files
    rm -f "$CONFIG_FILE.bak" 2>/dev/null
    
    echo -e "${GREEN}✓ Cache timeout setting applied${NC}"
}

# Function to show current cache issues from logs
analyze_logs() {
    echo ""
    echo -e "${BLUE}Analyzing recent cache timeout issues...${NC}"
    
    if [ -f "$HOME/enterprise.logs.txt" ]; then
        echo -e "${YELLOW}Recent cache timeout errors:${NC}"
        
        # Check for PLT_TASK cache timeout errors
        PLT_ERRORS=$(grep -c "PLT_TASK cache.*is not ready after" "$HOME/enterprise.logs.txt" 2>/dev/null || echo "0")
        if [ "$PLT_ERRORS" -gt 0 ]; then
            echo "  - PLT_TASK cache timeouts: $PLT_ERRORS occurrences"
            grep "PLT_TASK cache.*is not ready after" "$HOME/enterprise.logs.txt" | tail -2 | while read line; do
                ENTERPRISE=$(echo "$line" | grep -oP 'enterprise \K[a-f0-9-]+' | head -1)
                if [ ! -z "$ENTERPRISE" ]; then
                    echo "    Enterprise: $ENTERPRISE"
                fi
            done
        fi
        
        echo ""
        echo -e "${GREEN}With new setting:${NC}"
        echo "  • Cache bootstrap timeout: 60 minutes (was hardcoded 10)"
    else
        echo -e "${YELLOW}No log file found at ~/enterprise.logs.txt${NC}"
    fi
}

# Function to rebuild config
rebuild_config() {
    echo ""
    echo -e "${BLUE}Rebuilding application configuration...${NC}"
    
    cd "$ENTERPRISE_ROOT"
    mvn compile -P dev -pl config > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Configuration rebuilt successfully${NC}"
        echo -e "${YELLOW}Note: Restart the backend for changes to take effect${NC}"
    else
        echo -e "${RED}✗ Configuration rebuild failed${NC}"
        echo "Run manually: cd $ENTERPRISE_ROOT && mvn compile -P dev -pl config"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}This script will fix cache timeout issues${NC}"
    echo ""
    
    check_config
    backup_config
    apply_cache_timeout_settings
    analyze_logs
    
    echo ""
    read -p "Do you want to rebuild the configuration now? (y/n) [y]: " REBUILD
    REBUILD=${REBUILD:-y}
    
    if [[ "$REBUILD" == "y" || "$REBUILD" == "Y" ]]; then
        rebuild_config
    else
        echo -e "${YELLOW}Skipping rebuild. Run this when ready:${NC}"
        echo "  cd $ENTERPRISE_ROOT && mvn compile -P dev -pl config"
    fi
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  Configuration Summary                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Cache Setting Applied:"
    echo "  • scheduled_task_cache_timeout: 60 minutes"
    echo ""
    echo "Note: The Java code has been modified to read this property"
    echo "instead of using a hardcoded 10-minute timeout."
    echo ""
    echo -e "${GREEN}✓ Cache timeout configuration completed${NC}"
}

# Run main function
main "$@"