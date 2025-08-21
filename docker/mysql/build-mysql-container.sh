#!/bin/bash

# Legion MySQL Container Builder
# This script builds a MySQL 8.0 container with Legion databases pre-loaded
# Usage: DBDUMPS_FOLDER=/path/to/dbdumps ./build-mysql-container.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="legion-mysql"
VERSION="8.0-legion-v2"
LATEST_TAG="latest"
CONTAINER_NAME="legion-mysql"

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=8

# Progress functions
start_step() {
    CURRENT_STEP=$1
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ Step $CURRENT_STEP/$TOTAL_STEPS: $2${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

end_step() {
    echo -e "${GREEN}✓ Step $1 completed${NC}"
}

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Legion MySQL Container Builder v2.0                   ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  This script builds a MySQL 8.0 container with:             ║${NC}"
echo -e "${GREEN}║  • legiondb database (913 tables)                           ║${NC}"
echo -e "${GREEN}║  • legiondb0 database (840 tables)                          ║${NC}"
echo -e "${GREEN}║  • All stored procedures                                    ║${NC}"
echo -e "${GREEN}║  • Proper user permissions                                  ║${NC}"
echo -e "${GREEN}║  • EnterpriseSchema table configured                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Stop and clean existing containers
start_step 1 "Cleaning up existing containers and volumes"

# Stop existing container if running
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "Stopping existing container..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    echo -e "${GREEN}✓ Container removed${NC}"
fi

# Remove the old volume if it exists (IMPORTANT: data is in image, not volume)
if docker volume ls | grep -q "docker_mysql-data"; then
    echo "Removing old volume docker_mysql-data..."
    docker volume rm docker_mysql-data 2>/dev/null || true
    echo -e "${GREEN}✓ Volume removed${NC}"
fi

end_step 1

# Step 2: Validate database dumps
start_step 2 "Validating database dumps"

# Check for DBDUMPS_FOLDER environment variable or ask for it
if [ -z "$DBDUMPS_FOLDER" ]; then
    echo -e "${YELLOW}Database dumps folder required!${NC}"
    echo ""
    echo "This folder should contain:"
    echo "  • legiondb.sql.zip (5.6GB) - Main database with 913 tables"
    echo "  • legiondb0.sql.zip (306MB) - System database with 840 tables"  
    echo "  • storedprocedures.sql (67KB) - Stored procedures and functions"
    echo ""
    echo "To set up:"
    echo "  1. Create folder: mkdir -p ~/work/dbdumps"
    echo "  2. Get files from team (check Slack or Google Drive)"
    echo "  3. Place all three files in the folder"
    echo ""
    echo -e "${BLUE}Default path: /Users/kumar.ramaiyer/work/dbdumps${NC}"
    read -p "Enter path (or press Enter for default): " user_input
    
    if [ -z "$user_input" ]; then
        DBDUMPS_FOLDER="/Users/kumar.ramaiyer/work/dbdumps"
    else
        DBDUMPS_FOLDER="$user_input"
    fi
fi

# Expand tilde if present
DBDUMPS_FOLDER="${DBDUMPS_FOLDER/#\~/$HOME}"
echo "Using dbdumps folder: $DBDUMPS_FOLDER"

if [ ! -d "$DBDUMPS_FOLDER" ]; then
    echo -e "${RED}Database dumps folder not found: $DBDUMPS_FOLDER${NC}"
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
        exit 1
    fi
done
echo -e "${GREEN}✓ All required files found${NC}"
end_step 2

# Step 3: Prepare build directory
start_step 3 "Preparing build directory"
BUILD_DIR="$(pwd)/build-tmp-$$"
rm -rf "$BUILD_DIR" 2>/dev/null || true
mkdir -p "$BUILD_DIR/data"

# Extract database dumps
echo "Extracting legiondb.sql.zip..."
unzip -q "$DBDUMPS_FOLDER/legiondb.sql.zip" -d "$BUILD_DIR/data/"
echo "Extracting legiondb0.sql.zip..."
unzip -q "$DBDUMPS_FOLDER/legiondb0.sql.zip" -d "$BUILD_DIR/data/"
cp "$DBDUMPS_FOLDER/storedprocedures.sql" "$BUILD_DIR/data/"

echo -e "${GREEN}✓ Files prepared${NC}"
end_step 3

# Step 4: Create import script
start_step 4 "Creating database import script"

cat > "$BUILD_DIR/import-data.sh" << 'IMPORT_SCRIPT'
#!/bin/bash
set -e

echo "=== Starting MySQL for data import ==="

# Initialize MySQL data directory
mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

# Start MySQL in background
mysqld --user=mysql --datadir=/var/lib/mysql \
    --skip-networking \
    --socket=/var/run/mysqld/mysqld.sock &

# Wait for MySQL to be ready
echo "Waiting for MySQL to start..."
for i in {1..30}; do
    if mysqladmin ping -h localhost --socket=/var/run/mysqld/mysqld.sock --silent; then
        break
    fi
    sleep 1
done

echo "=== MySQL started, beginning import ==="

# Set root password
mysql --socket=/var/run/mysqld/mysqld.sock << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY 'mysql123';
FLUSH PRIVILEGES;
EOF

# Create databases
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock << EOF
SET GLOBAL character_set_server='utf8mb4';
SET GLOBAL collation_server='utf8mb4_general_ci';
SET GLOBAL max_allowed_packet=1073741824;
SET GLOBAL sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

CREATE USER IF NOT EXISTS 'legion'@'%' IDENTIFIED BY 'legionwork';
CREATE USER IF NOT EXISTS 'legion'@'localhost' IDENTIFIED BY 'legionwork';
CREATE USER IF NOT EXISTS 'legionro'@'%' IDENTIFIED BY 'legionwork';

GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON legiondb.* TO 'legionro'@'%';

GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON legiondb0.* TO 'legionro'@'%';

FLUSH PRIVILEGES;
EOF

echo "=== Importing legiondb database ==="
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock legiondb < /tmp/import/legiondb.sql

echo "=== Importing legiondb0 database ==="
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock legiondb0 < /tmp/import/legiondb0.sql

echo "=== Importing stored procedures to legiondb ==="
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock legiondb < /tmp/import/storedprocedures.sql

echo "=== Importing stored procedures to legiondb0 ==="
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock legiondb0 < /tmp/import/storedprocedures.sql

echo "=== Creating/Updating EnterpriseSchema table ==="
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock << 'EOF'
-- Drop and recreate EnterpriseSchema with correct structure
DROP TABLE IF EXISTS legiondb.EnterpriseSchema;
DROP TABLE IF EXISTS legiondb0.EnterpriseSchema;

CREATE TABLE legiondb.EnterpriseSchema (
    id bigint not null auto_increment,
    objectId varchar(36),
    active bit not null default 1,
    createdBy varchar(50),
    createdDate datetime(6) default CURRENT_TIMESTAMP(6),
    lastModifiedBy varchar(50),
    lastModifiedDate datetime(6) default CURRENT_TIMESTAMP(6) on update CURRENT_TIMESTAMP(6),
    timeCreated bigint not null default 0,
    timeUpdated bigint not null default 0,
    enterpriseId varchar(36) not null,
    schemaKey varchar(255) not null,
    primary key (id),
    UNIQUE KEY ESCHUnique1 (enterpriseId, schemaKey)
) engine=InnoDB;

CREATE TABLE legiondb0.EnterpriseSchema (
    id bigint not null auto_increment,
    objectId varchar(36),
    active bit not null default 1,
    createdBy varchar(50),
    createdDate datetime(6) default CURRENT_TIMESTAMP(6),
    lastModifiedBy varchar(50),
    lastModifiedDate datetime(6) default CURRENT_TIMESTAMP(6) on update CURRENT_TIMESTAMP(6),
    timeCreated bigint not null default 0,
    timeUpdated bigint not null default 0,
    enterpriseId varchar(36) not null,
    schemaKey varchar(255) not null,
    primary key (id),
    UNIQUE KEY ESCHUnique1 (enterpriseId, schemaKey)
) engine=InnoDB;

-- Insert default mappings for local development
INSERT INTO legiondb.EnterpriseSchema (objectId, enterpriseId, schemaKey, active, createdDate, lastModifiedDate) 
VALUES 
(UUID(), '1', 'legiondb', 1, NOW(), NOW()),
(UUID(), '1', 'default', 1, NOW(), NOW());

INSERT INTO legiondb0.EnterpriseSchema (objectId, enterpriseId, schemaKey, active, createdDate, lastModifiedDate) 
VALUES 
(UUID(), '1', 'legiondb0', 1, NOW(), NOW()),
(UUID(), '1', 'default', 1, NOW(), NOW());

-- If Enterprise table exists, populate from it
SET @enterprise_exists = (SELECT COUNT(*) FROM information_schema.tables 
                          WHERE table_schema = 'legiondb0' AND table_name = 'Enterprise');

SET @sql = IF(@enterprise_exists > 0,
    'INSERT IGNORE INTO legiondb0.EnterpriseSchema(objectId, active, createdDate, enterpriseId, schemaKey, lastModifiedDate)
     SELECT UUID(), 1, NOW(), objectId, "legiondb", NOW() FROM legiondb0.Enterprise',
    'SELECT "Enterprise table not found, skipping population"');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
EOF

echo "=== Verifying import ==="
mysql -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock << EOF
SELECT 'legiondb' as db, COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb';
SELECT 'legiondb0' as db, COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb0';
SELECT 'EnterpriseSchema in legiondb' as tbl, COUNT(*) as row_count FROM legiondb.EnterpriseSchema;
SELECT 'EnterpriseSchema in legiondb0' as tbl, COUNT(*) as row_count FROM legiondb0.EnterpriseSchema;
EOF

echo "=== Shutting down MySQL ==="
mysqladmin -uroot -pmysql123 --socket=/var/run/mysqld/mysqld.sock shutdown

echo "=== Data import completed successfully ==="
IMPORT_SCRIPT

chmod +x "$BUILD_DIR/import-data.sh"
end_step 4

# Step 5: Create Dockerfile
start_step 5 "Creating Dockerfile"

cat > "$BUILD_DIR/Dockerfile" << 'DOCKERFILE'
FROM mysql:8.0

# Install unzip for processing zip files
RUN microdnf install -y unzip && microdnf clean all

# Copy import data
COPY data/*.sql /tmp/import/
COPY import-data.sh /tmp/import-data.sh

# Run import during build
RUN /tmp/import-data.sh && rm -rf /tmp/import*

# MySQL configuration
ENV MYSQL_ROOT_PASSWORD=mysql123

# Add custom config
RUN echo "[mysqld]" > /etc/mysql/conf.d/legion.cnf && \
    echo "sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION" >> /etc/mysql/conf.d/legion.cnf && \
    echo "character-set-server=utf8mb4" >> /etc/mysql/conf.d/legion.cnf && \
    echo "collation-server=utf8mb4_unicode_ci" >> /etc/mysql/conf.d/legion.cnf && \
    echo "max_connections=200" >> /etc/mysql/conf.d/legion.cnf && \
    echo "max_allowed_packet=1024M" >> /etc/mysql/conf.d/legion.cnf && \
    echo "innodb_buffer_pool_size=1G" >> /etc/mysql/conf.d/legion.cnf && \
    echo "innodb_redo_log_capacity=512M" >> /etc/mysql/conf.d/legion.cnf

EXPOSE 3306

LABEL maintainer="Legion DevOps"
LABEL description="MySQL 8.0 with Legion databases pre-loaded"
LABEL version="8.0-legion-v2"
DOCKERFILE

end_step 5

# Step 6: Build Docker image
start_step 6 "Building Docker image (this will take ~20-30 minutes)"

cd "$BUILD_DIR"
docker build -t $IMAGE_NAME:$VERSION . --no-cache

# Tag as latest
docker tag $IMAGE_NAME:$VERSION $IMAGE_NAME:$LATEST_TAG

echo -e "${GREEN}✓ Docker image built successfully${NC}"
end_step 6

# Step 7: Clean up build directory
start_step 7 "Cleaning up"
cd ..
rm -rf "$BUILD_DIR"
end_step 7

# Step 8: Deploy the new container
start_step 8 "Deploying MySQL container"

# Start the new container using docker-compose
cd "$(dirname "$0")/.."
docker-compose up -d mysql

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
for i in {1..30}; do
    if docker exec $CONTAINER_NAME mysql -ulegion -plegionwork -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ MySQL is ready${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Verify the deployment
echo ""
echo "=== Verifying deployment ==="
docker exec $CONTAINER_NAME mysql -ulegion -plegionwork -e "
    SELECT 'legiondb tables' as info, COUNT(*) as count FROM information_schema.tables WHERE table_schema='legiondb'
    UNION ALL
    SELECT 'legiondb0 tables', COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb0'
    UNION ALL  
    SELECT 'EnterpriseSchema rows in legiondb', COUNT(*) FROM legiondb.EnterpriseSchema
    UNION ALL
    SELECT 'EnterpriseSchema rows in legiondb0', COUNT(*) FROM legiondb0.EnterpriseSchema;"

end_step 8

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    BUILD COMPLETED!                          ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  MySQL container is running with:                           ║${NC}"
echo -e "${GREEN}║  • Host: localhost                                          ║${NC}"
echo -e "${GREEN}║  • Port: 3306                                               ║${NC}"
echo -e "${GREEN}║  • User: legion                                             ║${NC}"
echo -e "${GREEN}║  • Password: legionwork                                     ║${NC}"
echo -e "${GREEN}║  • Databases: legiondb (913 tables), legiondb0 (840 tables) ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""