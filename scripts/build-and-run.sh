#!/bin/bash

# Legion Build and Run Script
# This script builds and/or runs the Legion backend and frontend applications
# Usage: ./build-and-run.sh [command] [options]
# Commands:
#   build-all      - Build both backend and frontend
#   build-backend  - Build only backend
#   build-frontend - Build only frontend
#   run-backend    - Run backend (builds first if needed)
#   run-frontend   - Run frontend development server
#   (no args)      - Same as run-backend for backward compatibility

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command and options
COMMAND="${1:-run-backend}"

# Parse additional arguments
for arg in "$@"; do
    case $arg in
        --build-only)
            # For backward compatibility
            COMMAND="build-backend"
            shift
            ;;
    esac
done

# Flyway will always run (as per developer requirements)
echo -e "${GREEN}Flyway migrations will run${NC}"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Docker configuration for MySQL credentials
DOCKER_CONFIG="$SCRIPT_DIR/../docker/config.sh"
if [ -f "$DOCKER_CONFIG" ]; then
    source "$DOCKER_CONFIG"
else
    # Fallback values if config doesn't exist
    MYSQL_HOST="localhost"
    MYSQL_PORT="3306"
    MYSQL_USER="legion"
    MYSQL_PASSWORD="legionwork"
fi

# Set the root directories
LEGION_ROOT="$HOME/Development/legion/code"
ENTERPRISE_ROOT="$LEGION_ROOT/enterprise"
CONSOLE_UI_ROOT="$LEGION_ROOT/console-ui"

# Check if directories exist
if [ ! -d "$LEGION_ROOT" ]; then
    echo -e "${RED}Error: Legion directory not found at $LEGION_ROOT${NC}"
    echo "Please run setup.sh first to clone repositories"
    exit 1
fi

# ============================================================================
# FUNCTION: ensure_config_optimizations (Added in v12)
# ============================================================================
# Purpose: Apply performance optimizations to prevent backend runtime issues
# 
# Problems Addressed:
# 1. HikariCP Connection Pool Exhaustion - "Connection not available" errors
#    - Increased max connections from 100 to 150
#    - Increased min connections from 5 to 10
#    - Added connection timeout of 5000ms
#
# 2. Cache Bootstrap Timeout - "PLT_TASK cache not ready after 10 minutes"
#    - Increased timeout from 10 to 20 minutes
#    - Enabled parallel cache loading
#    - Added batch size configuration
#
# 3. Missing Dynamic Group Enum Values - Deserialization errors
#    - Added logging to help identify problematic data
#
# Design: 
# - Fully idempotent - can be run multiple times safely
# - Returns 1 if config was modified (triggers rebuild)
# - Returns 0 if already optimized (skips unnecessary work)
# - Creates timestamped backups before modifications
# ============================================================================
ensure_config_optimizations() {
    local SOURCE_VALUES="$ENTERPRISE_ROOT/config/src/main/resources/templates/application/local/local.values.yml"
    
    # Check if source file exists
    if [ ! -f "$SOURCE_VALUES" ]; then
        echo -e "${YELLOW}⚠ Source values file not found, skipping config optimization${NC}"
        return 0
    fi
    
    # Check if optimizations already applied
    if grep -q "datasource_max_active: 150" "$SOURCE_VALUES" 2>/dev/null; then
        echo -e "${GREEN}✓ Config optimizations already applied${NC}"
        return 0
    fi
    
    # Track that we modified the config (for rebuild trigger)
    local CONFIG_MODIFIED=1
    
    echo -e "${BLUE}Applying performance optimizations to config...${NC}"
    
    # Create backup only if changes needed
    local BACKUP_FILE="$SOURCE_VALUES.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SOURCE_VALUES" "$BACKUP_FILE"
    
    # Check if settings exist and update or add them
    if grep -q "datasource_max_active:" "$SOURCE_VALUES"; then
        # Update existing values (use different backup extension to avoid conflicts)
        sed -i.bak 's/datasource_max_active:.*/datasource_max_active: 150  # Optimized by build script/' "$SOURCE_VALUES"
        sed -i.bak 's/datasource_min_size:.*/datasource_min_size: 10  # Optimized by build script/' "$SOURCE_VALUES"
        
        # Add other settings if missing
        if ! grep -q "datasource_max_wait:" "$SOURCE_VALUES"; then
            echo "datasource_max_wait: 5000  # Connection timeout in ms" >> "$SOURCE_VALUES"
        fi
        if ! grep -q "cache_bootstrap_timeout:" "$SOURCE_VALUES"; then
            echo -e "\n# Cache configuration optimizations" >> "$SOURCE_VALUES"
            echo "cache_bootstrap_timeout: 20  # Increased from 10 minutes" >> "$SOURCE_VALUES"
            echo "cache_bootstrap_parallel: true" >> "$SOURCE_VALUES"
            echo "cache_bootstrap_batch_size: 50" >> "$SOURCE_VALUES"
        fi
    else
        # Add new settings
        cat >> "$SOURCE_VALUES" << 'EOF'

# Performance optimizations added by build script
# Connection pool settings
datasource_max_active: 150  # Increased from 100
datasource_min_size: 10     # Increased from 5
datasource_max_wait: 5000   # Connection timeout in ms

# Cache configuration  
cache_bootstrap_timeout: 20  # Increased from 10 minutes
cache_bootstrap_parallel: true
cache_bootstrap_batch_size: 50

# Logging for debugging
logging_hikari_level: INFO
logging_cache_level: INFO
logging_scheduled_tasks_level: INFO
EOF
    fi
    
    # Clean up temp files (sed creates .bak files)
    rm -f "$SOURCE_VALUES.bak" 2>/dev/null
    
    echo -e "${GREEN}✓ Config optimizations applied (backup: $BACKUP_FILE)${NC}"
    
    # Return 1 to indicate config was modified (triggers rebuild)
    return 1
}

# Function to build backend
build_backend() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Building Legion Backend Application               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ ! -d "$ENTERPRISE_ROOT" ]; then
        echo -e "${RED}Error: Enterprise directory not found at $ENTERPRISE_ROOT${NC}"
        exit 1
    fi
    
    cd "$ENTERPRISE_ROOT"
    
    # ========================================================================
    # CONFIG OPTIMIZATION & REBUILD LOGIC (Added in v12)
    # ========================================================================
    # Why: Config changes weren't being picked up, causing backend to run with
    #      old settings even after optimizations were applied
    # How: 1. Apply optimizations if needed (idempotent function)
    #      2. Force rebuild if config was just modified
    #      3. Check timestamps for external modifications
    # ========================================================================
    
    # Apply config optimizations if needed (idempotent)
    # Returns 1 if config was modified, 0 if already optimized
    ensure_config_optimizations
    CONFIG_WAS_MODIFIED=$?
    
    # Check if application.yml exists or needs rebuild
    if [ ! -f "$ENTERPRISE_ROOT/config/target/resources/local/application.yml" ]; then
        echo -e "${YELLOW}Warning: application.yml not found${NC}"
        echo "Building configuration files..."
        mvn clean compile -P dev -pl config
    elif [ $CONFIG_WAS_MODIFIED -eq 1 ]; then
        # Config was just modified, force rebuild
        echo -e "${YELLOW}Config was optimized, rebuilding application.yml...${NC}"
        mvn compile -P dev -pl config
    else
        # Check if source is newer than target (config was updated externally)
        SOURCE_VALUES="$ENTERPRISE_ROOT/config/src/main/resources/templates/application/local/local.values.yml"
        TARGET_YML="$ENTERPRISE_ROOT/config/target/resources/local/application.yml"
        if [ "$SOURCE_VALUES" -nt "$TARGET_YML" ]; then
            echo -e "${YELLOW}Source config updated, rebuilding...${NC}"
            mvn compile -P dev -pl config
        fi
    fi
    
    echo -e "${BLUE}Running Maven build...${NC}"
    # Build with default profile for app module to generate enterprise JAR
    mvn clean package -T 1C -Pdefault -Djava.locale.providers=COMPAT,JRE,CLDR -DskipTests -Djavax.net.ssl.trustStorePassword=changeit -Dcheckstyle.skip=true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backend build successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Backend build failed${NC}"
        return 1
    fi
}

# Function to build frontend
build_frontend() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Building Legion Frontend Application               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ ! -d "$CONSOLE_UI_ROOT" ]; then
        echo -e "${RED}Error: Console-UI directory not found at $CONSOLE_UI_ROOT${NC}"
        exit 1
    fi
    
    cd "$CONSOLE_UI_ROOT"
    
    # Use Node.js version 18 with nvm if available
    if command -v nvm &> /dev/null; then
        echo -e "${BLUE}Using nvm to switch to Node.js 18...${NC}"
        nvm use 18
    else
        echo -e "${YELLOW}nvm not found, using system Node.js version$(node --version)${NC}"
    fi
    
    # Install dependencies
    echo -e "${BLUE}Installing frontend dependencies with yarn...${NC}"
    yarn
    
    # Run lerna bootstrap
    echo -e "${BLUE}Running yarn lerna bootstrap...${NC}"
    yarn lerna bootstrap
    
    echo -e "${GREEN}✓ Frontend build successful${NC}"
    echo -e "${YELLOW}To start the frontend, use: yarn console-ui${NC}"
    return 0
}

# Function to run backend
run_backend() {
    # Check if JAR exists, build if not
    APP_JAR="$ENTERPRISE_ROOT/app/target/legion-app-enterprise.jar"
    if [ ! -f "$APP_JAR" ]; then
        echo -e "${YELLOW}Application JAR not found. Building first...${NC}"
        build_backend
        if [ $? -ne 0 ]; then
            exit 1
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
    )
    
    
    # Show what we're running
    echo -e "${YELLOW}Starting backend with the following configuration:${NC}"
    echo "Main Class: com.legion.platform.server.base.SpringWebServer"
    echo "Classpath: legion-app module"
    echo ""
    
    # Check if MySQL is running
    echo -e "${BLUE}Checking MySQL connection...${NC}"
    if mysql -h $MYSQL_HOST -P $MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ MySQL is running and accessible${NC}"
    else
        echo -e "${RED}✗ MySQL is not accessible. Please ensure Docker containers are running.${NC}"
        echo "Run: cd docker && docker-compose up -d"
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
    
    # Look for the correct JAR file name (Spring Boot creates with enterprise classifier)
    if [ -f "$ENTERPRISE_ROOT/app/target/legion-app-enterprise.jar" ]; then
        APP_JAR="$ENTERPRISE_ROOT/app/target/legion-app-enterprise.jar"
    elif [ -f "$ENTERPRISE_ROOT/app/target/legion-app-1.0-SNAPSHOT-enterprise.jar" ]; then
        APP_JAR="$ENTERPRISE_ROOT/app/target/legion-app-1.0-SNAPSHOT-enterprise.jar"
    fi
    
    echo -e "${YELLOW}Using JAR: $APP_JAR${NC}"
    
    # Use direct Java command like developers do
    # Disable AWS SDK v1 deprecation warning
    export AWS_JAVA_V1_DISABLE_DEPRECATION_ANNOUNCEMENT=true
    exec java -Xmx6528m \
        -XX:MaxMetaspaceSize=1272m \
        -XX:CompressedClassSpaceSize=512m \
        -XX:+UseCompressedOops \
        -XX:+UseCompressedClassPointers \
        -XX:+UseG1GC \
        -XX:ParallelGCThreads=2 \
        -XX:ConcGCThreads=1 \
        -XX:+UseStringDeduplication \
        -XX:+HeapDumpOnOutOfMemoryError \
        -Duser.timezone=UTC \
        -Dspring.config.location=file:config/target/resources/local/application.yml \
        -Dspring.flyway.out-of-order=true \
        -Daws.java.v1.disableDeprecationAnnouncement=true \
        -Dspring.profiles.active=dev,local \
        -Djava.library.path=core/target/classes/com/legion/debian \
        -Djava.locale.providers=COMPAT,JRE,CLDR \
        -Dlog4j2.formatMsgNoLookups=true \
        -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector \
        -Dlogging.config=classpath:etc/log4j2.xml \
        -Dendpoint.url=http://localhost:4566 \
        -jar "$APP_JAR" 2>&1 | tee ~/enterprise.logs.txt
}

# Function to run frontend
run_frontend() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Legion Frontend Development Server                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ ! -d "$CONSOLE_UI_ROOT" ]; then
        echo -e "${RED}Error: Console-UI directory not found at $CONSOLE_UI_ROOT${NC}"
        exit 1
    fi
    
    cd "$CONSOLE_UI_ROOT"
    
    # Use Node.js version 18 with nvm if available
    if command -v nvm &> /dev/null; then
        echo -e "${BLUE}Using nvm to switch to Node.js 18...${NC}"
        nvm use 18
    else
        echo -e "${YELLOW}nvm not found, using system Node.js version $(node --version)${NC}"
    fi
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}Dependencies not installed. Building first...${NC}"
        yarn
        yarn lerna bootstrap
    fi
    
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Starting Legion Frontend Development Server...${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "The application will be available at:"
    echo "  • UI: http://localhost:3000"
    echo "  • Via Proxy: https://legion.local"
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    exec yarn console-ui
}

# Main execution
case "$COMMAND" in
    build-all)
        build_backend
        BACKEND_RESULT=$?
        build_frontend
        FRONTEND_RESULT=$?
        
        if [ $BACKEND_RESULT -eq 0 ] && [ $FRONTEND_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓ All builds completed successfully${NC}"
            exit 0
        else
            echo -e "${RED}✗ Some builds failed${NC}"
            exit 1
        fi
        ;;
        
    build-backend)
        build_backend
        ;;
        
    build-frontend)
        build_frontend
        ;;
        
    run-backend)
        run_backend
        ;;
        
    run-frontend)
        run_frontend
        ;;
        
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo "Usage: $0 [build-all|build-backend|build-frontend|run-backend|run-frontend]"
        echo ""
        echo "Examples:"
        echo "  $0 run-backend              # Run backend with Flyway migrations"
        echo "  $0 build-backend            # Build backend only"
        echo "  $0 build-all                # Build both backend and frontend"
        exit 1
        ;;
esac