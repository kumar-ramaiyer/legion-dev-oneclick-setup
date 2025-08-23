#!/bin/bash

# Simple script to mark all failed migrations as successful
# Per developer: "mark the column success as 1 to proceed to unblock"

echo "Marking all failed Flyway migrations as successful..."

# Mark all failed migrations in legiondb
docker exec legion-mysql mysql -ulegion -plegionwork -e "
USE legiondb;

-- Show failed migrations before fixing
SELECT 'Failed migrations before fix:' as status;
SELECT version, script FROM flyway_schema_history WHERE success = 0;

-- Mark all as successful
UPDATE flyway_schema_history 
SET success = 1 
WHERE success = 0;

-- Show result
SELECT 'Migrations fixed:' as status, ROW_COUNT() as count;

-- Verify no more failures
SELECT 'Failed migrations after fix:' as status, COUNT(*) as count 
FROM flyway_schema_history WHERE success = 0;
" 2>&1 | grep -v "Warning"

echo ""
echo "Done! All failed migrations marked as successful."
echo "You can now restart the application and Flyway will skip these migrations."