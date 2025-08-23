#!/bin/bash

# ============================================================================
# Fix Dynamic Group WorkRole Database Issues
# ============================================================================
# Problem: DynamicGroupCondition$FieldType enum is missing "WorkRole" value
#          causing deserialization errors when loading Dynamic Groups
#
# Solution: Update database to replace WorkRole with LocationAttribute
#           (a valid enum value that serves similar purpose)
#
# Impact: Fixes "No enum constant FieldType.WorkRole" errors
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Dynamic Group WorkRole Database Fix                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Accept container name as parameter, default to legion-mysql
CONTAINER_NAME=${1:-legion-mysql}
MYSQL_USER=${MYSQL_USER:-legion}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-legionwork}

# Function to check if container exists and is running
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo -e "${RED}Error: Container $CONTAINER_NAME is not running${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Container $CONTAINER_NAME is running${NC}"
}

# Function to find problematic groups
find_problematic_groups() {
    echo -e "${YELLOW}Searching for Dynamic Groups with WorkRole field type...${NC}"
    
    # Check legiondb
    AFFECTED_LEGIONDB=$(docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -NBe "
    USE legiondb;
    SELECT COUNT(*) FROM DynamicGroup 
    WHERE basicCondition LIKE '%WorkRole%' 
    OR advancedCondition LIKE '%WorkRole%';" 2>/dev/null || echo "0")
    
    # Check legiondb0
    AFFECTED_LEGIONDB0=$(docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -NBe "
    USE legiondb0;
    SELECT COUNT(*) FROM DynamicGroup 
    WHERE basicCondition LIKE '%WorkRole%' 
    OR advancedCondition LIKE '%WorkRole%';" 2>/dev/null || echo "0")
    
    echo -e "${YELLOW}Found $AFFECTED_LEGIONDB groups in legiondb${NC}"
    echo -e "${YELLOW}Found $AFFECTED_LEGIONDB0 groups in legiondb0${NC}"
    
    TOTAL_AFFECTED=$((AFFECTED_LEGIONDB + AFFECTED_LEGIONDB0))
    return $TOTAL_AFFECTED
}

# Function to backup affected data
backup_affected_data() {
    echo -e "${BLUE}Creating backup of affected Dynamic Groups...${NC}"
    
    BACKUP_FILE="/tmp/dynamicgroup_workrole_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    # Backup from legiondb
    docker exec $CONTAINER_NAME bash -c "
    mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD legiondb DynamicGroup \
    --where=\"basicCondition LIKE '%WorkRole%' OR advancedCondition LIKE '%WorkRole%'\" > $BACKUP_FILE.legiondb 2>/dev/null" || true
    
    # Backup from legiondb0
    docker exec $CONTAINER_NAME bash -c "
    mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD legiondb0 DynamicGroup \
    --where=\"basicCondition LIKE '%WorkRole%' OR advancedCondition LIKE '%WorkRole%'\" > $BACKUP_FILE.legiondb0 2>/dev/null" || true
    
    echo -e "${GREEN}✓ Backups created in container at:${NC}"
    echo "  - $BACKUP_FILE.legiondb"
    echo "  - $BACKUP_FILE.legiondb0"
}

# Function to fix WorkRole references
fix_workrole_references() {
    echo -e "${BLUE}Replacing WorkRole with LocationAttribute...${NC}"
    
    # Fix in legiondb
    echo -e "${YELLOW}Fixing legiondb...${NC}"
    docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
    USE legiondb;
    
    -- Update basicCondition
    UPDATE DynamicGroup 
    SET basicCondition = REPLACE(basicCondition, '\"fieldType\":\"WorkRole\"', '\"fieldType\":\"LocationAttribute\"')
    WHERE basicCondition LIKE '%WorkRole%';
    
    -- Update advancedCondition
    UPDATE DynamicGroup 
    SET advancedCondition = REPLACE(advancedCondition, '\"fieldType\":\"WorkRole\"', '\"fieldType\":\"LocationAttribute\"')
    WHERE advancedCondition LIKE '%WorkRole%';
    
    SELECT ROW_COUNT() as 'Rows updated in legiondb';
    " 2>&1 | grep -v "Warning"
    
    # Fix in legiondb0
    echo -e "${YELLOW}Fixing legiondb0...${NC}"
    docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
    USE legiondb0;
    
    -- Update basicCondition
    UPDATE DynamicGroup 
    SET basicCondition = REPLACE(basicCondition, '\"fieldType\":\"WorkRole\"', '\"fieldType\":\"LocationAttribute\"')
    WHERE basicCondition LIKE '%WorkRole%';
    
    -- Update advancedCondition
    UPDATE DynamicGroup 
    SET advancedCondition = REPLACE(advancedCondition, '\"fieldType\":\"WorkRole\"', '\"fieldType\":\"LocationAttribute\"')
    WHERE advancedCondition LIKE '%WorkRole%';
    
    SELECT ROW_COUNT() as 'Rows updated in legiondb0';
    " 2>&1 | grep -v "Warning"
}

# Function to verify the fix
verify_fix() {
    echo ""
    echo -e "${BLUE}Verifying the fix...${NC}"
    
    # Check if any WorkRole references remain
    REMAINING_LEGIONDB=$(docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -NBe "
    USE legiondb;
    SELECT COUNT(*) FROM DynamicGroup 
    WHERE basicCondition LIKE '%WorkRole%' 
    OR advancedCondition LIKE '%WorkRole%';" 2>/dev/null || echo "0")
    
    REMAINING_LEGIONDB0=$(docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -NBe "
    USE legiondb0;
    SELECT COUNT(*) FROM DynamicGroup 
    WHERE basicCondition LIKE '%WorkRole%' 
    OR advancedCondition LIKE '%WorkRole%';" 2>/dev/null || echo "0")
    
    if [ "$REMAINING_LEGIONDB" -eq 0 ] && [ "$REMAINING_LEGIONDB0" -eq 0 ]; then
        echo -e "${GREEN}✓ All WorkRole references have been fixed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some WorkRole references remain:${NC}"
        echo "  - legiondb: $REMAINING_LEGIONDB"
        echo "  - legiondb0: $REMAINING_LEGIONDB0"
        return 1
    fi
}

# Main execution
main() {
    check_container
    
    echo ""
    echo -e "${YELLOW}This will fix Dynamic Group WorkRole enum issues${NC}"
    echo ""
    
    # Find problematic groups
    find_problematic_groups
    TOTAL_AFFECTED=$?
    
    if [ $TOTAL_AFFECTED -eq 0 ]; then
        echo -e "${GREEN}✓ No problematic Dynamic Groups found!${NC}"
        echo -e "${YELLOW}The WorkRole errors in logs might be from cached data.${NC}"
        echo "Consider restarting the backend to clear caches."
    else
        echo ""
        echo -e "${YELLOW}Found $TOTAL_AFFECTED groups that need fixing${NC}"
        
        # Backup the data
        backup_affected_data
        
        # Apply the fix
        fix_workrole_references
        
        # Verify the fix
        verify_fix
    fi
    
    echo ""
    echo -e "${GREEN}✓ Dynamic Group WorkRole fix completed${NC}"
    echo ""
    echo -e "${BLUE}Note:${NC}"
    echo "- This is a temporary fix that replaces WorkRole with LocationAttribute"
    echo "- For a permanent fix, the Java enum needs to be updated in the codebase"
    echo "- File: com/legion/core/dynamicgroup/DynamicGroupCondition.java"
    echo "- Add 'WorkRole' to the FieldType enum"
}

# Run main function
main