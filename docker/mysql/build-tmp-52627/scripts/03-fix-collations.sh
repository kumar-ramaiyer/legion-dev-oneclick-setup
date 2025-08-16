#!/bin/bash
set -e

echo "Fixing collation mismatches..."

# Install Python MySQL connector
pip3 install mysql-connector-python

# Create Python script for collation fixes
cat > /tmp/fix_collations.py << 'PYTHON_EOF'
import mysql.connector
import sys

def fix_database_collation(database_name):
    print(f"Fixing collations for {database_name}...")
    
    # Database connection
    conn = mysql.connector.connect(
        host="localhost",
        user="root",
        password="mysql123",
        database=database_name
    )
    
    cursor = conn.cursor()
    
    # Query to generate ALTER TABLE statements
    cursor.execute(f"""
        SELECT CONCAT(
            'ALTER TABLE `', TABLE_NAME, '` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'
        ) AS alter_statement
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '{database_name}'
          AND TABLE_TYPE = 'BASE TABLE'
          AND TABLE_COLLATION != 'utf8mb4_general_ci';
    """)
    
    # Execute each generated statement
    alter_statements = cursor.fetchall()
    for (alter_statement,) in alter_statements:
        print(f"Executing: {alter_statement}")
        try:
            cursor.execute(alter_statement)
            conn.commit()
        except Exception as e:
            print(f"Warning: {e}")
            continue
    
    cursor.close()
    conn.close()
    print(f"✓ Collations fixed for {database_name}")

# Fix both databases
fix_database_collation("legiondb")
fix_database_collation("legiondb0")

print("All collation fixes completed!")
PYTHON_EOF

# Run the Python script
python3 /tmp/fix_collations.py

# Insert Enterprise Schema from legiondb to legiondb0 (as per README)
echo "Copying Enterprise Schema..."
mysql -uroot -pmysql123 << 'SQL'
INSERT IGNORE INTO legiondb0.EnterpriseSchema 
SELECT * FROM legiondb.EnterpriseSchema;
SQL

echo "Database setup completed!"
