#!/bin/bash

# Legion Build and Run Script
# This script builds and/or runs the Legion backend and frontend applications
# Usage: ./build-and-run.sh [command]
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

# Parse command
COMMAND="${1:-run-backend}"

# For backward compatibility
if [ "$1" == "--build-only" ]; then
    COMMAND="build-backend"
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    
    # Check if application.yml exists
    if [ ! -f "$ENTERPRISE_ROOT/config/target/resources/local/application.yml" ]; then
        echo -e "${YELLOW}Warning: application.yml not found${NC}"
        echo "Building configuration files..."
        mvn clean compile -P dev -pl config -Dflyway.skip=true
    fi
    
    echo -e "${BLUE}Running Maven build...${NC}"
    mvn clean install -P dev -DskipTests -Dcheckstyle.skip -Djavax.net.ssl.trustStorePassword=changeit -Dflyway.skip=true
    
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
    
    # Increase Node heap size for large builds
    export NODE_OPTIONS="--max-old-space-size=8192"
    echo -e "${YELLOW}Setting Node.js heap size to 8GB for build...${NC}"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo -e "${BLUE}Installing frontend dependencies...${NC}"
        yarn install || npm install
    fi
    
    # Run lerna bootstrap
    echo -e "${BLUE}Running lerna bootstrap...${NC}"
    npx lerna bootstrap || yarn lerna bootstrap
    
    # Build
    echo -e "${BLUE}Building frontend (this may take a few minutes)...${NC}"
    yarn build || npm run build
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Frontend build successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Frontend build failed${NC}"
        echo -e "${YELLOW}To retry with more memory: NODE_OPTIONS=\"--max-old-space-size=12288\" yarn build${NC}"
        return 1
    fi
}

# Function to run backend
run_backend() {
    # Check if JAR exists, build if not
    APP_JAR="$ENTERPRISE_ROOT/app/target/legion-app-1.0-SNAPSHOT.jar"
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
        
        # Flyway skip (if database is pre-loaded)
        "-Dflyway.skip=true"
    )
    
    # Show what we're running
    echo -e "${YELLOW}Starting backend with the following configuration:${NC}"
    echo "Main Class: com.legion.platform.server.base.SpringWebServer"
    echo "Classpath: legion-app module"
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
    
    # Convert JVM_ARGS array to a single string for Maven
    JVM_ARGS_STRING=""
    for arg in "${JVM_ARGS[@]}"; do
        JVM_ARGS_STRING="$JVM_ARGS_STRING $arg"
    done
    
    exec mvn spring-boot:run -pl app \
        -Dspring-boot.run.jvmArguments="$JVM_ARGS_STRING"
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
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}Dependencies not installed. Installing...${NC}"
        yarn install || npm install
        npx lerna bootstrap || yarn lerna bootstrap
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
    
    exec yarn start || exec npm start
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
        exit 1
        ;;
esac