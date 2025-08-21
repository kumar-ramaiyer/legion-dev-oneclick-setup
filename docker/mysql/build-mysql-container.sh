#!/bin/bash

# Legion MySQL Container Builder
# This script builds a MySQL 8.0 container with Legion databases pre-loaded
# Usage: ./build-mysql-container.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="legion-mysql"
VERSION="8.0-legion-v3"
LATEST_TAG="latest"
CONTAINER_NAME="legion-mysql"

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=7

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
echo -e "${GREEN}║        Legion MySQL Container Builder v3.0                   ║${NC}"
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

# Remove the old volume if it exists
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
    echo -e "${BLUE}Default path: ~/work/dbdumps${NC}"
    read -p "Enter path (or press Enter for default): " user_input
    
    if [ -z "$user_input" ]; then
        DBDUMPS_FOLDER="$HOME/work/dbdumps"
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
mkdir -p "$BUILD_DIR/docker-entrypoint-initdb.d"

# Extract database dumps
echo "Extracting legiondb.sql.zip..."
unzip -q "$DBDUMPS_FOLDER/legiondb.sql.zip" -d "$BUILD_DIR/docker-entrypoint-initdb.d/"
mv "$BUILD_DIR/docker-entrypoint-initdb.d/legiondb.sql" "$BUILD_DIR/docker-entrypoint-initdb.d/02-legiondb.sql"

echo "Extracting legiondb0.sql.zip..."
unzip -q "$DBDUMPS_FOLDER/legiondb0.sql.zip" -d "$BUILD_DIR/docker-entrypoint-initdb.d/"
mv "$BUILD_DIR/docker-entrypoint-initdb.d/legiondb0.sql" "$BUILD_DIR/docker-entrypoint-initdb.d/03-legiondb0.sql"

# Copy stored procedures
cp "$DBDUMPS_FOLDER/storedprocedures.sql" "$BUILD_DIR/docker-entrypoint-initdb.d/04-storedprocedures-legiondb.sql"
cp "$DBDUMPS_FOLDER/storedprocedures.sql" "$BUILD_DIR/docker-entrypoint-initdb.d/05-storedprocedures-legiondb0.sql"

echo -e "${GREEN}✓ Files prepared${NC}"
end_step 3

# Step 4: Create initialization scripts
start_step 4 "Creating initialization scripts"

# 01 - Create databases and users
cat > "$BUILD_DIR/docker-entrypoint-initdb.d/01-init.sql" << 'INIT_SQL'
-- Set up MySQL configuration
SET GLOBAL character_set_server='utf8mb4';
SET GLOBAL collation_server='utf8mb4_general_ci';
SET GLOBAL max_allowed_packet=1073741824;
SET GLOBAL sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- Create databases
CREATE DATABASE IF NOT EXISTS legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Create users
CREATE USER IF NOT EXISTS 'legion'@'%' IDENTIFIED BY 'legionwork';
CREATE USER IF NOT EXISTS 'legion'@'localhost' IDENTIFIED BY 'legionwork';
CREATE USER IF NOT EXISTS 'legionro'@'%' IDENTIFIED BY 'legionwork';

-- Grant privileges
GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON legiondb.* TO 'legionro'@'%';

GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'localhost' WITH GRANT OPTION;
GRANT SELECT ON legiondb0.* TO 'legionro'@'%';

FLUSH PRIVILEGES;

-- Switch to legiondb for subsequent operations
USE legiondb;
INIT_SQL

# 04 - Stored procedures for legiondb (update the file to use correct database)
sed -i.bak '1i USE legiondb;' "$BUILD_DIR/docker-entrypoint-initdb.d/04-storedprocedures-legiondb.sql"

# 05 - Stored procedures for legiondb0
sed -i.bak '1i USE legiondb0;' "$BUILD_DIR/docker-entrypoint-initdb.d/05-storedprocedures-legiondb0.sql"

# 06 - Create EnterpriseSchema tables
cat > "$BUILD_DIR/docker-entrypoint-initdb.d/06-enterprise-schema.sql" << 'SCHEMA_SQL'
-- Create EnterpriseSchema tables with correct structure
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
SCHEMA_SQL

# Clean up backup files
rm -f "$BUILD_DIR/docker-entrypoint-initdb.d"/*.bak

end_step 4

# Step 5: Create Dockerfile
start_step 5 "Creating Dockerfile"

cat > "$BUILD_DIR/Dockerfile" << 'DOCKERFILE'
FROM mysql:8.0

# MySQL configuration
ENV MYSQL_ROOT_PASSWORD=mysql123
ENV MYSQL_DATABASE=legiondb
ENV MYSQL_USER=legion
ENV MYSQL_PASSWORD=legionwork

# Copy initialization scripts (they run in alphabetical order)
COPY docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/

# Add custom config
RUN echo "[mysqld]" > /etc/mysql/conf.d/legion.cnf && \
    echo "sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION" >> /etc/mysql/conf.d/legion.cnf && \
    echo "character-set-server=utf8mb4" >> /etc/mysql/conf.d/legion.cnf && \
    echo "collation-server=utf8mb4_unicode_ci" >> /etc/mysql/conf.d/legion.cnf && \
    echo "max_connections=200" >> /etc/mysql/conf.d/legion.cnf && \
    echo "max_allowed_packet=1024M" >> /etc/mysql/conf.d/legion.cnf && \
    echo "innodb_buffer_pool_size=1G" >> /etc/mysql/conf.d/legion.cnf && \
    echo "innodb_redo_log_capacity=512M" >> /etc/mysql/conf.d/legion.cnf && \
    echo "connect_timeout=3600" >> /etc/mysql/conf.d/legion.cnf && \
    echo "wait_timeout=3600" >> /etc/mysql/conf.d/legion.cnf && \
    echo "interactive_timeout=3600" >> /etc/mysql/conf.d/legion.cnf

EXPOSE 3306

LABEL maintainer="Legion DevOps"
LABEL description="MySQL 8.0 with Legion databases pre-loaded"
LABEL version="8.0-legion-v3"
DOCKERFILE

end_step 5

# Step 6: Build Docker image
start_step 6 "Building Docker image"

cd "$BUILD_DIR"
docker build -t $IMAGE_NAME:$VERSION . --no-cache

# Tag as latest
docker tag $IMAGE_NAME:$VERSION $IMAGE_NAME:$LATEST_TAG

echo -e "${GREEN}✓ Docker image built successfully${NC}"
end_step 6

# Step 7: Deploy and verify
start_step 7 "Deploying MySQL container"

# Stop old container if running
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Start new container
echo "Starting new container..."
docker run -d \
    --name $CONTAINER_NAME \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD=mysql123 \
    $IMAGE_NAME:$LATEST_TAG

# Wait for MySQL to be ready (initialization takes time)
echo "Waiting for MySQL to initialize (this may take 5-10 minutes)..."
for i in {1..60}; do
    if docker exec $CONTAINER_NAME mysql -ulegion -plegionwork -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ MySQL is ready${NC}"
        break
    fi
    echo -n "."
    sleep 10
done

# Verify the deployment
echo ""
echo "=== Verifying deployment ==="
docker exec $CONTAINER_NAME mysql -ulegion -plegionwork -e "
    SELECT 'legiondb tables' as info, COUNT(*) as count FROM information_schema.tables WHERE table_schema='legiondb'
    UNION ALL
    SELECT 'legiondb0 tables', COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb0'
    UNION ALL  
    SELECT 'EnterpriseSchema in legiondb', COUNT(*) FROM legiondb.EnterpriseSchema
    UNION ALL
    SELECT 'EnterpriseSchema in legiondb0', COUNT(*) FROM legiondb0.EnterpriseSchema;"

# Check EnterpriseSchema structure
echo ""
echo "=== EnterpriseSchema structure ==="
docker exec $CONTAINER_NAME mysql -ulegion -plegionwork -e "DESCRIBE legiondb0.EnterpriseSchema;"

# Clean up build directory
cd ..
rm -rf "$BUILD_DIR"

end_step 7

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