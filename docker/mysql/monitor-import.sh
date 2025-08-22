#!/bin/bash

# Alternative monitoring script for MySQL import progress
# This can be run in a separate terminal to monitor the import

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    # Fallback values if config doesn't exist
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    MYSQL_USER="legion"
    MYSQL_PASSWORD="legionwork"
    MYSQL_IMPORT_CONTAINER="mysql-import"
    LEGIONDB_TABLE_COUNT="913"
    LEGIONDB0_TABLE_COUNT="840"
else
    source "$CONFIG_FILE"
fi

echo -e "${GREEN}MySQL Import Monitor${NC}"
echo "========================"
echo ""

while true; do
    clear
    echo -e "${GREEN}MySQL Import Progress Monitor${NC}"
    echo "=============================="
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Check legiondb
    if docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "USE legiondb" 2>/dev/null; then
        LEGIONDB_TABLES=$(docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb';" 2>/dev/null | tail -1)
        LEGIONDB_SIZE=$(docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='legiondb';" 2>/dev/null | tail -1)
        echo -e "${YELLOW}legiondb:${NC}"
        echo "  Tables: $LEGIONDB_TABLES / $LEGIONDB_TABLE_COUNT"
        echo "  Size: ${LEGIONDB_SIZE} MB"
        
        # Show recently created tables
        echo "  Recent tables:"
        docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT table_name FROM information_schema.tables WHERE table_schema='legiondb' ORDER BY create_time DESC LIMIT 3;" 2>/dev/null | tail -n +2 | sed 's/^/    - /'
    else
        echo -e "${YELLOW}legiondb:${NC} Not yet created"
    fi
    
    echo ""
    
    # Check legiondb0
    if docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "USE legiondb0" 2>/dev/null; then
        LEGIONDB0_TABLES=$(docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb0';" 2>/dev/null | tail -1)
        LEGIONDB0_SIZE=$(docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables WHERE table_schema='legiondb0';" 2>/dev/null | tail -1)
        echo -e "${YELLOW}legiondb0:${NC}"
        echo "  Tables: $LEGIONDB0_TABLES / $LEGIONDB0_TABLE_COUNT"
        echo "  Size: ${LEGIONDB0_SIZE} MB"
        
        # Show recently created tables
        echo "  Recent tables:"
        docker exec $MYSQL_IMPORT_CONTAINER mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT table_name FROM information_schema.tables WHERE table_schema='legiondb0' ORDER BY create_time DESC LIMIT 3;" 2>/dev/null | tail -n +2 | sed 's/^/    - /'
    else
        echo -e "${YELLOW}legiondb0:${NC} Not yet created"
    fi
    
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Check if $MYSQL_IMPORT_CONTAINER container is still running
    if ! docker ps | grep -q $MYSQL_IMPORT_CONTAINER; then
        echo -e "${GREEN}Import complete or container stopped${NC}"
        break
    fi
    
    sleep 5
done