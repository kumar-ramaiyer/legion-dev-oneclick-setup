#!/bin/bash

# ============================================================================
# Fix Cache Validation Tolerance Issues
# ============================================================================
# Problem: Cache files are being marked as stale too quickly
# Example: "age:132 > tolerance:120" means cache is only 132 seconds old
# but tolerance is set to 120 seconds, causing unnecessary cache rebuilds
#
# Solution: Increase cache validation tolerances in configuration
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Cache Validation Tolerance Fix Script               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Set paths
LEGION_ROOT="$HOME/Development/legion/code"
ENTERPRISE_ROOT="$LEGION_ROOT/enterprise"
CONFIG_FILE="$ENTERPRISE_ROOT/config/src/main/resources/templates/application/local/local.values.yml"

# Function to check if config file exists
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
        echo "Please ensure the enterprise repository is cloned"
        exit 1
    fi
}

# Function to backup config
backup_config() {
    BACKUP_FILE="$CONFIG_FILE.backup.cache_tolerance.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Config backed up to: $BACKUP_FILE${NC}"
}

# Function to add cache tolerance settings
add_cache_tolerance() {
    echo -e "${BLUE}Adding cache validation tolerance settings...${NC}"
    
    # Check if cache tolerance settings already exist
    if grep -q "cache_validation_tolerance" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Cache tolerance settings already exist, updating...${NC}"
        
        # Update existing values
        sed -i.bak 's/cache_validation_tolerance_seconds:.*/cache_validation_tolerance_seconds: 600  # 10 minutes (v14)/' "$CONFIG_FILE"
        sed -i.bak 's/cache_s3_age_tolerance:.*/cache_s3_age_tolerance: 3600  # 1 hour (v14)/' "$CONFIG_FILE"
    else
        echo -e "${BLUE}Adding new cache tolerance settings...${NC}"
        
        # Add new settings
        cat >> "$CONFIG_FILE" << 'EOF'

# Cache Validation Tolerance Settings (v14)
# Prevents excessive cache rebuilds due to stale validation
cache_validation_tolerance_seconds: 600  # 10 minutes (was 120 seconds)
cache_s3_age_tolerance: 3600            # 1 hour for S3 cached files
cache_stale_check_interval: 300         # Check every 5 minutes
cache_force_refresh_after: 7200         # Force refresh after 2 hours

# Individual cache tolerances (in seconds)
cache_tolerance_employee: 600           # Employee cache
cache_tolerance_engagement: 600         # Engagement cache  
cache_tolerance_workerbadge: 300        # Worker badge cache (5 min)
cache_tolerance_assignmentrule: 1200    # Assignment rule cache (20 min)
cache_tolerance_dynamicgroup: 900       # Dynamic group cache (15 min)
cache_tolerance_template: 1800          # Template cache (30 min)

# S3 cache externalization settings
cache_externalize_enabled: true         # Enable S3 externalization
cache_externalize_min_size: 1024        # Min size in KB to externalize
cache_externalize_compression: true     # Enable compression
EOF
    fi
    
    # Clean up backup files
    rm -f "$CONFIG_FILE.bak" 2>/dev/null
    
    echo -e "${GREEN}✓ Cache tolerance settings added/updated${NC}"
}

# Function to show current issues from logs
analyze_logs() {
    echo ""
    echo -e "${BLUE}Analyzing recent cache validation issues...${NC}"
    
    if [ -f "$HOME/enterprise.logs.txt" ]; then
        echo -e "${YELLOW}Recent cache tolerance violations:${NC}"
        grep "age:.* > tolerance:" "$HOME/enterprise.logs.txt" | tail -5 | while read line; do
            # Extract the age and tolerance values
            if [[ $line =~ age:([0-9]+).*tolerance:([0-9]+) ]]; then
                AGE="${BASH_REMATCH[1]}"
                TOLERANCE="${BASH_REMATCH[2]}"
                CACHE_TYPE=$(echo "$line" | grep -oP 'PLT_CACHE \K[^/]+' | head -1)
                echo "  - Cache: $CACHE_TYPE, Age: ${AGE}s, Tolerance: ${TOLERANCE}s (exceeded by $((AGE-TOLERANCE))s)"
            fi
        done
        
        echo ""
        echo -e "${GREEN}With new settings, these caches will have 600s (10 min) tolerance${NC}"
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
    echo -e "${BLUE}This script will fix cache validation tolerance issues${NC}"
    echo ""
    
    check_config
    backup_config
    add_cache_tolerance
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
    echo -e "${BLUE}║                     Additional Notes                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1. Cache tolerance increased from 2 minutes to 10 minutes"
    echo "2. S3 externalized cache tolerance set to 1 hour"
    echo "3. Individual cache types have customized tolerances"
    echo "4. Restart backend after config rebuild for changes to apply"
    echo ""
    echo -e "${GREEN}✓ Script completed${NC}"
}

# Run main function
main "$@"