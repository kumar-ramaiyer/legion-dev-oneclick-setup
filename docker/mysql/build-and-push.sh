#!/bin/bash
# Build and push Legion MySQL container to JFrog Artifactory

set -e

# Configuration
REGISTRY="legiontech.jfrog.io"
REPOSITORY="docker-local"
IMAGE_NAME="legion-mysql"
VERSION=$(date +%Y%m%d)
LATEST_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Legion MySQL Container Build & Push Script${NC}"
echo "==========================================="

# Check if logged in to JFrog
echo -e "${YELLOW}Checking JFrog Artifactory login...${NC}"
if ! docker login $REGISTRY 2>/dev/null; then
    echo -e "${RED}Not logged in to JFrog Artifactory${NC}"
    echo "Please login first:"
    echo "  docker login legiontech.jfrog.io"
    echo ""
    echo "Use your JFrog credentials (same as Maven/Okta)"
    exit 1
fi

# Check if data files exist
echo -e "${YELLOW}Checking for database dump files...${NC}"
if [ ! -f "data/legiondb.sql" ] || [ ! -f "data/legiondb0.sql" ]; then
    echo -e "${RED}Missing database files in data/ directory${NC}"
    echo "Please place the following files in docker/mysql/data/:"
    echo "  - legiondb.sql (unzipped)"
    echo "  - legiondb0.sql (unzipped)"
    echo "  - storedprocedures.sql"
    exit 1
fi

# Create import script that runs after database creation
cat > init-scripts/02-import-data.sh << 'EOF'
#!/bin/bash
# Import data into MySQL databases

echo "Starting database import..."

# Wait for MySQL to be ready
while ! mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

# Import legiondb
if [ -f /var/lib/mysql-import/legiondb.sql ]; then
    echo "Importing legiondb..."
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} legiondb < /var/lib/mysql-import/legiondb.sql
    echo "Importing stored procedures for legiondb..."
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} legiondb < /var/lib/mysql-import/storedprocedures.sql
fi

# Import legiondb0
if [ -f /var/lib/mysql-import/legiondb0.sql ]; then
    echo "Importing legiondb0..."
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} legiondb0 < /var/lib/mysql-import/legiondb0.sql
    echo "Importing stored procedures for legiondb0..."
    mysql -uroot -p${MYSQL_ROOT_PASSWORD} legiondb0 < /var/lib/mysql-import/storedprocedures.sql
fi

# Fix collations
mysql -uroot -p${MYSQL_ROOT_PASSWORD} << 'SQL'
USE legiondb;
SELECT CONCAT('ALTER TABLE ', table_name, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;')
FROM information_schema.tables
WHERE table_schema = 'legiondb' AND table_type = 'BASE TABLE'
INTO OUTFILE '/tmp/fix_legiondb.sql';
SOURCE /tmp/fix_legiondb.sql;

USE legiondb0;
SELECT CONCAT('ALTER TABLE ', table_name, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;')
FROM information_schema.tables
WHERE table_schema = 'legiondb0' AND table_type = 'BASE TABLE'
INTO OUTFILE '/tmp/fix_legiondb0.sql';
SOURCE /tmp/fix_legiondb0.sql;
SQL

echo "Database import completed!"
EOF

chmod +x init-scripts/02-import-data.sh

# Build the container
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t $IMAGE_NAME:$VERSION .
docker tag $IMAGE_NAME:$VERSION $REGISTRY/$REPOSITORY/$IMAGE_NAME:$VERSION
docker tag $IMAGE_NAME:$VERSION $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG

# Push to JFrog registry
echo -e "${YELLOW}Pushing to JFrog Artifactory...${NC}"
docker push $REGISTRY/$REPOSITORY/$IMAGE_NAME:$VERSION
docker push $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG

echo -e "${GREEN}✅ Successfully built and pushed Legion MySQL container${NC}"
echo ""
echo "Image URLs:"
echo "  - $REGISTRY/$REPOSITORY/$IMAGE_NAME:$VERSION"
echo "  - $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
echo ""
echo "To use this container:"
echo "  docker pull $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"
echo "  docker run -d -p 3306:3306 --name legion-mysql $REGISTRY/$REPOSITORY/$IMAGE_NAME:$LATEST_TAG"