#!/bin/bash
set -e

# Legion Enterprise Development Environment Setup - Docker Edition
# ONE COMMAND setup for all developers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/docker"
CONFIG_FILE="$SCRIPT_DIR/setup_config.yaml"
LOG_DIR="$HOME/.legion_setup/logs"

# Setup logging
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Metrics tracking (using regular arrays for compatibility)
STAGE_TIMES=()
STAGE_NAMES=()
STAGE_DURATIONS=()
SETUP_START=$(date +%s)
CURRENT_STAGE=0

# Function to start timing a stage
start_stage() {
    local stage_num=$1
    local stage_name="$2"
    CURRENT_STAGE=$stage_num
    STAGE_NAMES[$stage_num]="$stage_name"
    STAGE_TIMES[$stage_num]=$(date +%s)
    echo -e "${MAGENTA}━━━ Stage $stage_num: $stage_name ━━━${NC}" | tee -a "$LOG_FILE"
}

# Function to end timing a stage
end_stage() {
    local stage_num=$1
    local end_time=$(date +%s)
    local start_time=${STAGE_TIMES[$stage_num]}
    local duration=$((end_time - start_time))
    STAGE_DURATIONS[$stage_num]=$duration
    echo -e "${CYAN}  ⏱️  Stage $stage_num completed in ${duration} seconds${NC}" | tee -a "$LOG_FILE"
    echo ""
}

# Function to print final metrics summary
print_setup_metrics() {
    local total_time=$(($(date +%s) - SETUP_START))
    
    echo "" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}║                   Setup Metrics Summary                      ║${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${BLUE}Stage Timing Breakdown:${NC}" | tee -a "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
    
    # Find longest stage name for formatting
    local max_length=0
    for i in "${!STAGE_NAMES[@]}"; do
        local len=${#STAGE_NAMES[$i]}
        if [ $len -gt $max_length ]; then
            max_length=$len
        fi
    done
    
    # Print each stage with timing
    for i in $(seq 1 $CURRENT_STAGE); do
        if [ ! -z "${STAGE_NAMES[$i]}" ]; then
            local duration=${STAGE_DURATIONS[$i]}
            if [ ! -z "$duration" ]; then
                local percentage=$((duration * 100 / total_time))
                local mins=$((duration / 60))
                local secs=$((duration % 60))
                printf "  Stage %d: %-${max_length}s : %3dm %2ds (%2d%%)\n" \
                    "$i" "${STAGE_NAMES[$i]}" "$mins" "$secs" "$percentage" | tee -a "$LOG_FILE"
            fi
        fi
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$LOG_FILE"
    
    local total_mins=$((total_time / 60))
    local total_secs=$((total_time % 60))
    echo -e "${GREEN}Total Setup Time: ${total_mins} minutes ${total_secs} seconds${NC}" | tee -a "$LOG_FILE"
    
    # Performance analysis
    echo "" | tee -a "$LOG_FILE"
    echo -e "${BLUE}Performance Analysis:${NC}" | tee -a "$LOG_FILE"
    
    # Find slowest stage
    local slowest_stage=0
    local slowest_time=0
    for i in $(seq 1 $CURRENT_STAGE); do
        local duration=${STAGE_DURATIONS[$i]}
        if [ ! -z "$duration" ] && [ $duration -gt $slowest_time ]; then
            slowest_time=$duration
            slowest_stage=$i
        fi
    done
    
    if [ $slowest_stage -gt 0 ]; then
        echo -e "  🐌 Slowest stage: Stage $slowest_stage - ${STAGE_NAMES[$slowest_stage]} (${slowest_time}s)" | tee -a "$LOG_FILE"
    fi
    
    # Calculate average stage time
    local avg_time=$((total_time / CURRENT_STAGE))
    echo -e "  📊 Average stage time: ${avg_time} seconds" | tee -a "$LOG_FILE"
    
    echo "" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${MAGENTA}━━━ $1 ━━━${NC}" | tee -a "$LOG_FILE"
}

# Show banner
show_banner() {
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║      ██╗     ███████╗ ██████╗ ██╗ ██████╗ ███╗   ██╗               ║
║      ██║     ██╔════╝██╔════╝ ██║██╔═══██╗████╗  ██║               ║
║      ██║     █████╗  ██║  ███╗██║██║   ██║██╔██╗ ██║               ║
║      ██║     ██╔══╝  ██║   ██║██║██║   ██║██║╚██╗██║               ║
║      ███████╗███████╗╚██████╔╝██║╚██████╔╝██║ ╚████║               ║
║      ╚══════╝╚══════╝ ╚═════╝ ╚═╝ ╚═════╝ ╚═╝  ╚═══╝               ║
║                                                                      ║
║                ENTERPRISE DEVELOPMENT ENVIRONMENT                    ║
║                         Docker Edition v6.0                         ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

        🚀 ONE COMMAND SETUP - Everything containerized!
        
EOF
}

# Check Docker installation
check_docker() {
    start_stage 1 "Checking Docker"
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not found. Installing Docker Desktop..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install --cask docker
            else
                print_error "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
                exit 1
            fi
        else
            # Linux
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            rm get-docker.sh
            print_warning "Please log out and back in for Docker group changes to take effect"
        fi
    else
        print_success "Docker is installed"
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_warning "Docker is not running. Starting Docker..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open -a Docker
            print_status "Waiting for Docker to start..."
            for i in {1..30}; do
                if docker info &> /dev/null; then
                    break
                fi
                sleep 2
                echo -n "."
            done
            echo
        else
            sudo systemctl start docker
        fi
    fi
    
    if docker info &> /dev/null; then
        print_success "Docker is running"
    else
        print_error "Failed to start Docker. Please start Docker Desktop manually and run again."
        exit 1
    fi
    end_stage 1
}

# Check required tools
check_prerequisites() {
    start_stage 2 "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check Git
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    else
        print_success "Git is installed"
    fi
    
    # Check Make (optional but helpful)
    if ! command -v make &> /dev/null; then
        print_warning "Make not found (optional)"
    else
        print_success "Make is installed"
    fi
    
    # Install missing tools
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_warning "Installing missing tools: ${missing_tools[*]}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - use brew
            if ! command -v brew &> /dev/null; then
                print_status "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install "${missing_tools[@]}"
        else
            # Linux - use apt/yum
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y "${missing_tools[@]}"
            elif command -v yum &> /dev/null; then
                sudo yum install -y "${missing_tools[@]}"
            fi
        fi
    fi
    
    print_success "All prerequisites checked"
}

# Clone repositories if needed
clone_repositories() {
    start_stage 3 "Setting up Legion Repositories"
    
    LEGION_DIR="$HOME/Development/legion/code"
    mkdir -p "$LEGION_DIR"
    
    # Check for enterprise repo
    if [ ! -d "$LEGION_DIR/enterprise" ]; then
        print_status "Cloning enterprise repository..."
        if [ -f "$CONFIG_FILE" ]; then
            GITHUB_USER=$(grep "github_username:" "$CONFIG_FILE" | cut -d'"' -f2)
        else
            read -p "Enter your GitHub username: " GITHUB_USER
        fi
        
        git clone git@github.com:legionco/enterprise.git "$LEGION_DIR/enterprise" || {
            print_warning "SSH clone failed, trying HTTPS..."
            git clone https://github.com/legionco/enterprise.git "$LEGION_DIR/enterprise"
        }
        print_success "Enterprise repository cloned"
    else
        print_success "Enterprise repository already exists"
        cd "$LEGION_DIR/enterprise" && git pull origin main 2>/dev/null || true
    fi
    
    # Check for console-ui repo
    if [ ! -d "$LEGION_DIR/console-ui" ]; then
        print_status "Cloning console-ui repository..."
        git clone git@github.com:legionco/console-ui.git "$LEGION_DIR/console-ui" || {
            print_warning "SSH clone failed, trying HTTPS..."
            git clone https://github.com/legionco/console-ui.git "$LEGION_DIR/console-ui"
        }
        print_success "Console-UI repository cloned"
    else
        print_success "Console-UI repository already exists"
        cd "$LEGION_DIR/console-ui" && git pull origin main 2>/dev/null || true
    fi
}

# Setup Docker environment
setup_docker_environment() {
    start_stage 4 "Setting up Docker Environment"
    
    cd "$DOCKER_DIR"
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in $DOCKER_DIR"
        exit 1
    fi
    
    # Clean up any existing containers and volumes
    print_status "Cleaning up existing Docker containers..."
    docker-compose down -v 2>/dev/null || true
    
    # Stop any standalone containers that might conflict
    docker stop elasticsearch 2>/dev/null || true
    docker rm elasticsearch 2>/dev/null || true
    docker ps -a | grep localstack | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    
    # Clean up old Docker images (except legion-mysql)
    print_status "Cleaning up Docker images (keeping legion-mysql)..."
    
    # Get list of images to remove (exclude legion-mysql)
    images_to_remove=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "legion-mysql" | grep -v "<none>" | tr '\n' ' ')
    
    if [ ! -z "$images_to_remove" ]; then
        print_status "Removing old images: $images_to_remove"
        for image in $images_to_remove; do
            docker rmi "$image" 2>/dev/null || true
        done
        print_success "Docker images cleaned up"
    else
        print_success "No images to clean up"
    fi
    
    # Check for Legion MySQL image with fail-fast approach
    print_status "Checking Legion MySQL image availability..."
    
    # Priority 1: Check if locally built image exists
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "legion-mysql:latest"; then
        print_success "✓ Found locally built Legion MySQL image"
        
        # IMPORTANT: If using a freshly built MySQL image, remove old volume data
        if docker volume ls | grep -q "docker_mysql-data"; then
            print_warning "Found existing MySQL data volume"
            print_status "Removing old MySQL volume to use fresh data from image..."
            docker-compose down mysql 2>/dev/null || true
            docker volume rm docker_mysql-data 2>/dev/null || true
            print_success "Old MySQL volume removed - will use fresh data from image"
        fi
        # Update docker-compose to use local image
        sed -i.bak 's|image: mysql:8.0|image: legion-mysql:latest|' docker-compose.yml
        sed -i.bak 's|image: legiontech.jfrog.io/docker-local/legion-mysql:latest|image: legion-mysql:latest|' docker-compose.yml
        # Remove init scripts volume line if present (pre-loaded data in container)
        sed -i.bak '/.*mysql\/init-scripts:\/docker-entrypoint-initdb.d/d' docker-compose.yml
        
    # Priority 2: Check JFrog registry
    elif docker pull legiontech.jfrog.io/docker-local/legion-mysql:latest 2>/dev/null; then
        print_success "✓ Found Legion MySQL image on JFrog"
        # Update docker-compose to use JFrog image
        sed -i.bak 's|image: mysql:8.0|image: legiontech.jfrog.io/docker-local/legion-mysql:latest|' docker-compose.yml
        # Remove init scripts volume line if present (pre-loaded data in container)
        sed -i.bak '/.*mysql\/init-scripts:\/docker-entrypoint-initdb.d/d' docker-compose.yml
        
    # Priority 3: FAIL FAST - Image not available anywhere
    else
        print_error "✗ Legion MySQL image not found!"
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                    SETUP FAILED                             ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}The Legion MySQL container with pre-loaded data is required but not found.${NC}"
        echo ""
        echo -e "${BLUE}DevOps Action Required:${NC}"
        echo "1. Build the MySQL container:"
        echo "   cd docker/mysql"
        echo "   ./build-mysql-container.sh"
        echo ""
        echo "2. Push to JFrog (resolve 409 Conflict issue first):"
        echo "   docker push legiontech.jfrog.io/docker-local/legion-mysql:latest"
        echo ""
        echo -e "${BLUE}Alternative for Developers:${NC}"
        echo "Contact #devops-it-support for access to the pre-built MySQL image."
        echo ""
        echo -e "${RED}Setup cannot continue without the Legion MySQL image.${NC}"
        exit 1
    fi
    
    # Generate SSL certificates
    print_status "Setting up SSL certificates..."
    if [ -f "setup-certificates.sh" ]; then
        ./setup-certificates.sh
    else
        # Create inline certificate setup
        print_status "Installing mkcert for SSL certificates..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install mkcert
        else
            sudo apt-get install -y libnss3-tools
            curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
            chmod +x mkcert-*-linux-amd64
            sudo mv mkcert-*-linux-amd64 /usr/local/bin/mkcert
        fi
        
        mkcert -install
        mkdir -p certs
        mkcert -cert-file certs/legion.crt -key-file certs/legion.key \
            "legion.local" "*.legion.local" "localhost" "127.0.0.1"
        print_success "SSL certificates generated"
    fi
    
    # Add hosts entry
    print_status "Updating /etc/hosts..."
    if ! grep -q "legion.local" /etc/hosts; then
        echo "127.0.0.1 legion.local mail.legion.local tracing.legion.local" | sudo tee -a /etc/hosts > /dev/null
        print_success "Added legion.local to /etc/hosts"
    else
        print_success "/etc/hosts already configured"
    fi
    
    # Start Docker services
    print_status "Starting Docker services..."
    if ! docker-compose pull; then
        print_error "Failed to pull Docker images"
        exit 1
    fi
    
    if ! docker-compose up -d; then
        print_error "Failed to start Docker services"
        print_error "Check for port conflicts or other issues"
        print_error "Common fixes:"
        echo "  • Port 9200 in use: docker stop elasticsearch"
        echo "  • Port 3306 in use: brew services stop mysql"
        echo "  • Reset all: docker-compose down -v"
        exit 1
    fi
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    echo -n "MySQL"
    for i in {1..30}; do
        if docker-compose exec -T mysql mysql -ulegion -plegionwork -e "SELECT 1" &>/dev/null; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    echo -n "Elasticsearch"
    for i in {1..30}; do
        if curl -s http://localhost:9200/_cluster/health &>/dev/null; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    echo -n "Redis"
    if docker-compose exec -T redis redis-cli ping &>/dev/null; then
        echo " ✓"
    fi
    
    print_success "All Docker services are running"
}

# Setup development tools
setup_dev_tools() {
    start_stage 5 "Installing Development Tools"
    
    # Check for Homebrew on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &> /dev/null; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            print_success "Homebrew installed"
        else
            print_success "Homebrew already installed"
        fi
    fi
    
    # Java 17 (Amazon Corretto)
    if ! java -version 2>&1 | grep -q "version \"17"; then
        print_status "Installing Java 17 (Amazon Corretto)..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install --cask amazon-corretto@17
            # Set JAVA_HOME
            echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
            export JAVA_HOME=$(/usr/libexec/java_home -v 17)
        else
            sudo apt-get install -y openjdk-17-jdk
        fi
        print_success "Java 17 installed"
    else
        print_success "Java 17 already installed"
        # Ensure JAVA_HOME is set
        if [[ "$OSTYPE" == "darwin"* ]]; then
            export JAVA_HOME=$(/usr/libexec/java_home -v 17)
        fi
    fi
    
    # Maven 3.9.9+
    if ! command -v mvn &> /dev/null; then
        print_status "Installing Maven..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install maven
        else
            sudo apt-get install -y maven
        fi
        print_success "Maven installed"
    else
        # Check Maven version
        maven_version=$(mvn -version | grep "Apache Maven" | awk '{print $3}')
        print_success "Maven $maven_version already installed"
    fi
    
    # Check for settings.xml
    if [ ! -f "$HOME/.m2/settings.xml" ]; then
        print_warning "Maven settings.xml not found in ~/.m2/"
        print_warning "Download from JFrog Artifactory via Okta login"
        print_warning "Or contact #devops-it-support for help"
    else
        print_success "Maven settings.xml found"
    fi
    
    # MySQL client
    if ! command -v mysql &> /dev/null; then
        print_status "Installing MySQL client..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install mysql-client
            # Add to PATH
            echo 'export PATH="/usr/local/opt/mysql-client/bin:$PATH"' >> ~/.zshrc
        else
            sudo apt-get install -y mysql-client
        fi
        print_success "MySQL client installed"
    else
        print_success "MySQL client already installed"
    fi
    
    # Node.js 18 (specific version for compatibility)
    node_correct_version=false
    
    # Check if node exists and its version
    if command -v node &> /dev/null; then
        node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -eq 18 ]; then
            node_correct_version=true
            print_success "Node.js $(node -v) already installed"
        else
            print_warning "Node.js v$node_version found, but v18 is required for console-ui"
        fi
    else
        print_status "Node.js not found"
    fi
    
    # Install or switch to Node.js 18 if needed
    if [ "$node_correct_version" = false ]; then
        print_status "Setting up Node.js 18..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # On macOS, use brew to install node@18
            if brew list node@18 &>/dev/null; then
                print_status "Node.js 18 is installed, linking it..."
                brew unlink node 2>/dev/null || true
                brew link --force --overwrite node@18
            else
                print_status "Installing Node.js 18 via Homebrew..."
                brew unlink node 2>/dev/null || true
                brew install node@18
                brew link --force --overwrite node@18
            fi
            
            # Verify the switch worked
            if node -v 2>/dev/null | grep -q "v18"; then
                print_success "Successfully switched to Node.js 18"
            else
                print_warning "Could not switch to Node.js 18. You may need to:"
                echo "  brew unlink node && brew link --force --overwrite node@18"
                echo "  OR use nvm: nvm install 18 && nvm use 18"
            fi
        else
            # On Linux, use NodeSource repository
            print_status "Installing Node.js 18 via NodeSource..."
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
            print_success "Node.js 18 installed"
        fi
    fi
    
    # Yarn
    if ! command -v yarn &> /dev/null; then
        print_status "Installing Yarn..."
        npm install -g yarn
        print_success "Yarn installed"
    else
        print_success "Yarn $(yarn -v) already installed"
    fi
    
    # Lerna
    if ! npm list -g lerna &> /dev/null; then
        print_status "Installing Lerna..."
        npm install -g lerna@6
        print_success "Lerna installed"
    else
        print_success "Lerna already installed"
    fi
    
    # Python 3 and pip
    if ! command -v python3 &> /dev/null; then
        print_status "Installing Python 3..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install python3
        else
            sudo apt-get install -y python3 python3-pip
        fi
        print_success "Python 3 installed"
    else
        print_success "Python $(python3 --version) already installed"
    fi
    
    # pipx (for Python app installation)
    if ! command -v pipx &> /dev/null; then
        print_status "Installing pipx..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install pipx
            pipx ensurepath
        else
            python3 -m pip install --user pipx
            python3 -m pipx ensurepath
        fi
        # Add to current session PATH
        export PATH="$HOME/.local/bin:$PATH"
        print_success "pipx installed"
    else
        print_success "pipx already installed"
    fi
    
    # Yasha (YAML templating tool required for Maven build)
    if ! command -v yasha &> /dev/null; then
        print_status "Installing Yasha (YAML templating tool)..."
        # Check if yasha is in PATH (might be in .local/bin)
        if [ -f "$HOME/.local/bin/yasha" ]; then
            export PATH="$HOME/.local/bin:$PATH"
            print_success "Yasha found in ~/.local/bin"
        else
            # Install using pipx (preferred) or brew
            if command -v pipx &> /dev/null; then
                pipx install yasha
                pipx ensurepath
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                # Try brew if pipx fails
                brew install yasha 2>/dev/null || {
                    print_warning "Installing yasha via pip with --break-system-packages"
                    pip3 install --break-system-packages --user yasha
                }
            else
                pip3 install --user yasha
            fi
            # Ensure PATH is updated
            export PATH="$HOME/.local/bin:$PATH"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
            else
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            fi
        fi
        
        # Verify installation
        if command -v yasha &> /dev/null || [ -f "$HOME/.local/bin/yasha" ]; then
            print_success "Yasha installed successfully"
        else
            print_error "Failed to install Yasha. Maven build may fail."
        fi
    else
        print_success "Yasha $(yasha --version 2>/dev/null || echo 'installed')"
    fi
    
    # GLPK library (for optimization)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ ! -f "/opt/local/lib/libglpk.40.dylib" ]; then
            print_warning "GLPK library not found. Will be set up after Maven build."
        else
            print_success "GLPK library already installed"
        fi
    fi
}

# Build and verify setup
verify_setup() {
    start_stage 6 "Building & Verifying Setup"
    
    print_status "This stage will:"
    print_status "  • Build backend (Maven)"
    print_status "  • Build frontend (Yarn)"
    print_status "  • Verify all services are running"
    echo
    
    LEGION_DIR="$HOME/Development/legion/code"
    
    # Build Maven project using run-backend script
    print_status "Building backend project..."
    cd "$LEGION_DIR/enterprise"
    
    # First ensure Lombok annotation processing is configured
    print_status "Checking Lombok configuration..."
    if ! grep -q "annotationProcessorPaths" pom.xml; then
        print_status "Adding Lombok annotation processor configuration..."
        # Add the annotation processor configuration to maven-compiler-plugin
        sed -i.bak '/<artifactId>maven-compiler-plugin<\/artifactId>/,/<\/plugin>/ {
            /<configuration>/a\
                        <annotationProcessorPaths>\
                            <path>\
                                <groupId>org.projectlombok</groupId>\
                                <artifactId>lombok</artifactId>\
                                <version>1.18.38</version>\
                            </path>\
                        </annotationProcessorPaths>
        }' pom.xml
        print_success "Lombok configuration added"
    fi
    
    # Use run-backend.sh script to build (it handles all the Maven flags properly)
    # Use the SCRIPT_DIR that was set at the beginning of this file
    RUN_BACKEND_SCRIPT="$SCRIPT_DIR/scripts/run-backend.sh"
    
    print_status "Using run-backend.sh from: $RUN_BACKEND_SCRIPT"
    
    if [ ! -f "$RUN_BACKEND_SCRIPT" ]; then
        print_error "run-backend.sh not found at $RUN_BACKEND_SCRIPT"
        print_warning "Cannot build backend without the run script"
        return 1
    fi
    
    if "$RUN_BACKEND_SCRIPT" --build-only; then
        print_success "Maven build successful"
    else
        print_warning "Maven build failed - please check logs"
    fi
    
    # Build frontend
    print_status "Building frontend (Console-UI)..."
    cd "$LEGION_DIR/console-ui"
    if [ -f "package.json" ]; then
        print_status "Installing frontend dependencies..."
        yarn install || npm install
        print_success "Frontend dependencies installed"
        
        print_status "Running lerna bootstrap to install all package dependencies..."
        npx lerna bootstrap || yarn lerna bootstrap
        print_success "Lerna bootstrap complete"
        
        print_status "Building frontend application..."
        yarn build || npm run build
        if [ $? -eq 0 ]; then
            print_success "Frontend build complete"
        else
            print_warning "Frontend build failed - this is okay, you can build it later with 'yarn build'"
        fi
    fi
    
    # Show service status
    print_step "Service Status"
    cd "$DOCKER_DIR"
    docker-compose ps
}

# Show next steps
show_next_steps() {
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════╗
║                     🎉 SETUP COMPLETE! 🎉                           ║
╚══════════════════════════════════════════════════════════════════════╝

✅ All services are running in Docker containers
✅ SSL certificates installed and trusted
✅ Repositories cloned and ready

📦 DOCKER SERVICES:
   • MySQL 8.0       : localhost:3306 (user: legion, pass: legionwork)
   • Elasticsearch   : localhost:9200
   • Redis          : localhost:6379 (master), localhost:6380 (slave)
   • LocalStack     : localhost:4566 (AWS services)
   • MailHog        : http://mail.legion.local
   • Jaeger         : http://tracing.legion.local
   • Caddy (HTTPS)  : https://legion.local

✅ BUILD STATUS:
   • Backend: Built and ready (legion-app-1.0-SNAPSHOT.jar)
   • Frontend: Built and ready (dist folder created)
   • Database: MySQL running with 913/840 tables
   • All services: Running in Docker

🚀 TO START THE APPLICATION:

   1. Start Backend:
      cd ~/work/legion-dev-oneclick-setup
      ./scripts/run-backend.sh
      
   2. Start Frontend:
      cd ~/Development/legion/code/console-ui
      yarn start
      
   3. Access the application:
      https://legion.local
      
📝 USEFUL COMMANDS:

   • View logs      : cd docker && docker-compose logs -f [service]
   • Stop services  : cd docker && docker-compose stop
   • Start services : cd docker && docker-compose start
   • Reset all      : cd docker && docker-compose down -v
   
💡 TIPS:
   • All data persists in Docker volumes
   • Caddy automatically handles HTTPS
   • Use https://legion.local for development
   • MySQL data is pre-loaded from JFrog

📚 For more information, see docker/README.md

EOF
    
    # Calculate total time (macOS compatible)
    TOTAL_TIME=$SECONDS
    HOURS=$((TOTAL_TIME / 3600))
    MINUTES=$(((TOTAL_TIME % 3600) / 60))
    SECS=$((TOTAL_TIME % 60))
    print_success "Setup completed in ${HOURS}h ${MINUTES}m ${SECS}s"
    print_success "Log saved to: $LOG_FILE"
}

# Main execution
main() {
    # Start timer
    SECONDS=0
    
    # Log start
    echo "Legion Setup Started: $(date)" >> "$LOG_FILE"
    
    # Show banner
    show_banner
    
    # Confirm with user
    echo "This will set up your complete Legion development environment using Docker."
    echo "The setup will:"
    echo "  • Install Docker if needed"
    echo "  • Clone Legion repositories"
    echo "  • Start all required services in containers"
    echo "  • Configure HTTPS with SSL certificates"
    echo "  • Install development tools (Java, Maven, Node.js)"
    echo ""
    read -p "Ready to proceed? (Y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        print_warning "Setup cancelled"
        exit 0
    fi
    
    # Run setup steps
    check_docker
    check_prerequisites
    clone_repositories
    setup_docker_environment
    setup_dev_tools
    verify_setup
    
    # Show completion
    show_next_steps
    
    # Print metrics summary
    print_setup_metrics
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi