#!/bin/bash

# Script to fix failed Flyway migrations
# Based on developer guidance: mark failed migrations as successful to unblock

echo "Checking for failed Flyway migrations..."

# Check failed migrations
docker exec legion-mysql mysql -ulegion -plegionwork -e "
SELECT version, script, installed_on 
FROM legiondb.flyway_schema_history 
WHERE success = 0
ORDER BY installed_rank DESC;" 2>/dev/null

echo ""
read -p "Do you want to mark all failed migrations as successful? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Marking failed migrations as successful..."
    
    docker exec legion-mysql mysql -ulegion -plegionwork -e "
    -- Mark all failed migrations as successful
    UPDATE legiondb.flyway_schema_history 
    SET success = 1 
    WHERE success = 0;
    
    SELECT 'Updated' as status, ROW_COUNT() as migrations_fixed;
    " 2>/dev/null
    
    echo ""
    echo "Done! You can now restart the application."
    echo "Note: The actual migration changes may not have been applied."
    echo "      You may need to manually apply them or wait for developers to fix the ordering."
else
    echo "Cancelled. No changes made."
fi