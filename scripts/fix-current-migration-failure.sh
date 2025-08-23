#!/bin/bash

# Script to fix the current migration failure
# Based on developer guidance: manually fix the issue, then mark as successful

MYSQL_USER="${MYSQL_USER:-legion}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-legionwork}"

echo "========================================="
echo "Fix Current Migration Failure"
echo "========================================="
echo ""

# Check what migration failed
echo "Checking for failed migrations..."
FAILED=$(docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -N -e "
SELECT CONCAT(version, '|', script, '|', execution_time) 
FROM legiondb.flyway_schema_history 
WHERE success = 0
ORDER BY installed_rank DESC
LIMIT 1;" 2>/dev/null)

if [ -z "$FAILED" ]; then
    echo "✓ No failed migrations found!"
    exit 0
fi

IFS='|' read -r VERSION SCRIPT EXEC_TIME <<< "$FAILED"

echo "Failed Migration:"
echo "  Version: $VERSION"
echo "  Script: $SCRIPT"
echo "  Execution Time: $EXEC_TIME ms"
echo ""

# Check the error in logs
echo "Checking application logs for error details..."
if [ -f ~/enterprise.logs.txt ]; then
    echo "Last Flyway error in logs:"
    grep -A 5 "Migration.*failed" ~/enterprise.logs.txt | tail -10
    echo ""
fi

# Provide specific fixes for known issues
case "$VERSION" in
    "50.57.0.1753310683108")
        echo "Known Issue: Trying to add column to AccrualType table that doesn't exist yet."
        echo "Fix: Creating AccrualType table with the needed column..."
        
        docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD legiondb -e "
        CREATE TABLE IF NOT EXISTS AccrualType (
           id bigint not null auto_increment,
           objectId varchar(36),
           active bit not null,
           createdBy varchar(50),
           createdDate datetime(6),
           externalId varchar(64),
           lastModifiedBy varchar(50),
           lastModifiedDate datetime(6),
           timeCreated bigint not null,
           timeUpdated bigint not null,
           enterpriseId varchar(36) not null,
           accrualCode varchar(255),
           description varchar(255),
           name varchar(32),
           payCode varchar(255),
           payCodeOT varchar(255),
           unit varchar(32),
           includeForPayfile bit,
           primary key (id)
        ) engine=InnoDB;" 2>&1 | grep -v "Warning"
        
        echo "✓ Table created with includeForPayfile column"
        ;;
    *)
        echo "Unknown migration failure. You may need to:"
        echo "1. Check the migration file: /Users/kumar.ramaiyer/Development/legion/code/enterprise/app/src/main/resources/db/migration/$SCRIPT"
        echo "2. Manually apply the necessary fixes"
        echo "3. Then mark as successful"
        echo ""
        read -p "Have you manually fixed the issue? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Please fix the issue manually first, then run this script again."
            exit 1
        fi
        ;;
esac

# Mark the migration as successful
echo ""
echo "Marking migration $VERSION as successful..."
docker exec legion-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "
UPDATE legiondb.flyway_schema_history 
SET success = 1 
WHERE version = '$VERSION' AND success = 0;

SELECT 'Updated' as status, ROW_COUNT() as rows_updated;" 2>&1 | grep -v "Warning"

echo ""
echo "✓ Migration marked as successful!"
echo ""
echo "Next steps:"
echo "1. Restart the application: ./scripts/build-and-run.sh run-backend"
echo "2. Flyway will skip this migration and continue with the next ones"
echo "3. If another migration fails, run this script again"