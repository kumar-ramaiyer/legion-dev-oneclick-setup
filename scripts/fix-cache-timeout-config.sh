#!/bin/bash

# ============================================================================
# Fix Cache Timeout Configuration  
# ============================================================================
# Problems:
# 1. "PLT_TASK cache for enterprise X is not ready after 10 minutes"
# 2. "PLT_CACHE age:132 > tolerance:120" causing unnecessary cache rebuilds
# 3. Cache bootstrap timeout too short for large enterprises
#
# Solution: Increase all cache-related timeouts to 60 minutes
#
# Impact: Prevents cache timeout errors and reduces unnecessary rebuilds
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
    if grep -q "# Cache Timeout Configuration (v14)" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Cache timeout settings already exist, updating...${NC}"
        
        # Update existing values
        sed -i.bak 's/cache_bootstrap_timeout:.*/cache_bootstrap_timeout: 60  # 60 minutes for large enterprises/' "$CONFIG_FILE"
        sed -i.bak 's/scheduled_task_cache_timeout:.*/scheduled_task_cache_timeout: 60  # Match bootstrap timeout/' "$CONFIG_FILE"
        sed -i.bak 's/cache_validation_tolerance_seconds:.*/cache_validation_tolerance_seconds: 600  # 10 minutes/' "$CONFIG_FILE"
        sed -i.bak 's/cache_s3_age_tolerance:.*/cache_s3_age_tolerance: 3600  # 1 hour for S3/' "$CONFIG_FILE"
    else
        echo -e "${BLUE}Adding new cache timeout settings...${NC}"
        
        # Add new settings
        cat >> "$CONFIG_FILE" << 'EOF'

# Cache Timeout Configuration (v14)
# Prevents cache timeout errors and unnecessary rebuilds
cache_bootstrap_timeout: 60  # 60 minutes for large enterprises (was 10)
scheduled_task_cache_timeout: 60  # Match bootstrap timeout
plt_task_cache_timeout: 60  # Platform task cache timeout

# Cache Validation Tolerance Settings
# Prevents "age > tolerance" errors causing unnecessary rebuilds
cache_validation_tolerance_seconds: 600  # 10 minutes (was 120 seconds)
cache_s3_age_tolerance: 3600            # 1 hour for S3 cached files
cache_stale_check_interval: 300         # Check every 5 minutes
cache_force_refresh_after: 7200         # Force refresh after 2 hours

# Individual cache type tolerances (in seconds)
cache_tolerance_employee: 600           # Employee cache
cache_tolerance_engagement: 600         # Engagement cache  
cache_tolerance_workerbadge: 300        # Worker badge cache (5 min)
cache_tolerance_assignmentrule: 1200    # Assignment rule cache (20 min)
cache_tolerance_dynamicgroup: 900       # Dynamic group cache (15 min)
cache_tolerance_template: 1800          # Template cache (30 min)
cache_tolerance_location: 600           # Location cache
cache_tolerance_enterprise: 1800        # Enterprise cache (30 min)

# Cache externalization settings (S3)
cache_externalize_enabled: true         # Enable S3 externalization
cache_externalize_min_size: 1024        # Min size in KB to externalize
cache_externalize_compression: true     # Enable compression
cache_externalize_s3_bucket: legion-cache  # S3 bucket for cache

# Cache warming settings
cache_warm_on_startup: true             # Warm caches on startup
cache_warm_parallel_threads: 4          # Parallel threads for warming
cache_warm_retry_attempts: 3            # Retry attempts for warming
cache_warm_retry_delay: 5000            # Delay between retries (ms)
EOF
    fi
    
    # Clean up backup files
    rm -f "$CONFIG_FILE.bak" 2>/dev/null
    
    echo -e "${GREEN}✓ Cache timeout settings applied${NC}"
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
                echo "    Enterprise: $ENTERPRISE"
            done
        fi
        
        # Check for cache validation tolerance errors
        echo ""
        echo -e "${YELLOW}Recent cache tolerance violations:${NC}"
        grep "age:.* > tolerance:" "$HOME/enterprise.logs.txt" 2>/dev/null | tail -5 | while read line; do
            if [[ $line =~ age:([0-9]+).*tolerance:([0-9]+) ]]; then
                AGE="${BASH_REMATCH[1]}"
                TOLERANCE="${BASH_REMATCH[2]}"
                CACHE_TYPE=$(echo "$line" | grep -oP 'PLT_CACHE \K[^/]+' | head -1)
                echo "  - Cache: $CACHE_TYPE, Age: ${AGE}s, Tolerance: ${TOLERANCE}s (exceeded by $((AGE-TOLERANCE))s)"
            fi
        done
        
        echo ""
        echo -e "${GREEN}With new settings:${NC}"
        echo "  • Bootstrap timeout: 60 minutes (was 10)"
        echo "  • Validation tolerance: 600 seconds (was 120)"
        echo "  • Individual cache tolerances: 300-1800 seconds"
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
    echo -e "${BLUE}This script will fix cache timeout and tolerance issues${NC}"
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
    echo "Cache Settings Applied:"
    echo "  • Bootstrap Timeout: 60 minutes (was 10)"
    echo "  • PLT_TASK Timeout: 60 minutes"
    echo "  • Validation Tolerance: 600 seconds (was 120)"
    echo "  • S3 Age Tolerance: 3600 seconds"
    echo "  • Individual Cache Tolerances: 300-1800 seconds"
    echo "  • Cache Warming: Enabled with 4 threads"
    echo ""
    echo -e "${GREEN}✓ Cache timeout configuration completed${NC}"
}

# Run main function
main "$@"