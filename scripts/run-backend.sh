#!/bin/bash

# Legion Backend Runner Script
# This script builds and/or runs the Legion backend application with all necessary JVM arguments
# Usage: ./run-backend.sh [--build-only]
#   --build-only: Only build the application, don't run it

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
BUILD_ONLY=false
if [ "$1" == "--build-only" ]; then
    BUILD_ONLY=true
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set the root directory - check multiple possible locations
if [ -d "$HOME/Development/legion/code/enterprise" ]; then
    ENTERPRISE_ROOT="$HOME/Development/legion/code/enterprise"
elif [ -d "$HOME/legion/code/enterprise" ]; then
    ENTERPRISE_ROOT="$HOME/legion/code/enterprise"
elif [ -d "../enterprise" ]; then
    ENTERPRISE_ROOT="$(cd ../enterprise && pwd)"
else
    echo -e "${RED}Error: Could not find enterprise directory${NC}"
    echo "Expected locations:"
    echo "  - $HOME/Development/legion/code/enterprise"
    echo "  - $HOME/legion/code/enterprise"
    exit 1
fi

# Check if enterprise directory exists
if [ ! -d "$ENTERPRISE_ROOT" ]; then
    echo -e "${RED}Error: Enterprise directory not found at $ENTERPRISE_ROOT${NC}"
    echo "Please ensure Legion Enterprise is cloned to the correct location"
    exit 1
fi

# Check if application.yml exists
if [ ! -f "$ENTERPRISE_ROOT/config/target/resources/local/application.yml" ]; then
    echo -e "${YELLOW}Warning: application.yml not found${NC}"
    echo "Building configuration files..."
    cd "$ENTERPRISE_ROOT"
    mvn clean compile -P dev -pl config
fi

# Build the application
if [ "$BUILD_ONLY" == "true" ]; then
    echo -e "${BLUE}Building Legion Backend (build-only mode)...${NC}"
else
    # Check if the app JAR exists
    APP_JAR="$ENTERPRISE_ROOT/app/target/legion-app-1.0-SNAPSHOT.jar"
    if [ ! -f "$APP_JAR" ]; then
        echo -e "${YELLOW}Application JAR not found. Building...${NC}"
    fi
fi

# Always build if in build-only mode or if JAR is missing
if [ "$BUILD_ONLY" == "true" ] || [ ! -f "$APP_JAR" ]; then
    cd "$ENTERPRISE_ROOT"
    echo -e "${BLUE}Running Maven build...${NC}"
    mvn clean install -P dev -DskipTests -Dcheckstyle.skip -Djavax.net.ssl.trustStorePassword=changeit -Dflyway.skip=true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Maven build successful${NC}"
    else
        echo -e "${RED}✗ Maven build failed${NC}"
        exit 1
    fi
    
    # If build-only mode, exit here
    if [ "$BUILD_ONLY" == "true" ]; then
        echo -e "${GREEN}Build completed successfully (build-only mode)${NC}"
        exit 0
    fi
fi

# Detect OS for library path
if [[ "$OSTYPE" == "darwin"* ]]; then
    LIBRARY_PATH="$ENTERPRISE_ROOT/core/target/classes/lib/darwin"
    OS_NAME="macOS"
else
    LIBRARY_PATH="$ENTERPRISE_ROOT/core/target/classes/lib/linux"
    OS_NAME="Linux"
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Legion Backend Application Runner                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Operating System: $OS_NAME${NC}"
echo -e "${GREEN}Working Directory: $ENTERPRISE_ROOT${NC}"
echo -e "${GREEN}Application JAR: $APP_JAR${NC}"
echo ""

# Build the JVM arguments
JVM_ARGS=(
    # Memory settings
    "-Xms1536m"
    "-Xmx4928m"
    "-XX:MaxMetaspaceSize=768m"
    "-XX:CompressedClassSpaceSize=192m"
    "-XX:+UseCompressedOops"
    "-XX:+UseCompressedClassPointers"
    
    # GC settings
    "-XX:ParallelGCThreads=2"
    "-XX:ConcGCThreads=1"
    "-XX:+UseStringDeduplication"
    "-XX:+HeapDumpOnOutOfMemoryError"
    
    # Spring configuration
    "-Dspring.config.location=file:$ENTERPRISE_ROOT/config/target/resources/local/application.yml"
    "-Dspring.profiles.active=dev,local"
    
    # Library path for native libraries
    "-Djava.library.path=$LIBRARY_PATH"
    
    # AWS SES credentials (for email)
    "-Dspring.mail.username=AKIAIKDDWGXOBOHNLBPA"
    "-Dspring.mail.password=Aunn+EAQkicwNjYzkVBFSU+T7T0TIZMBSCBBdayNRiye"
    
    # Timezone
    "-Duser.timezone=LOCAL"
    
    # Async logging
    "-DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
    "-Dlogging.config=$ENTERPRISE_ROOT/config/target/resources/log4j2.xml"
    
    # Flyway skip (if database is pre-loaded)
    "-Dflyway.skip=true"
)

# Show what we're running
echo -e "${YELLOW}Starting backend with the following configuration:${NC}"
echo "Main Class: com.legion.platform.server.base.SpringWebServer"
echo "Classpath: legion-app module"
echo ""
echo -e "${YELLOW}JVM Arguments:${NC}"
for arg in "${JVM_ARGS[@]}"; do
    echo "  $arg"
done
echo ""

# Check if MySQL is running
echo -e "${BLUE}Checking MySQL connection...${NC}"
if mysql -h localhost -P 3306 -ulegion -plegionwork -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ MySQL is running and accessible${NC}"
else
    echo -e "${RED}✗ MySQL is not accessible. Please ensure Docker containers are running.${NC}"
    echo "Run: cd ~/work/legion-dev-oneclick-setup/docker && docker-compose up -d"
    exit 1
fi

# Check if Elasticsearch is running
echo -e "${BLUE}Checking Elasticsearch...${NC}"
if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Elasticsearch is running${NC}"
else
    echo -e "${YELLOW}⚠ Elasticsearch is not accessible (optional)${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Starting Legion Backend Application...${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "The application will be available at:"
echo "  • API: http://localhost:8080"
echo "  • Health: http://localhost:8080/actuator/health"
echo ""
echo "Press Ctrl+C to stop the application"
echo ""

# Change to enterprise directory
cd "$ENTERPRISE_ROOT"

# Run the application using Maven spring-boot:run
# This handles finding the main class automatically
# Convert JVM_ARGS array to a single string for Maven
JVM_ARGS_STRING=""
for arg in "${JVM_ARGS[@]}"; do
    JVM_ARGS_STRING="$JVM_ARGS_STRING $arg"
done

exec mvn spring-boot:run -pl app \
    -Dspring-boot.run.jvmArguments="$JVM_ARGS_STRING"