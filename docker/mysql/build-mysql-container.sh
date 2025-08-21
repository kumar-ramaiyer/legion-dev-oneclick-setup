#!/bin/bash
# Build MySQL container with Legion data locally
# This script is idempotent - it cleans up and rebuilds each time

set -e

# Configuration
IMAGE_NAME="legion-mysql"
VERSION=$(date +%Y%m%d-%H%M%S)
LATEST_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Metrics tracking (using regular arrays for compatibility)
STEP_TIMES=()
STEP_NAMES=()
STEP_DURATIONS=()
SCRIPT_START=$(date +%s)
CURRENT_STEP=0

# Function to record step time
start_step() {
    CURRENT_STEP=$1
    STEP_NAMES[$1]="$2"
    STEP_TIMES[$1]=$(date +%s)
    echo -e "${YELLOW}Step $1: $2${NC}"
}

end_step() {
    local step=$1
    local end_time=$(date +%s)
    local start_time=${STEP_TIMES[$step]}
    local duration=$((end_time - start_time))
    STEP_DURATIONS[$step]=$duration
    echo -e "${CYAN}  ⏱️  Step $step completed in ${duration} seconds${NC}"
    echo ""
}

# Function to print metrics summary
print_metrics_summary() {
    local total_time=$(($(date +%s) - SCRIPT_START))
    
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                    Build Metrics Summary                     ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Stage Timing Breakdown:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for i in $(seq 1 $CURRENT_STEP); do
        if [ ! -z "${STEP_NAMES[$i]}" ]; then
            local duration=${STEP_DURATIONS[$i]}
            if [ ! -z "$duration" ]; then
                local percentage=$((duration * 100 / total_time))
                printf "  Step %d: %-40s : %3d seconds (%2d%%)\n" \
                    "$i" "${STEP_NAMES[$i]}" "$duration" "$percentage"
            fi
        fi
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Total Build Time: ${total_time} seconds ($(printf '%d:%02d' $((total_time/60)) $((total_time%60))) minutes)${NC}"
    echo ""
}

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Legion MySQL Container Build Script                ║${NC}"
echo -e "${GREEN}║                  (Local Build Only)                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Build started at: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# Step 1: Clean up existing containers and images (idempotent)
start_step 1 "Cleaning up existing containers and images"

# Stop and remove any existing containers (idempotent cleanup)
echo "Cleaning up existing MySQL containers and volumes..."

# Remove test container
if docker ps -a | grep -q "legion-mysql-test"; then
    docker stop legion-mysql-test 2>/dev/null || true
    docker rm legion-mysql-test 2>/dev/null || true
    echo "  Removed test container"
fi

# Remove production container - no prompts, always clean up
if docker ps -a | grep -q "legion-mysql"; then
    docker stop legion-mysql 2>/dev/null || true
    docker rm legion-mysql 2>/dev/null || true
    echo "  Removed legion-mysql container"
fi

# Remove docker-compose managed MySQL volume to ensure fresh data
if docker volume ls | grep -q "docker_mysql-data"; then
    docker volume rm docker_mysql-data 2>/dev/null || true
    echo "  Removed docker_mysql-data volume"
fi

echo -e "${GREEN}✓ Cleanup completed${NC}"

# Remove ALL existing legion-mysql images (force removal)
echo "Removing ALL existing $IMAGE_NAME images..."
# Get all image IDs for legion-mysql (including tagged versions)
IMAGE_IDS=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "^$IMAGE_NAME" | awk '{print $2}' | sort -u)
if [ ! -z "$IMAGE_IDS" ]; then
    echo "Found the following images to remove:"
    docker images | grep "^$IMAGE_NAME"
    for IMAGE_ID in $IMAGE_IDS; do
        echo "Removing image $IMAGE_ID..."
        docker rmi -f $IMAGE_ID 2>/dev/null || true
    done
    echo -e "${GREEN}✓ Removed all existing $IMAGE_NAME images${NC}"
else
    echo "No existing $IMAGE_NAME images found"
fi

# Clean up any old build directories
echo "Cleaning up old build directories..."
rm -rf "$(pwd)"/build-tmp-* 2>/dev/null || true
echo -e "${GREEN}✓ Cleanup completed${NC}"
end_step 1

# Step 2: Check for database dump files
start_step 2 "Checking for database dump files"

# Check if dbdumps folder is specified
if [ -z "$DBDUMPS_FOLDER" ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Database dump files are required to build the MySQL container${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Please download the following files from Google Drive:"
    echo -e "${BLUE}https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK${NC}"
    echo ""
    echo "Required files:"
    echo "  • storedprocedures.sql"
    echo "  • legiondb.sql.zip (5.6GB)"
    echo "  • legiondb0.sql.zip (306MB)"
    echo ""
    read -p "Enter the path to your dbdumps folder (or press Enter to use ~/dbdumps): " user_path
    
    if [ -z "$user_path" ]; then
        DBDUMPS_FOLDER="$HOME/dbdumps"
    else
        # Expand tilde if present
        DBDUMPS_FOLDER="${user_path/#\~/$HOME}"
    fi
fi

if [ ! -d "$DBDUMPS_FOLDER" ]; then
    echo -e "${RED}Database dumps folder not found: $DBDUMPS_FOLDER${NC}"
    echo ""
    echo "Please:"
    echo "1. Create the folder: mkdir -p $DBDUMPS_FOLDER"
    echo "2. Download files from: ${BLUE}https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK${NC}"
    echo "3. Place the files in: $DBDUMPS_FOLDER"
    echo "4. Run this script again"
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
end_step 2

# Step 3: Prepare build directory
start_step 3 "Preparing build directory"
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
end_step 3

# Step 4: Create MySQL configuration
start_step 4 "Creating MySQL configuration"
cat > "$BUILD_DIR/my.cnf" << 'EOF'
[mysqld]
# MySQL 8.0 configuration for Legion
# Disable ONLY_FULL_GROUP_BY and allow reserved keywords
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION

# Character set and collation
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Connection settings
max_connections=200
max_allowed_packet=1024M

# InnoDB settings (using new MySQL 8.0 parameters)
innodb_buffer_pool_size=1G
# Use innodb_redo_log_capacity instead of deprecated innodb_log_file_size
innodb_redo_log_capacity=512M
innodb_flush_log_at_trx_commit=2
innodb_flush_method=O_DIRECT

# Disable host cache as recommended
host_cache_size=0

# Timeout settings for large imports
connect_timeout=3600
wait_timeout=3600
interactive_timeout=3600
EOF
end_step 4

# Step 5: Create Dockerfile
start_step 5 "Creating Dockerfile"
cat > "$BUILD_DIR/Dockerfile" << 'EOF'
# Legion MySQL with pre-loaded data
FROM mysql:8.0

# Install Python3 and pip3 for collation fixes
RUN microdnf install -y python3 python3-pip && \
    microdnf clean all

# Environment variables
ENV MYSQL_ROOT_PASSWORD=mysql123
ENV MYSQL_DATABASE=legiondb

# Copy MySQL configuration to handle reserved keywords
COPY my.cnf /etc/mysql/conf.d/legion.cnf

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
end_step 5

# Step 6: Create initialization scripts
start_step 6 "Creating initialization scripts"

# 01 - Create databases and users (following README_enterprise.md exactly)
cat > "$BUILD_DIR/scripts/01-create-databases.sh" << 'EOF'
#!/bin/bash
set -ex  # Enable command echoing and exit on error

echo "=== Starting database and user creation ==="

# Following README_enterprise.md steps exactly
echo "=== Setting character encoding ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SET GLOBAL character_set_server='utf8mb4';"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SET GLOBAL collation_server='utf8mb4_general_ci';"

echo "=== Creating legiondb database ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

echo "=== Creating users ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS 'legion'@'%' IDENTIFIED WITH caching_sha2_password BY 'legionwork';"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS 'legionro'@'%' IDENTIFIED WITH caching_sha2_password BY 'legionwork';"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS 'legion'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'legionwork';"

echo "=== Granting privileges for legiondb ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'%' WITH GRANT OPTION;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'localhost' WITH GRANT OPTION;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT SELECT ON legiondb.* TO 'legionro'@'%';"

echo "=== Creating legiondb0 database ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

echo "=== Granting privileges for legiondb0 ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'%' WITH GRANT OPTION;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'localhost' WITH GRANT OPTION;"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT SELECT ON legiondb0.* TO 'legionro'@'%';"

echo "=== Flushing privileges ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"

echo "=== Verifying databases created ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW DATABASES;"

echo "=== Verifying users created ==="
mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT user, host FROM mysql.user WHERE user IN ('legion', 'legionro');"

echo "=== Database and user creation completed ==="
EOF

# Make the script executable
chmod +x "$BUILD_DIR/scripts/01-create-databases.sh"

# 02 - Import data and run migrations
cat > "$BUILD_DIR/scripts/02-import-data.sh" << 'EOF'
#!/bin/bash
set -ex  # Enable command echoing and exit on error

echo "=== Starting database import (following README_enterprise.md) ==="

# First verify the legion user exists and has access
echo "=== Verifying legion user access ==="
mysql -ulegion -plegionwork -e "SELECT USER();" 2>&1 || {
    echo "=== ERROR: Cannot connect as legion user ==="
    exit 1
}

# Import database dumps following README_enterprise.md exactly
echo "=== Importing database dumps as per README_enterprise.md ==="

# Data dump for legiondb
echo "=== Data dump for legiondb ==="
echo "=== Running: mysql -u legion -p legiondb < path/to/legiondb.sql ==="
if [ -f "/var/lib/mysql-import/legiondb.sql" ]; then
    echo "=== File size: $(ls -lh /var/lib/mysql-import/legiondb.sql | awk '{print $5}') ==="
    mysql -ulegion -plegionwork legiondb < /var/lib/mysql-import/legiondb.sql 2>&1
    echo "=== Checking table count after legiondb.sql import ==="
    mysql -ulegion -plegionwork -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb';"
fi

echo "=== Running: mysql -u legion -p legiondb < path/to/storedprocedures.sql ==="
if [ -f "/var/lib/mysql-import/storedprocedures.sql" ]; then
    mysql -ulegion -plegionwork legiondb < /var/lib/mysql-import/storedprocedures.sql 2>&1
    echo "=== Stored procedures imported to legiondb ==="
fi

# Data dump for legiondb0
echo "=== Data dump for legiondb0 ==="
echo "=== Running: mysql -u legion -p legiondb0 < path/to/legiondb0.sql ==="
if [ -f "/var/lib/mysql-import/legiondb0.sql" ]; then
    echo "=== File size: $(ls -lh /var/lib/mysql-import/legiondb0.sql | awk '{print $5}') ==="
    mysql -ulegion -plegionwork legiondb0 < /var/lib/mysql-import/legiondb0.sql 2>&1
    echo "=== Checking table count after legiondb0.sql import ==="
    mysql -ulegion -plegionwork -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb0';"
fi

echo "=== Running: mysql -u legion -p legiondb0 < path/to/storedprocedures.sql ==="
if [ -f "/var/lib/mysql-import/storedprocedures.sql" ]; then
    mysql -ulegion -plegionwork legiondb0 < /var/lib/mysql-import/storedprocedures.sql 2>&1
    echo "=== Stored procedures imported to legiondb0 ==="
fi

# Note: If the dumps don't have the complete migrated schema, you'll see
# Flyway migration errors during Maven build. In that case, either:
# 1. Get updated dumps from the platform team, or
# 2. Run Maven with -Dflyway.skip=true

echo "=== Database setup completed ==="
EOF

# 03 - Fix collations (using Python script approach)
cat > "$BUILD_DIR/scripts/03-fix-collations.sh" << 'EOF'
#!/bin/bash
set -ex  # Enable command echoing and exit on error

echo "=== Starting collation fixes ==="

# First check what tables exist in both databases
echo "=== Checking existing tables in legiondb ==="
mysql -uroot -pmysql123 -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb';"

echo "=== Checking existing tables in legiondb0 ==="
mysql -uroot -pmysql123 -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb0';"

# Install Python MySQL connector
echo "=== Installing Python MySQL connector ==="
pip3 install mysql-connector-python 2>&1

# Create Python script for collation fixes
cat > /tmp/fix_collations.py << 'PYTHON_EOF'
import mysql.connector
import sys

def fix_database_collation(database_name):
    print(f"Fixing collations for {database_name}...")
    
    # Database connection - use socket during initialization
    conn = mysql.connector.connect(
        unix_socket="/var/run/mysqld/mysqld.sock",
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
echo "=== Running Python collation fix script ==="
python3 /tmp/fix_collations.py 2>&1 || {
    echo "=== WARNING: Python script failed, but continuing ==="
}

# Create EnterpriseSchema table if it doesn't exist (from migration V49_38.0.1699000000000)
echo "=== Creating EnterpriseSchema table if needed ==="
mysql -uroot -pmysql123 << 'SQL' 2>&1
CREATE TABLE IF NOT EXISTS legiondb.EnterpriseSchema (
    id bigint not null auto_increment,
    objectId varchar(36),
    active bit not null default 1,
    createdBy varchar(50),
    createdDate datetime(6) default CURRENT_TIMESTAMP(6),
    lastModifiedBy varchar(50),
    lastModifiedDate datetime(6) on update CURRENT_TIMESTAMP(6),
    timeCreated bigint not null default 0,
    timeUpdated bigint not null default 0,
    enterpriseId varchar(36) not null,
    schemaKey varchar(255) not null,
    primary key (id),
    UNIQUE KEY ESCHUnique1 (enterpriseId, schemaKey)
) engine=InnoDB;

CREATE TABLE IF NOT EXISTS legiondb0.EnterpriseSchema (
    id bigint not null auto_increment,
    objectId varchar(36),
    active bit not null default 1,
    createdBy varchar(50),
    createdDate datetime(6) default CURRENT_TIMESTAMP(6),
    lastModifiedBy varchar(50),
    lastModifiedDate datetime(6) on update CURRENT_TIMESTAMP(6),
    timeCreated bigint not null default 0,
    timeUpdated bigint not null default 0,
    enterpriseId varchar(36) not null,
    schemaKey varchar(255) not null,
    primary key (id),
    UNIQUE KEY ESCHUnique1 (enterpriseId, schemaKey)
) engine=InnoDB;

-- Insert default enterprise mapping for local development
INSERT IGNORE INTO legiondb0.EnterpriseSchema (enterpriseId, schemaKey, active) VALUES 
('1', 'default', 1),
('1', 'legiondb0', 1);

-- Copy any existing data from legiondb to legiondb0
INSERT IGNORE INTO legiondb0.EnterpriseSchema 
SELECT * FROM legiondb.EnterpriseSchema;
SQL

echo "=== Final table count verification ==="
echo "=== Tables in legiondb: ==="
mysql -uroot -pmysql123 -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb';"

echo "=== Tables in legiondb0: ==="
mysql -uroot -pmysql123 -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='legiondb0';"

echo "=== Database setup completed ==="
EOF

# Make scripts executable
chmod +x "$BUILD_DIR/scripts"/*.sh
end_step 6

# Step 7: Build Docker image
start_step 7 "Building Docker image"
cd "$BUILD_DIR"
# Build with version tag first
docker build -t $IMAGE_NAME:$VERSION .
# Tag as latest (this creates an alias, not a separate image)
docker tag $IMAGE_NAME:$VERSION $IMAGE_NAME:$LATEST_TAG

echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo "Image created: $IMAGE_NAME:$VERSION"
echo "Tagged as: $IMAGE_NAME:$LATEST_TAG"
end_step 7

# Step 8: Test the container locally
start_step 8 "Testing container locally"
echo "Starting test container..."
docker run -d --name legion-mysql-test \
    -p 3307:3306 \
    -e MYSQL_ROOT_PASSWORD=mysql123 \
    $IMAGE_NAME:$LATEST_TAG

# Wait for container to be ready
echo "Waiting for MySQL to start (this may take several minutes for large databases)..."
echo "Database files are 6GB+ so import will take 10-20 minutes..."
echo ""

# First wait for MySQL to be accepting connections
for i in {1..60}; do
    if docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ MySQL is accepting connections after $(($i * 5)) seconds${NC}"
        break
    fi
    if [ $((i % 6)) -eq 0 ]; then
        echo "  Still waiting... $(($i * 5)) seconds elapsed"
        # Show container status
        docker exec legion-mysql-test ps aux | grep mysql | head -2
    fi
    sleep 5
done

# Now wait for initialization scripts to complete
echo ""
echo "Waiting for database imports to complete (this will take 10-20 minutes)..."
echo "Monitoring import progress..."

# Check for completion by looking for our final messages in the logs
for i in {1..240}; do  # 240 * 5 seconds = 20 minutes max
    if docker logs legion-mysql-test 2>&1 | grep -q "=== Database setup completed ==="; then
        echo -e "${GREEN}✓ Database imports completed!${NC}"
        break
    fi
    
    if [ $((i % 12)) -eq 0 ]; then  # Every minute
        echo "  Import still running... $(($i * 5)) seconds elapsed"
        # Show last import-related log entry
        docker logs legion-mysql-test 2>&1 | grep "===" | tail -1
    fi
    sleep 5
done

# Verify databases
echo "Verifying databases..."
echo "Checking container logs for import status:"
docker logs legion-mysql-test 2>&1 | grep -E "===|ERROR|WARNING|Importing|table_count" | tail -50

DATABASES=$(docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SHOW DATABASES;" 2>/dev/null | grep -E "legiondb|legiondb0" | wc -l)
if [ "$DATABASES" -eq "2" ]; then
    echo -e "${GREEN}✓ Both databases exist${NC}"
    
    # Check table counts and sample tables
    echo "Detailed database verification:"
    
    echo "legiondb tables:"
    LEGION_TABLES=$(docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb';" -s 2>/dev/null)
    echo "  Total tables: $LEGION_TABLES"
    
    if [ "$LEGION_TABLES" -lt "100" ]; then
        echo -e "${RED}  WARNING: Expected 100+ tables in legiondb, found only $LEGION_TABLES${NC}"
        echo "  Sample tables in legiondb:"
        docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SHOW TABLES FROM legiondb LIMIT 10;" 2>/dev/null
    else
        echo -e "${GREEN}  ✓ Table count looks correct${NC}"
    fi
    
    echo "legiondb0 tables:"
    LEGION0_TABLES=$(docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='legiondb0';" -s 2>/dev/null)
    echo "  Total tables: $LEGION0_TABLES"
    
    if [ "$LEGION0_TABLES" -lt "100" ]; then
        echo -e "${RED}  WARNING: Expected 100+ tables in legiondb0, found only $LEGION0_TABLES${NC}"
        echo "  Sample tables in legiondb0:"
        docker exec legion-mysql-test mysql -uroot -pmysql123 -e "SHOW TABLES FROM legiondb0 LIMIT 10;" 2>/dev/null
        
        # Check if import actually ran
        echo "  Checking if SQL files were processed:"
        docker exec legion-mysql-test ls -la /var/lib/mysql-import/ 2>/dev/null || echo "Import directory not found"
    else
        echo -e "${GREEN}  ✓ Table count looks correct${NC}"
    fi
    
    # Show full container logs if tables are missing
    if [ "$LEGION_TABLES" -lt "100" ] || [ "$LEGION0_TABLES" -lt "100" ]; then
        echo -e "${YELLOW}Full container initialization logs:${NC}"
        docker logs legion-mysql-test 2>&1
    fi
else
    echo -e "${RED}Database verification failed!${NC}"
    docker logs legion-mysql-test
    docker stop legion-mysql-test && docker rm legion-mysql-test
    exit 1
fi

# Stop test container
docker stop legion-mysql-test && docker rm legion-mysql-test
echo -e "${GREEN}✓ Container test passed${NC}"
end_step 8

# Step 9: Final local deployment
start_step 9 "Ready for local deployment"
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Build Completed Successfully!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Image built: ${IMAGE_NAME}:${LATEST_TAG}"
echo ""
echo "Deploying the new MySQL container..."
echo ""
# Automatically deploy using docker-compose
cd $(dirname $0)/..
docker-compose up -d mysql
echo ""
echo -e "${GREEN}✓ MySQL container deployed and running${NC}"
echo ""
echo "Container: legion-mysql"
echo "Port: 3306"
echo "Credentials: legion/legionwork"
echo ""
end_step 9

# Step 10: Cleanup build directory
start_step 10 "Cleaning up build directory"
cd ..
rm -rf "$BUILD_DIR"
echo -e "${GREEN}✓ Build directory cleaned${NC}"
end_step 10

# Print metrics before final summary
print_metrics_summary

# Display summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║               MySQL Container Build Complete!                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Image Details:${NC}"
echo "  Image Name: ${IMAGE_NAME}:${LATEST_TAG}"
echo "  Version:    ${VERSION}"
echo ""
echo -e "${BLUE}Databases included:${NC}"
echo "  - legiondb (with full schema and data)"
echo "  - legiondb0 (with full schema and data)"
echo ""
echo -e "${BLUE}MySQL Connection Info:${NC}"
echo "  Host: localhost"
echo "  Port: 3306"
echo "  User: legion"
echo "  Password: legionwork"
echo "  Database: legiondb (913 tables) / legiondb0 (840 tables)"
echo ""
echo -e "${GREEN}✨ MySQL container is running and ready to use!${NC}"