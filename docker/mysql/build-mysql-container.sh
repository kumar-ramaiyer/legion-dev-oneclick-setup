#!/bin/bash
# Build MySQL container with Legion data and push to JFrog
# This script builds once and pushes to JFrog. Other developers just pull.

set -e

# Configuration
REGISTRY="legiontech.jfrog.io"
REPOSITORY="docker-local"
IMAGE_NAME="legion-mysql"
VERSION=$(date +%Y%m%d-%H%M%S)
LATEST_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Legion MySQL Container Build & Push Script           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if image already exists in JFrog
echo -e "${YELLOW}Step 1: Checking if image already exists in JFrog...${NC}"
if docker pull $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG 2>/dev/null; then
    echo -e "${GREEN}✓ Image already exists in JFrog${NC}"
    echo ""
    read -p "Image exists. Do you want to rebuild and push a new version? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Using existing image from JFrog${NC}"
        echo "Pull command: docker pull $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
        exit 0
    fi
fi

# Step 2: Check for database dump files
echo -e "${YELLOW}Step 2: Checking for database dump files...${NC}"

# Check if dbdumps folder is specified
DBDUMPS_FOLDER="${DBDUMPS_FOLDER:-/Users/kumar.ramaiyer/work/dbdumps}"
if [ ! -d "$DBDUMPS_FOLDER" ]; then
    echo -e "${RED}Database dumps folder not found: $DBDUMPS_FOLDER${NC}"
    echo "Please set DBDUMPS_FOLDER environment variable or place files in /Users/kumar.ramaiyer/work/dbdumps"
    exit 1
fi

# Check for required files
REQUIRED_FILES=(
    "storedprocedures.sql"
    "legiondb.sql.zip"
    "legiondb0.sql.zip"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$DBDUMPS_FOLDER/$file" ]; then
        echo -e "${RED}Missing required file: $file${NC}"
        echo "Please download from: https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK"
        exit 1
    fi
done
echo -e "${GREEN}✓ All required files found${NC}"

# Step 3: Prepare build directory
echo -e "${YELLOW}Step 3: Preparing build directory...${NC}"
BUILD_DIR="$(pwd)/build-tmp-$$"
mkdir -p "$BUILD_DIR/data"
mkdir -p "$BUILD_DIR/scripts"

# Copy and extract files
cp "$DBDUMPS_FOLDER/storedprocedures.sql" "$BUILD_DIR/data/"
echo "Extracting legiondb.sql.zip..."
unzip -q "$DBDUMPS_FOLDER/legiondb.sql.zip" -d "$BUILD_DIR/data/"
echo "Extracting legiondb0.sql.zip..."
unzip -q "$DBDUMPS_FOLDER/legiondb0.sql.zip" -d "$BUILD_DIR/data/"

echo -e "${GREEN}✓ Files prepared${NC}"

# Step 4: Create Dockerfile
echo -e "${YELLOW}Step 4: Creating Dockerfile...${NC}"
cat > "$BUILD_DIR/Dockerfile" << 'EOF'
# Legion MySQL with pre-loaded data
FROM mysql:8.0

# Environment variables
ENV MYSQL_ROOT_PASSWORD=mysql123
ENV MYSQL_DATABASE=legiondb

# Copy initialization scripts (run in alphabetical order)
COPY scripts/*.sql /docker-entrypoint-initdb.d/
COPY scripts/*.sh /docker-entrypoint-initdb.d/

# Copy data files
COPY data/*.sql /var/lib/mysql-import/

# Ensure scripts are executable
RUN chmod +x /docker-entrypoint-initdb.d/*.sh || true

# Expose port
EXPOSE 3306

# Add labels
LABEL maintainer="Legion DevOps"
LABEL description="MySQL 8.0 with Legion databases pre-loaded"
LABEL version="${VERSION}"
EOF

# Step 5: Create initialization scripts
echo -e "${YELLOW}Step 5: Creating initialization scripts...${NC}"

# 01 - Create databases and users
cat > "$BUILD_DIR/scripts/01-create-databases.sql" << 'EOF'
-- Set character encoding
SET GLOBAL character_set_server='utf8mb4';
SET GLOBAL collation_server='utf8mb4_general_ci';

-- Create databases
CREATE DATABASE IF NOT EXISTS legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Create users
CREATE USER IF NOT EXISTS 'legion'@'%' IDENTIFIED WITH caching_sha2_password BY 'legionwork';
CREATE USER IF NOT EXISTS 'legionro'@'%' IDENTIFIED WITH caching_sha2_password BY 'legionwork';
CREATE USER IF NOT EXISTS 'legion'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'legionwork';

-- Grant privileges for legiondb
GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON legiondb.* TO 'legionro'@'%';

-- Grant privileges for legiondb0
GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON legiondb0.* TO 'legionro'@'%';

FLUSH PRIVILEGES;
EOF

# 02 - Import data
cat > "$BUILD_DIR/scripts/02-import-data.sh" << 'EOF'
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
EOF

# 03 - Fix collations (using Python script approach)
cat > "$BUILD_DIR/scripts/03-fix-collations.sh" << 'EOF'
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
    
    # Query to generate ALTER TABLE statements (using dynamic collation like original script)
    cursor.execute(f"""
        SELECT CONCAT(
            'ALTER TABLE `', TABLE_NAME, '` CONVERT TO CHARACTER SET utf8mb4 COLLATE ',
            (SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '{database_name}'),
            ';'
        ) AS alter_statement
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '{database_name}'
          AND TABLE_TYPE = 'BASE TABLE'
          AND TABLE_COLLATION != (SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '{database_name}');
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
EOF

# Make scripts executable
chmod +x "$BUILD_DIR/scripts"/*.sh

# Step 6: Build Docker image
echo -e "${YELLOW}Step 6: Building Docker image...${NC}"
cd "$BUILD_DIR"
docker build -t $IMAGE_NAME:$VERSION .
docker tag $IMAGE_NAME:$VERSION $IMAGE_NAME:$LATEST_TAG

echo -e "${GREEN}✓ Docker image built successfully${NC}"

# Step 7: Test the container locally
echo -e "${YELLOW}Step 7: Testing container locally...${NC}"
echo "Starting test container..."
docker run -d --name legion-mysql-test \
    -p 3307:3306 \
    -e MYSQL_ROOT_PASSWORD=mysql123 \
    $IMAGE_NAME:$LATEST_TAG

# Wait for container to be ready
echo "Waiting for MySQL to be ready..."
for i in {1..60}; do
    if docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SELECT 1" >/dev/null 2>&1; then
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Verify databases
echo "Verifying databases..."
DATABASES=$(docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SHOW DATABASES;" 2>/dev/null | grep -E "legiondb|legiondb0" | wc -l)
if [ "$DATABASES" -eq "2" ]; then
    echo -e "${GREEN}✓ Both databases verified${NC}"
    
    # Check table counts
    LEGION_TABLES=$(docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb';" -s 2>/dev/null)
    LEGION0_TABLES=$(docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb0';" -s 2>/dev/null)
    echo "  legiondb: $LEGION_TABLES tables"
    echo "  legiondb0: $LEGION0_TABLES tables"
else
    echo -e "${RED}Database verification failed!${NC}"
    docker logs legion-mysql-test
    docker stop legion-mysql-test && docker rm legion-mysql-test
    exit 1
fi

# Stop test container
docker stop legion-mysql-test && docker rm legion-mysql-test
echo -e "${GREEN}✓ Container test passed${NC}"

# Step 8: Login to JFrog
echo -e "${YELLOW}Step 8: Logging into JFrog...${NC}"
if ! docker login $REGISTRY 2>/dev/null; then
    echo -e "${YELLOW}Please login to JFrog:${NC}"
    docker login $REGISTRY
fi

# Step 9: Tag and push to JFrog
echo -e "${YELLOW}Step 9: Pushing to JFrog...${NC}"
docker tag $IMAGE_NAME:$VERSION $REGISTRY/$REPOSITORY/$IMAGE_NAME:$VERSION
docker tag $IMAGE_NAME:$LATEST_TAG $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG

docker push $REGISTRY/$REPOSITORY/$IMAGE_NAME:$VERSION
docker push $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG

echo -e "${GREEN}✓ Image pushed to JFrog${NC}"

# Step 10: Cleanup
echo -e "${YELLOW}Step 10: Cleaning up...${NC}"
cd ..
rm -rf "$BUILD_DIR"
docker rmi $IMAGE_NAME:$VERSION $IMAGE_NAME:$LATEST_TAG 2>/dev/null || true

# Display summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Build Complete!                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Image Details:${NC}"
echo "  Registry:  $REGISTRY"
echo "  Image:     $REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
echo "  Version:   $VERSION"
echo ""
echo -e "${BLUE}To use this image:${NC}"
echo "  1. In docker-compose.yml:"
echo "     image: $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
echo ""
echo "  2. Pull manually:"
echo "     docker pull $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
echo ""
echo "  3. Run standalone:"
echo "     docker run -d -p 3306:3306 --name legion-mysql \\"
echo "       $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
echo ""
echo -e "${GREEN}✨ MySQL container with Legion data is ready on JFrog!${NC}"