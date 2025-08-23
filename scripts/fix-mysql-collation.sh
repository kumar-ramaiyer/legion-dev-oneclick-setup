#!/bin/bash

# ============================================================================
# Fix MySQL Collation Issues (Comprehensive)
# ============================================================================
# Problem: "Illegal mix of collations (utf8mb4_general_ci,IMPLICIT) and 
#          (utf8mb4_0900_ai_ci,IMPLICIT) for operation '='"
# 
# Root Cause: MySQL 8.0 defaults to utf8mb4_0900_ai_ci collation while our
#             database uses utf8mb4_general_ci. Tables created by Flyway 
#             migrations inherit the wrong collation.
#
# Solution: Convert all tables AND columns to utf8mb4_general_ci
# 
# Impact: Fixes JPA query failures in:
#         - AccrualTypeMigrateTask
#         - OAuth2 operations  
#         - Enterprise data queries
#         - DynamicGroup operations
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              MySQL Collation Fix Script                      ║${NC}"
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

# Function to fix database-level collation
fix_database_collation() {
    echo -e "${BLUE}Setting database-level collation...${NC}"
    
    docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
    ALTER DATABASE legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    ALTER DATABASE legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    SELECT 'Database collation updated' as status;
    " 2>&1 | grep -v "Warning"
}

# Function to fix critical tables
fix_critical_tables() {
    echo -e "${BLUE}Converting critical tables to utf8mb4_general_ci...${NC}"
    
    # List of critical tables that commonly have collation issues
    CRITICAL_TABLES=(
        "Enterprise"
        "EnterpriseSchema"
        "LocationAttribute"
        "DynamicGroup"
        "DynamicGroupAssociation"
        "AccrualType"
        "EmployeeAttribute"
        "ExternalEmployee"
        "flyway_schema_history"
    )
    
    for table in "${CRITICAL_TABLES[@]}"; do
        echo -e "${YELLOW}Converting table: $table${NC}"
        docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD legiondb -e "
        ALTER TABLE $table CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
        " 2>/dev/null && echo -e "${GREEN}✓ $table converted${NC}" || echo -e "${YELLOW}⚠ $table not found or already converted${NC}"
    done
}

# Function to fix all tables in a database
fix_all_tables() {
    local database=$1
    echo -e "${BLUE}Converting all tables in $database...${NC}"
    
    docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD << EOF
USE $database;

DROP PROCEDURE IF EXISTS ConvertAllTablesToGeneralCI;
DELIMITER $$
CREATE PROCEDURE ConvertAllTablesToGeneralCI()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tableName VARCHAR(255);
    DECLARE cur CURSOR FOR 
        SELECT TABLE_NAME 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = '$database'
        AND TABLE_TYPE = 'BASE TABLE';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO tableName;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        SET @sql = CONCAT('ALTER TABLE \`', tableName, '\` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci');
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    
    CLOSE cur;
END$$
DELIMITER ;

CALL ConvertAllTablesToGeneralCI();
DROP PROCEDURE ConvertAllTablesToGeneralCI;

SELECT CONCAT('Tables converted in $database: ', COUNT(*)) as status
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = '$database'
AND TABLE_TYPE = 'BASE TABLE';
EOF
}

# Function to verify collation
verify_collation() {
    echo ""
    echo -e "${BLUE}Verifying collation fixes...${NC}"
    
    docker exec $CONTAINER_NAME mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
    SELECT 
        'Tables with wrong collation in legiondb' as check_type,
        COUNT(*) as count
    FROM information_schema.TABLES 
    WHERE TABLE_SCHEMA = 'legiondb' 
    AND TABLE_COLLATION = 'utf8mb4_0900_ai_ci'
    UNION ALL
    SELECT 
        'Tables with wrong collation in legiondb0' as check_type,
        COUNT(*) as count
    FROM information_schema.TABLES 
    WHERE TABLE_SCHEMA = 'legiondb0' 
    AND TABLE_COLLATION = 'utf8mb4_0900_ai_ci';
    " 2>&1 | grep -v "Warning"
}

# Main execution
main() {
    check_container
    
    echo ""
    echo -e "${YELLOW}This will fix MySQL collation issues to prevent query failures${NC}"
    echo ""
    
    # Fix database-level collation
    fix_database_collation
    
    # Fix critical tables first (faster)
    fix_critical_tables
    
    # Optionally fix all tables (slower but comprehensive)
    read -p "Do you want to convert ALL tables (slower but comprehensive)? (y/n) [n]: " FIX_ALL
    FIX_ALL=${FIX_ALL:-n}
    
    if [[ "$FIX_ALL" == "y" || "$FIX_ALL" == "Y" ]]; then
        fix_all_tables "legiondb"
        fix_all_tables "legiondb0"
    fi
    
    # Verify the fixes
    verify_collation
    
    echo ""
    echo -e "${GREEN}✓ Collation fix completed${NC}"
    echo -e "${YELLOW}Note: Restart the backend if it's running for changes to take full effect${NC}"
}

# Run main function
main