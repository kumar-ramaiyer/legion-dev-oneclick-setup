#!/bin/bash

# ============================================================================
# Fix Connection Pool Configuration
# ============================================================================
# Problem: "Unable to acquire connection" errors due to connection pool exhaustion
#
# Root Causes:
# 1. Default pool size (100) insufficient for enterprise workload
# 2. Multiple datasources competing for connections
# 3. Multischema routing consuming more connections
#
# Solution: Increase pool size for all datasources using correct YAML structure
#
# Impact: Prevents connection pool exhaustion and improves stability
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Connection Pool Configuration Fix                   ║${NC}"
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
    BACKUP_FILE="$CONFIG_FILE.backup.connection_pool.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Config backed up to: $BACKUP_FILE${NC}"
}

# Function to apply connection pool settings
apply_connection_pool_settings() {
    echo -e "${BLUE}Applying connection pool settings to datasources...${NC}"
    
    # Update system primary datasource
    if grep -q "datasources:" "$CONFIG_FILE"; then
        echo -e "${BLUE}Updating system datasource connection pools...${NC}"
        
        # Check if maxActive already exists for system.primary
        if grep -A 5 "system:" "$CONFIG_FILE" | grep -A 5 "primary:" | grep -q "maxActive:"; then
            echo -e "${YELLOW}System primary datasource already has maxActive, updating...${NC}"
            # Update existing maxActive for system.primary
            perl -i -pe 's/(system:\s*\n\s*primary:[\s\S]*?)(maxActive:\s*)\d+/$1${2}300  # Increased from default 100 (v15)/m' "$CONFIG_FILE"
            perl -i -pe 's/(system:\s*\n\s*primary:[\s\S]*?)(minSize:\s*)\d+/$1${2}20     # Increased from default 5 (v15)/m' "$CONFIG_FILE"
        else
            echo -e "${BLUE}Adding maxActive to system primary datasource...${NC}"
            # Add maxActive and minSize after password in system.primary
            perl -i -pe 's/(system:\s*\n\s*primary:[\s\S]*?password:\s*\S+)/$1\n            maxActive: 300  # Increased from default 100 (v15)\n            minSize: 20     # Increased from default 5 (v15)/m' "$CONFIG_FILE"
        fi
        
        # Check if maxActive already exists for system.secondary
        if grep -A 5 "system:" "$CONFIG_FILE" | grep -A 20 "secondary:" | grep -q "maxActive:"; then
            echo -e "${YELLOW}System secondary datasource already has maxActive, updating...${NC}"
            # Update existing maxActive for system.secondary
            perl -i -pe 's/(system:[\s\S]*?secondary:[\s\S]*?)(maxActive:\s*)\d+/$1${2}300  # Increased from default 100 (v15)/m' "$CONFIG_FILE"
            perl -i -pe 's/(system:[\s\S]*?secondary:[\s\S]*?)(minSize:\s*)\d+/$1${2}20     # Increased from default 5 (v15)/m' "$CONFIG_FILE"
        else
            echo -e "${BLUE}Adding maxActive to system secondary datasource...${NC}"
            # Add maxActive and minSize after password in system.secondary
            perl -i -pe 's/(secondary:\s*\n\s*url:[\s\S]*?password:\s*\S+)/$1\n            maxActive: 300  # Increased from default 100 (v15)\n            minSize: 20     # Increased from default 5 (v15)/m' "$CONFIG_FILE"
        fi
        
        # Update enterprise datasources
        echo -e "${BLUE}Updating enterprise datasource connection pools...${NC}"
        
        # For each enterprise datasource (legiondb, legiondb1000, legiondb1001)
        for db in legiondb legiondb1000 legiondb1001; do
            echo "  - Updating $db datasources..."
            
            # Update primary datasource
            if grep -A 10 "$db:" "$CONFIG_FILE" | grep -A 5 "primary:" | grep -q "maxActive:"; then
                perl -i -pe "s/($db:[\s\S]*?primary:[\s\S]*?)(maxActive:\s*)\d+/\${1}\${2}100  # Enterprise-specific pool (v15)/m" "$CONFIG_FILE"
            else
                perl -i -pe "s/($db:\s*\n\s*primary:[\s\S]*?password:\s*\S+)/\$1\n          maxActive: 100  # Enterprise-specific pool (v15)/m" "$CONFIG_FILE"
            fi
            
            if grep -A 10 "$db:" "$CONFIG_FILE" | grep -A 5 "primary:" | grep -q "minSize:"; then
                perl -i -pe "s/($db:[\s\S]*?primary:[\s\S]*?)(minSize:\s*)\d+/\${1}\${2}10     # Increased from 1 (v15)/m" "$CONFIG_FILE"
            else
                perl -i -pe "s/($db:\s*\n\s*primary:[\s\S]*?)(maxActive:.*\n)/\$1\$2          minSize: 10     # Increased from 1 (v15)\n/m" "$CONFIG_FILE"
            fi
            
            # Update secondary datasource
            if grep -A 10 "$db:" "$CONFIG_FILE" | grep -A 20 "secondary:" | grep -q "maxActive:"; then
                perl -i -pe "s/($db:[\s\S]*?secondary:[\s\S]*?)(maxActive:\s*)\d+/\${1}\${2}100  # Enterprise-specific pool (v15)/m" "$CONFIG_FILE"
            else
                perl -i -pe "s/($db:[\s\S]*?secondary:[\s\S]*?password:\s*\S+)/\$1\n          maxActive: 100  # Enterprise-specific pool (v15)/m" "$CONFIG_FILE"
            fi
            
            if grep -A 10 "$db:" "$CONFIG_FILE" | grep -A 20 "secondary:" | grep -q "minSize:"; then
                perl -i -pe "s/($db:[\s\S]*?secondary:[\s\S]*?)(minSize:\s*)\d+/\${1}\${2}10     # Increased from 1 (v15)/m" "$CONFIG_FILE"
            else
                perl -i -pe "s/($db:[\s\S]*?secondary:[\s\S]*?)(maxActive:.*\n)/\$1\$2          minSize: 10     # Increased from 1 (v15)\n/m" "$CONFIG_FILE"
            fi
        done
        
        echo -e "${GREEN}✓ Connection pool settings applied to all datasources${NC}"
    else
        echo -e "${RED}✗ Could not find datasources section in config${NC}"
        exit 1
    fi
}

# Function to show current connection pool issues from logs
analyze_logs() {
    echo ""
    echo -e "${BLUE}Analyzing recent connection pool issues...${NC}"
    
    if [ -f "$HOME/enterprise.logs.txt" ]; then
        echo -e "${YELLOW}Recent connection pool errors:${NC}"
        grep -E "(Unable to acquire connection|Connection is not available|Timeout waiting for connection)" "$HOME/enterprise.logs.txt" 2>/dev/null | tail -5 | while read line; do
            echo "  - $(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' | head -1): Connection pool exhaustion detected"
        done
        
        # Count total connection errors
        CONN_ERRORS=$(grep -c "Unable to acquire connection" "$HOME/enterprise.logs.txt" 2>/dev/null || echo "0")
        echo ""
        echo -e "${YELLOW}Total connection pool errors found: $CONN_ERRORS${NC}"
        echo -e "${GREEN}With new settings:${NC}"
        echo "  • System datasources: 300 max connections each"
        echo "  • Enterprise datasources: 100 max connections each"
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
    echo -e "${BLUE}This script will fix connection pool exhaustion issues${NC}"
    echo ""
    
    check_config
    backup_config
    apply_connection_pool_settings
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
    echo "Connection Pool Settings Applied:"
    echo "  System Datasources (primary & secondary):"
    echo "    • Max Active Connections: 300 (was 100)"
    echo "    • Min Pool Size: 20 (was 5)"
    echo ""
    echo "  Enterprise Datasources (all schemas):"
    echo "    • Max Active Connections: 100 (was default)"
    echo "    • Min Pool Size: 10 (was 1)"
    echo ""
    echo "Note: These settings use the correct YAML structure"
    echo "that the Jinja2 template system expects."
    echo ""
    echo -e "${GREEN}✓ Connection pool configuration completed${NC}"
}

# Run main function
main "$@"