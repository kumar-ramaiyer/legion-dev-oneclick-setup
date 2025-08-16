#!/bin/bash
set -e

echo "Starting database import..."

# Function to import SQL file
import_sql() {
    local db=$1
    local file=$2
    local desc=$3
    
    if [ -f "/var/lib/mysql-import/$file" ]; then
        echo "Importing $desc into $db..."
        mysql -uroot -p${MYSQL_ROOT_PASSWORD} "$db" < "/var/lib/mysql-import/$file"
        echo "✓ $desc imported successfully"
    else
        echo "WARNING: $file not found, skipping $desc"
    fi
}

# Import legiondb
import_sql "legiondb" "legiondb.sql" "legiondb data"
import_sql "legiondb" "storedprocedures.sql" "stored procedures for legiondb"

# Import legiondb0
import_sql "legiondb0" "legiondb0.sql" "legiondb0 data"
import_sql "legiondb0" "storedprocedures.sql" "stored procedures for legiondb0"

echo "Database import completed!"
