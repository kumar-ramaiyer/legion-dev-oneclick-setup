#!/bin/bash

# ============================================================================
# Fix Missing Badge Column Issue
# ============================================================================
# Problem: "Unknown column 'badge0_.isExpirationDateRequired' in 'field list'"
# 
# Root Cause: Flyway migration V50_38.0.1745841392574__SchemaUpdate.sql 
# didn't execute properly
#
# Solution: Manually add the missing column to both schemas
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Fix Missing Badge Column                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if MySQL container is running
check_mysql() {
    if ! docker ps | grep -q legion-mysql; then
        echo -e "${RED}Error: MySQL container 'legion-mysql' is not running${NC}"
        echo "Please start MySQL first: docker start legion-mysql"
        exit 1
    fi
    echo -e "${GREEN}✓ MySQL container is running${NC}"
}

# Function to execute SQL in a schema
execute_sql() {
    local SCHEMA=$1
    local SQL=$2
    local DESC=$3
    
    echo -e "${BLUE}Executing in $SCHEMA: $DESC${NC}"
    
    docker exec -i legion-mysql mysql -ulegion -plegionwork "$SCHEMA" -e "$SQL" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success in $SCHEMA${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ May already exist or error in $SCHEMA${NC}"
        return 1
    fi
}

# Function to check if column exists
check_column_exists() {
    local SCHEMA=$1
    local TABLE=$2
    local COLUMN=$3
    
    local EXISTS=$(docker exec -i legion-mysql mysql -ulegion -plegionwork "$SCHEMA" -e \
        "SELECT COUNT(*) FROM information_schema.COLUMNS 
         WHERE TABLE_SCHEMA='$SCHEMA' 
         AND TABLE_NAME='$TABLE' 
         AND COLUMN_NAME='$COLUMN';" -sN 2>/dev/null)
    
    if [ "$EXISTS" = "1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to add the missing column
add_badge_column() {
    local SCHEMA=$1
    
    echo ""
    echo -e "${BLUE}Processing schema: $SCHEMA${NC}"
    echo -e "${BLUE}────────────────────────────────${NC}"
    
    # Check if Badge table exists
    local TABLE_EXISTS=$(docker exec -i legion-mysql mysql -ulegion -plegionwork "$SCHEMA" -e \
        "SELECT COUNT(*) FROM information_schema.TABLES 
         WHERE TABLE_SCHEMA='$SCHEMA' AND TABLE_NAME='Badge';" -sN 2>/dev/null)
    
    if [ "$TABLE_EXISTS" != "1" ]; then
        echo -e "${YELLOW}⚠ Badge table doesn't exist in $SCHEMA, skipping...${NC}"
        return
    fi
    
    # Check if column already exists
    if check_column_exists "$SCHEMA" "Badge" "isExpirationDateRequired"; then
        echo -e "${GREEN}✓ Column 'isExpirationDateRequired' already exists in $SCHEMA.Badge${NC}"
        return
    fi
    
    # Add the column using AddColumnWithType stored procedure
    echo -e "${BLUE}Adding column 'isExpirationDateRequired' to Badge table...${NC}"
    
    # First try using the stored procedure if it exists
    local SP_EXISTS=$(docker exec -i legion-mysql mysql -ulegion -plegionwork "$SCHEMA" -e \
        "SELECT COUNT(*) FROM information_schema.ROUTINES 
         WHERE ROUTINE_SCHEMA='$SCHEMA' 
         AND ROUTINE_NAME='AddColumnWithType';" -sN 2>/dev/null)
    
    if [ "$SP_EXISTS" = "1" ]; then
        # Use stored procedure
        execute_sql "$SCHEMA" \
            "CALL AddColumnWithType('Badge', 'isExpirationDateRequired', 'bit');" \
            "Adding column via stored procedure"
    else
        # Direct ALTER TABLE
        echo -e "${YELLOW}Stored procedure not found, using direct ALTER TABLE...${NC}"
        execute_sql "$SCHEMA" \
            "ALTER TABLE Badge ADD COLUMN isExpirationDateRequired BIT DEFAULT 0;" \
            "Adding column via ALTER TABLE"
    fi
    
    # Verify the column was added
    if check_column_exists "$SCHEMA" "Badge" "isExpirationDateRequired"; then
        echo -e "${GREEN}✓ Column successfully added to $SCHEMA.Badge${NC}"
        
        # Set default value for existing rows
        execute_sql "$SCHEMA" \
            "UPDATE Badge SET isExpirationDateRequired = 0 WHERE isExpirationDateRequired IS NULL;" \
            "Setting default values"
    else
        echo -e "${RED}✗ Failed to add column to $SCHEMA.Badge${NC}"
    fi
}

# Function to check and update flyway_schema_history
update_flyway_history() {
    local SCHEMA=$1
    
    echo ""
    echo -e "${BLUE}Checking Flyway history in $SCHEMA...${NC}"
    
    # Check if the migration is already recorded
    local MIGRATION_EXISTS=$(docker exec -i legion-mysql mysql -ulegion -plegionwork "$SCHEMA" -e \
        "SELECT COUNT(*) FROM flyway_schema_history 
         WHERE script LIKE '%V50_38.0.1745841392574__SchemaUpdate%';" -sN 2>/dev/null || echo "0")
    
    if [ "$MIGRATION_EXISTS" = "0" ]; then
        echo -e "${YELLOW}Migration not recorded in Flyway history${NC}"
        echo -e "${BLUE}Adding migration record to prevent re-execution...${NC}"
        
        # Add the migration record
        execute_sql "$SCHEMA" \
            "INSERT INTO flyway_schema_history 
             (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) 
             VALUES 
             ((SELECT COALESCE(MAX(installed_rank), 0) + 1 FROM flyway_schema_history fsh), 
              '50.38.0.1745841392574', 'SchemaUpdate', 'SQL', 
              'V50_38.0.1745841392574__SchemaUpdate.sql', 
              NULL, 'manual_fix', NOW(), 0, 1);" \
            "Recording migration in Flyway history"
    else
        echo -e "${GREEN}✓ Migration already recorded in Flyway history${NC}"
    fi
}

# Function to verify the fix
verify_fix() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Verification                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for SCHEMA in legiondb0 legiondb; do
        echo -e "${BLUE}Checking $SCHEMA:${NC}"
        
        # Show Badge table structure
        echo "  Badge table columns:"
        docker exec -i legion-mysql mysql -ulegion -plegionwork "$SCHEMA" -e \
            "SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT 
             FROM information_schema.COLUMNS 
             WHERE TABLE_SCHEMA='$SCHEMA' AND TABLE_NAME='Badge' 
             AND COLUMN_NAME='isExpirationDateRequired';" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓ Column exists in $SCHEMA${NC}"
        else
            echo -e "${RED}  ✗ Column missing in $SCHEMA${NC}"
        fi
    done
}

# Main execution
main() {
    echo -e "${BLUE}This script will fix the missing Badge.isExpirationDateRequired column${NC}"
    echo -e "${BLUE}in both system (legiondb0) and enterprise (legiondb) schemas${NC}"
    echo ""
    
    check_mysql
    
    # Process both schemas
    add_badge_column "legiondb0"
    add_badge_column "legiondb"
    
    # Update Flyway history
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Updating Flyway History                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    update_flyway_history "legiondb0"
    update_flyway_history "legiondb"
    
    # Verify the fix
    verify_fix
    
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                       Summary                                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Actions completed:"
    echo "  • Added isExpirationDateRequired column to Badge table"
    echo "  • Updated both legiondb0 (system) and legiondb (enterprise) schemas"
    echo "  • Recorded migration in Flyway history to prevent re-execution"
    echo ""
    echo -e "${GREEN}✓ Badge column fix completed${NC}"
    echo ""
    echo -e "${YELLOW}Note: If you continue to see errors, you may need to:${NC}"
    echo "  1. Restart the backend application"
    echo "  2. Clear any cached JPA metadata"
    echo "  3. Check for other missing migrations"
}

# Run main function
main "$@"