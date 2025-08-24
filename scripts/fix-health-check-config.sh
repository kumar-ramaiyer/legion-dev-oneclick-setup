#!/bin/bash

# ============================================================================
# Fix Health Check Configuration
# ============================================================================
# Problem: "MULTISCHEMA Cannot determine DataSource for null"
# 
# Root Cause: Spring Boot health check tries to use the routing datasource
# without an enterprise context, causing it to fail
#
# Solution: Disable the DB health check for multischema environments
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Fix Health Check Configuration                    ║${NC}"
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
    BACKUP_FILE="$CONFIG_FILE.backup.health_check.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Config backed up to: $BACKUP_FILE${NC}"
}

# Function to apply health check fix
apply_health_check_fix() {
    echo -e "${BLUE}Applying health check configuration fix...${NC}"
    
    # Check if management section exists
    if grep -q "^management:" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Management section found, checking for health settings...${NC}"
        
        # Check if health.db.enabled setting already exists
        if grep -q "management.health.db.enabled" "$CONFIG_FILE" 2>/dev/null || \
           grep -A 10 "^management:" "$CONFIG_FILE" | grep -q "db.enabled" 2>/dev/null; then
            echo -e "${YELLOW}Health DB setting already exists, updating...${NC}"
            # This is complex to update in nested YAML, so we'll add a note
            echo -e "${YELLOW}Note: Please manually verify that management.health.db.enabled is set to false${NC}"
        else
            echo -e "${BLUE}Adding health DB disable setting...${NC}"
            # Find management section and add health configuration
            sed -i.bak '/^management:/a\
  health:\
    db:\
      enabled: false  # Disabled to prevent multischema routing errors' "$CONFIG_FILE"
        fi
    else
        echo -e "${BLUE}Adding new management section with health check fix...${NC}"
        
        # Add new management section at the end of the file
        cat >> "$CONFIG_FILE" << 'EOF'

# Management configuration (v15)
# Disable DB health check to prevent multischema routing errors
management:
  health:
    db:
      enabled: false  # Prevents "Cannot determine DataSource for null" errors
    diskspace:
      enabled: false  # Optional: disable disk space check if not needed
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: always
EOF
    fi
    
    # Clean up backup files
    rm -f "$CONFIG_FILE.bak" 2>/dev/null
    
    echo -e "${GREEN}✓ Health check configuration applied${NC}"
}

# Function to verify the fix in generated config
verify_fix() {
    echo ""
    echo -e "${BLUE}Verifying configuration...${NC}"
    
    local GENERATED_CONFIG="$ENTERPRISE_ROOT/config/target/resources/local/application.yml"
    
    if [ -f "$GENERATED_CONFIG" ]; then
        if grep -q "management:" "$GENERATED_CONFIG" && \
           grep -A 5 "management:" "$GENERATED_CONFIG" | grep -q "enabled.*false"; then
            echo -e "${GREEN}✓ Health check is disabled in generated config${NC}"
        else
            echo -e "${YELLOW}⚠ Generated config may need to be rebuilt${NC}"
            echo "  Run: cd $ENTERPRISE_ROOT && mvn compile -P dev -pl config"
        fi
    else
        echo -e "${YELLOW}Generated config not found. Need to rebuild.${NC}"
    fi
}

# Function to show current issues from logs
analyze_logs() {
    echo ""
    echo -e "${BLUE}Analyzing recent health check issues...${NC}"
    
    if [ -f "$HOME/enterprise.logs.txt" ]; then
        echo -e "${YELLOW}Recent multischema routing errors:${NC}"
        
        # Count multischema errors
        MULTISCHEMA_ERRORS=$(grep -c "MULTISCHEMA Cannot determine DataSource" "$HOME/enterprise.logs.txt" 2>/dev/null || echo "0")
        if [ "$MULTISCHEMA_ERRORS" -gt 0 ]; then
            echo "  - Multischema routing errors: $MULTISCHEMA_ERRORS occurrences"
            echo "    These occur when health checks try to use the routing datasource"
        fi
        
        # Check for health check failures
        HEALTH_FAILURES=$(grep -c "DataSource health check failed" "$HOME/enterprise.logs.txt" 2>/dev/null || echo "0")
        if [ "$HEALTH_FAILURES" -gt 0 ]; then
            echo "  - Health check failures: $HEALTH_FAILURES occurrences"
        fi
        
        echo ""
        echo -e "${GREEN}With this fix:${NC}"
        echo "  • DB health check will be disabled"
        echo "  • Health endpoint will still work but skip DB checks"
        echo "  • No more multischema routing errors from health checks"
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
    echo -e "${BLUE}This script will fix health check configuration issues${NC}"
    echo ""
    
    check_config
    backup_config
    apply_health_check_fix
    analyze_logs
    verify_fix
    
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
    echo "Health Check Settings Applied:"
    echo "  • management.health.db.enabled: false"
    echo "  • This prevents multischema routing errors"
    echo ""
    echo "Note: The health endpoint will still work but will skip DB checks."
    echo "This is normal for multischema environments where the routing"
    echo "datasource requires an enterprise context to function."
    echo ""
    echo -e "${GREEN}✓ Health check configuration completed${NC}"
}

# Run main function
main "$@"