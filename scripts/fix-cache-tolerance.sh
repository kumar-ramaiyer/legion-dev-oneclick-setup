#!/bin/bash

# ============================================================================
# Fix Cache Validation Tolerance Issues
# ============================================================================
# Problem: Cache files are being marked as stale too quickly
# Example: "age:132 > tolerance:120" means cache is only 132 seconds old
# but tolerance is set to 120 seconds, causing unnecessary cache rebuilds
#
# Note: These underscore-based properties don't work with the Jinja2 template
# system. This script is kept for documentation purposes but won't fix the
# actual issue. The real fix requires modifying the Java code directly.
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Cache Validation Tolerance Information              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  IMPORTANT NOTE:${NC}"
echo "Cache validation tolerance settings cannot be configured via YAML properties"
echo "because they are not supported by the Jinja2 template system."
echo ""
echo "These issues need to be fixed in the Java code directly by modifying"
echo "the tolerance values in the cache validation logic."
echo ""

# Set paths
LEGION_ROOT="$HOME/Development/legion/code"
ENTERPRISE_ROOT="$LEGION_ROOT/enterprise"

# Function to show current issues from logs
analyze_logs() {
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
        echo -e "${YELLOW}Recommendation:${NC}"
        echo "These tolerance values are hardcoded in the Java cache validation code."
        echo "To fix them, the Java code needs to be modified to either:"
        echo "  1. Increase the hardcoded tolerance values"
        echo "  2. Make them configurable via @Value annotations"
    else
        echo -e "${YELLOW}No log file found at ~/enterprise.logs.txt${NC}"
    fi
}

# Main execution
main() {
    echo ""
    analyze_logs
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                     Summary                                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Cache tolerance issues require Java code changes."
    echo "The tolerance values are hardcoded and cannot be"
    echo "configured via YAML properties at this time."
    echo ""
    echo -e "${YELLOW}This is a known limitation that requires code changes.${NC}"
}

# Run main function
main "$@"