#!/bin/bash

# ============================================================================
# Fix Connection Pool Configuration
# ============================================================================
# Problem: "Unable to acquire connection" errors due to connection pool exhaustion
#
# Root Causes:
# 1. Default pool size (100) insufficient for enterprise workload
# 2. Short connection timeout (5s) causing premature failures
# 3. No connection leak detection configured
# 4. Health checks consuming connections unnecessarily
#
# Solution: Increase pool size, timeouts, and add leak detection
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
    echo -e "${BLUE}Applying aggressive connection pool settings...${NC}"
    
    # Check if settings already exist
    if grep -q "# Connection Pool Configuration (v14)" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Connection pool settings already exist, updating...${NC}"
        
        # Update existing values
        sed -i.bak 's/datasource_max_active:.*/datasource_max_active: 300  # Increased from default 100/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_min_size:.*/datasource_min_size: 20    # Minimum pool size/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_max_idle:.*/datasource_max_idle: 50     # Maximum idle connections/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_max_wait:.*/datasource_max_wait: 30000  # 30 seconds timeout/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_validation_timeout:.*/datasource_validation_timeout: 5000  # 5 seconds/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_leak_detection_threshold:.*/datasource_leak_detection_threshold: 60000  # 60 seconds/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_connection_timeout:.*/datasource_connection_timeout: 30000  # 30 seconds/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_idle_timeout:.*/datasource_idle_timeout: 600000  # 10 minutes/' "$CONFIG_FILE"
        sed -i.bak 's/datasource_max_lifetime:.*/datasource_max_lifetime: 1800000  # 30 minutes/' "$CONFIG_FILE"
    else
        echo -e "${BLUE}Adding new connection pool settings...${NC}"
        
        # Add new settings
        cat >> "$CONFIG_FILE" << 'EOF'

# Connection Pool Configuration (v14)
# Prevents "Unable to acquire connection" errors under heavy load
datasource_max_active: 300  # Increased from default 100
datasource_min_size: 20    # Minimum pool size
datasource_max_idle: 50     # Maximum idle connections
datasource_max_wait: 30000  # 30 seconds timeout (was 5000ms)
datasource_validation_timeout: 5000  # 5 seconds
datasource_leak_detection_threshold: 60000  # 60 seconds
datasource_connection_timeout: 30000  # 30 seconds
datasource_idle_timeout: 600000  # 10 minutes
datasource_max_lifetime: 1800000  # 30 minutes

# HikariCP specific settings
hikari_minimum_idle: 20
hikari_maximum_pool_size: 300
hikari_connection_timeout: 30000
hikari_idle_timeout: 600000
hikari_max_lifetime: 1800000
hikari_validation_timeout: 5000
hikari_leak_detection_threshold: 60000

# Connection validation
datasource_test_on_borrow: true
datasource_test_while_idle: true
datasource_validation_query: "SELECT 1"
datasource_time_between_eviction_runs_millis: 30000
datasource_min_evictable_idle_time_millis: 60000

# Disable problematic health checks that consume connections
management_health_db_enabled: false
management_health_diskspace_enabled: false
EOF
    fi
    
    # Clean up backup files
    rm -f "$CONFIG_FILE.bak" 2>/dev/null
    
    echo -e "${GREEN}✓ Connection pool settings applied${NC}"
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
        echo -e "${GREEN}With new settings: 300 max connections, 30s timeout${NC}"
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
    echo "  • Max Active Connections: 300 (was 100)"
    echo "  • Min Pool Size: 20 (was 5)"
    echo "  • Connection Timeout: 30s (was 5s)"
    echo "  • Leak Detection: 60s threshold"
    echo "  • Idle Timeout: 10 minutes"
    echo "  • Max Lifetime: 30 minutes"
    echo "  • Health Checks: Disabled (to save connections)"
    echo ""
    echo -e "${GREEN}✓ Connection pool configuration completed${NC}"
}

# Run main function
main "$@"