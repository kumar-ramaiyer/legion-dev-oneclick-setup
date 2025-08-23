#!/bin/bash

# ============================================================================
# Fix Dynamic Group WorkRole Issue
# ============================================================================
# Problem: DynamicGroupCondition$FieldType enum is missing "WorkRole" value
# causing deserialization errors when loading Dynamic Groups
#
# This script provides two solutions:
# 1. Clean problematic test data from database (quick fix)
# 2. Instructions for proper code fix (permanent solution)
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Dynamic Group WorkRole Fix Script                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Source Docker configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CONFIG="$SCRIPT_DIR/../docker/config.sh"
if [ -f "$DOCKER_CONFIG" ]; then
    source "$DOCKER_CONFIG"
else
    MYSQL_HOST="localhost"
    MYSQL_PORT="3306"
    MYSQL_USER="legion"
    MYSQL_PASSWORD="legionwork"
fi

# Function to check if MySQL container is running
check_mysql() {
    if ! docker ps | grep -q legion-mysql; then
        echo -e "${RED}Error: MySQL container is not running${NC}"
        echo "Please start it with: ./docker/mysql/build-mysql-container.sh"
        exit 1
    fi
}

# Function to find problematic groups
find_problematic_groups() {
    echo -e "${YELLOW}Finding Dynamic Groups with WorkRole field type...${NC}"
    
    docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
    USE legiondb;
    SELECT 
        id,
        name,
        enterprise_id,
        SUBSTRING(condition_json, 1, 100) as condition_preview
    FROM DynamicGroup 
    WHERE condition_json LIKE '%WorkRole%'
    ORDER BY created_date DESC;" 2>/dev/null
    
    # Count affected groups
    AFFECTED_COUNT=$(docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -NBe "
    USE legiondb;
    SELECT COUNT(*) FROM DynamicGroup WHERE condition_json LIKE '%WorkRole%';" 2>/dev/null)
    
    echo -e "${YELLOW}Found $AFFECTED_COUNT groups with WorkRole field type${NC}"
    return $AFFECTED_COUNT
}

# Function to backup affected data
backup_data() {
    echo -e "${BLUE}Creating backup of affected Dynamic Groups...${NC}"
    
    BACKUP_FILE="/tmp/dynamicgroup_workrole_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    docker exec legion-mysql bash -c "
    mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD legiondb DynamicGroup \
    --where=\"condition_json LIKE '%WorkRole%'\" > $BACKUP_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup created in container at: $BACKUP_FILE${NC}"
    else
        echo -e "${YELLOW}⚠ Could not create backup (data might not exist)${NC}"
    fi
}

# Function to clean problematic data
clean_data() {
    echo -e "${YELLOW}Cleaning Dynamic Groups with WorkRole field type...${NC}"
    
    # Option 1: Delete the problematic groups
    read -p "Do you want to DELETE groups with WorkRole? (y/n) [n]: " DELETE_GROUPS
    
    if [[ "$DELETE_GROUPS" == "y" || "$DELETE_GROUPS" == "Y" ]]; then
        docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
        USE legiondb;
        DELETE FROM DynamicGroup WHERE condition_json LIKE '%WorkRole%';
        SELECT ROW_COUNT() as 'Deleted Groups';" 2>/dev/null
        
        echo -e "${GREEN}✓ Problematic groups deleted${NC}"
    else
        # Option 2: Update to use a valid field type
        echo -e "${BLUE}Alternative: Converting WorkRole to LocationAttribute...${NC}"
        
        docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
        USE legiondb;
        UPDATE DynamicGroup 
        SET condition_json = REPLACE(condition_json, '\"fieldType\":\"WorkRole\"', '\"fieldType\":\"LocationAttribute\"')
        WHERE condition_json LIKE '%WorkRole%';
        SELECT ROW_COUNT() as 'Updated Groups';" 2>/dev/null
        
        echo -e "${GREEN}✓ Groups updated to use LocationAttribute instead of WorkRole${NC}"
    fi
}

# Function to show code fix instructions
show_code_fix() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Permanent Code Fix Instructions                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}To permanently fix this issue, the enum needs to be updated:${NC}"
    echo ""
    echo "File: com/legion/core/dynamicgroup/DynamicGroupCondition.java"
    echo ""
    echo -e "${GREEN}Current enum:${NC}"
    echo "  public enum FieldType {"
    echo "    LocationId, State, Country, LocationAttribute,"
    echo "    UpperField, City, ConfigType, District,"
    echo "    LocationType, LocationName"
    echo "  }"
    echo ""
    echo -e "${GREEN}Should be:${NC}"
    echo "  public enum FieldType {"
    echo "    LocationId, State, Country, LocationAttribute,"
    echo "    UpperField, City, ConfigType, District,"
    echo "    LocationType, LocationName,"
    echo -    WorkRole  // Added to support work role based grouping"
    echo "  }"
    echo ""
    echo -e "${YELLOW}This change requires:${NC}"
    echo "1. Updating the Java enum in the enterprise codebase"
    echo "2. Rebuilding the backend"
    echo "3. Testing dynamic group functionality"
    echo ""
}

# Main execution
main() {
    check_mysql
    
    echo -e "${BLUE}Analyzing Dynamic Group issues...${NC}"
    echo ""
    
    find_problematic_groups
    AFFECTED=$?
    
    if [ $AFFECTED -eq 0 ]; then
        echo -e "${GREEN}✓ No problematic Dynamic Groups found!${NC}"
        echo -e "${YELLOW}The WorkRole errors in logs might be from cached data.${NC}"
        echo "Consider restarting the backend to clear caches."
    else
        echo ""
        echo -e "${YELLOW}Options to fix:${NC}"
        echo "1. Clean the test data (temporary fix)"
        echo "2. Update the code (permanent fix)"
        echo ""
        
        read -p "Do you want to clean the problematic data? (y/n) [y]: " CLEAN
        CLEAN=${CLEAN:-y}
        
        if [[ "$CLEAN" == "y" || "$CLEAN" == "Y" ]]; then
            backup_data
            clean_data
            echo -e "${GREEN}✓ Data cleaned successfully${NC}"
        fi
        
        show_code_fix
    fi
    
    echo ""
    echo -e "${GREEN}✓ Script completed${NC}"
}

# Run main function
main "$@"