import mysql.connector

# Database connection
conn = mysql.connector.connect(
    host="your_host",
    user="your_user",
    password="your_password",
    database="your_database_name"
)

cursor = conn.cursor()

# Query to generate ALTER TABLE statements
cursor.execute("""
    SELECT CONCAT(
        'ALTER TABLE ', TABLE_NAME, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE ',
        (SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'your_database_name'),
        ';'
    ) AS alter_statement
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'your_database_name'
      AND TABLE_COLLATION != (SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'your_database_name');
""")

# Execute each generated statement
for (alter_statement,) in cursor.fetchall():
    print(f"Executing: {alter_statement}")
    cursor.execute(alter_statement)
    conn.commit()

cursor.close()
conn.close()

print("All tables converted to the default collation.")
