#!/bin/bash
set -e

# Legion Enterprise Development Environment Setup Script
# Wrapper script for easy execution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/legion_dev_setup.py"
CONFIG_FILE="$SCRIPT_DIR/setup_config.yaml"
CONFIG_TEMPLATE="$SCRIPT_DIR/setup_config.yaml.template"
VENV_DIR="$SCRIPT_DIR/venv"

# Setup logging
LOG_DIR="$HOME/.legion_setup/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup_full_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to start logging
start_logging() {
    # Create a named pipe for tee
    exec 3>&1 4>&2
    # Redirect stdout and stderr to tee, which writes to both console and log file
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    
    echo "========================================" >> "$LOG_FILE"
    echo "Legion Setup Started: $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# Function to stop logging
stop_logging() {
    # Only restore if descriptors exist
    if [[ -e /dev/fd/3 ]]; then
        exec 1>&3 3>&-
    fi
    if [[ -e /dev/fd/4 ]]; then
        exec 2>&4 4>&-
    fi
    
    echo "" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "Legion Setup Ended: $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

# Function to setup Python virtual environment
setup_python_environment() {
    print_status "Setting up Python virtual environment..."
    
    # Create virtual environment
    if [[ -d "$VENV_DIR" ]]; then
        print_status "Removing existing virtual environment..."
        rm -rf "$VENV_DIR"
    fi
    
    python3 -m venv "$VENV_DIR"
    print_success "Virtual environment created"
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    print_success "Virtual environment activated"
    
    # Upgrade pip and install requirements
    print_status "Installing Python dependencies..."
    "$VENV_DIR/bin/pip" install --upgrade pip >/dev/null 2>&1
    "$VENV_DIR/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
    print_success "Python dependencies installed"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        echo "Please install Python 3.7+ and try again"
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    if [[ $(echo "$python_version 3.7" | tr ' ' '\n' | sort -V | head -n1) != "3.7" ]]; then
        print_error "Python 3.7+ is required (found: $python_version)"
        exit 1
    fi
    
    print_success "Python $python_version found"
}

# Function to setup configuration
setup_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "Configuration file not found."
        print_status "Creating configuration (just 3 quick questions!)..."
        
        # Run simplified configuration creator using venv python if available
        if [[ -f "$VENV_DIR/bin/python" ]]; then
            PYTHON_CMD="$VENV_DIR/bin/python"
        else
            PYTHON_CMD="python3"
        fi
        
        if $PYTHON_CMD create_config_simple.py; then
            print_success "Configuration created successfully!"
        else
            # Fall back to creating a default config if the script fails
            print_warning "Interactive config failed, using defaults..."
            
            print_status "Creating default configuration..."
            # Create minimal default config
            cat > "$CONFIG_FILE" << 'EOF'
user:
  name: "Legion Developer"
  email: "developer@legion.com"
  github_username: "developer"

paths:
  enterprise_repo_path: "~/Development/legion/code/enterprise"
  console_ui_repo_path: "~/Development/legion/code/console-ui"
  maven_install_path: ""
  jdk_install_path: ""
  mysql_data_path: ""

versions:
  node: "latest"
  yarn: "latest"
  lerna: "6"
  maven: "3.9.9"
  jdk: "17"
  mysql: "8.0"
  elasticsearch: "8.0.0"

database:
  mysql_root_password: "mysql123"
  legion_db_password: "legionwork"
  elasticsearch_index_modifier: "developer"

setup_options:
  skip_intellij_setup: false
  skip_database_import: false
  use_snapshot_import: true
  skip_docker_setup: false
  install_homebrew: true
  setup_vpn_check: false
  setup_ssh_keys: true
  clone_repositories: true

aws:
  setup_localstack: true
  setup_aws_cli: false

docker:
  memory_gb: 4.0
  cpus: 4
  swap_gb: 1.0

dev_environment:
  setup_redis: true
  setup_elasticsearch: true
  setup_frontend: true
  create_intellij_config: true

network:
  proxy_host: ""
  proxy_port: ""
  no_proxy: "localhost,127.0.0.1"

advanced:
  parallel_downloads: true
  verbose_logging: true
  dry_run: false
  auto_confirm: true
  backup_existing_config: true

git:
  generate_ssh_key: true
  setup_github_cli: true
  ssh_key_type: "ed25519"
  git_editor: "nano"

repositories:
  enterprise:
    url: "git@github.com:legionco/enterprise.git"
    path: "~/Development/legion/code/enterprise"
    clone_submodules: true
  console_ui:
    url: "git@github.com:legionco/console-ui.git"
    path: "~/Development/legion/code/console-ui"
    clone_submodules: false

jfrog:
  download_settings_xml: true
  artifactory_url: ""

database_snapshots:
  gdrive_folder_url: "https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK"
  file_ids:
    storedprocedures: ""
    legiondb: ""
    legiondb0: ""

custom_commands:
  pre_setup: []
  post_setup: []
  pre_build: []
  post_build: []

notifications:
  email_on_completion: false
  slack_webhook: ""
  teams_webhook: ""
EOF
            print_success "Default configuration created!"
            print_warning "⚠️  Remember to update user details in $CONFIG_FILE before running setup"
        fi
        
        # Verify config was created
        if [[ ! -f "$CONFIG_FILE" ]]; then
            print_error "Configuration file was not created properly"
            exit 1
        fi
    fi
    
    print_success "Configuration file ready"
}

# Function to show banner
show_banner() {
    # Get database URL from config if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        DB_URL=$(grep -A1 "gdrive_folder_url:" "$CONFIG_FILE" 2>/dev/null | tail -1 | sed 's/.*gdrive_folder_url: *//' | tr -d "'\"")
    fi
    if [[ -z "$DB_URL" ]]; then
        DB_URL="https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK"
    fi
    
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║               LEGION ENTERPRISE SETUP                       ║
║          Development Environment Automation                  ║
╚══════════════════════════════════════════════════════════════╝

This script will set up your complete Legion development environment.

Components included:
• Java 17 (Amazon Corretto)
• Maven 3.9.9+
• Node.js (latest) with Yarn & Lerna
• MySQL 8.0 with Legion databases
• Docker Desktop with:
  - Elasticsearch 8.0.0 container
  - Redis master/slave containers
  - LocalStack for AWS emulation
• IntelliJ IDEA configuration (optional)

Database snapshots: 
  $DB_URL

Estimated time: 45-90 minutes
Required space: ~50GB

EOF
}

# Function to show help
show_help() {
    cat << 'EOF'
Legion Enterprise Development Environment Setup - ONE CLICK SETUP

Usage: ./setup.sh

This is a ONE-CLICK setup that will:
1. Ask you 4 simple questions (name, email, github, ssh passphrase)
2. Install all required software automatically
3. Configure your complete development environment
4. Get you coding in 45-90 minutes!

Just run: ./setup.sh

That's it! No options needed.

For documentation, see README.md
EOF
}

# Main execution
main() {
    # Start logging before anything else
    start_logging
    
    # Ensure logging is stopped on exit
    trap 'stop_logging' EXIT INT TERM
    
    print_status "Full log is being saved to: $LOG_FILE"
    
    # Show recent log files if any exist
    if ls "$LOG_DIR"/setup_full_*.log 1> /dev/null 2>&1; then
        echo ""
        print_status "Recent setup logs:"
        ls -lt "$LOG_DIR"/setup_full_*.log | head -5 | awk '{print "  • " $9 " (" $6 " " $7 " " $8 ")"}'
    fi
    echo ""
    
    local args=()
    
    # Parse command line arguments - simplified for one-click
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                # Ignore any other arguments for true one-click experience
                shift
                ;;
        esac
    done
    
    # Always use verbose mode for transparency
    args+=("--verbose")
    
    # Show banner
    show_banner
    
    # Check if this is just a validation or report generation
    if [[ " ${args[*]} " =~ " --validate-only " ]] || [[ " ${args[*]} " =~ " --generate-report " ]]; then
        python3 "$PYTHON_SCRIPT" "${args[@]}"
        exit $?
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Setup Python virtual environment if needed
    if [[ ! -d "$VENV_DIR" ]] || [[ "$FORCE_REINSTALL" == "true" ]]; then
        setup_python_environment
    else
        # Just activate existing environment
        source "$VENV_DIR/bin/activate"
        print_success "Using existing virtual environment"
    fi
    
    # Setup configuration (using venv python for create_config.py if needed)
    setup_config
    
    # Auto-proceed for one-click setup (no confirmation needed)
    
    # Run the Python setup script with force-continue for one-click setup
    print_status "Starting Legion development environment setup..."
    
    # Use python from virtual environment
    if "$VENV_DIR/bin/python" "$PYTHON_SCRIPT" --force-continue "${args[@]}"; then
        print_success "Setup completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Open IntelliJ IDEA and import ~/Development/legion/code/enterprise"
        echo "2. Use the auto-configured run configurations"
        echo "3. Access the application at: http://localhost:8080/legion/?enterprise=LegionCoffee"
        echo ""
        echo "For troubleshooting, see SETUP_GUIDE.md"
        echo ""
        print_success "Full setup log saved to: $LOG_FILE"
        stop_logging
    else
        print_error "Setup failed. Check the logs in ~/.legion_setup/logs/"
        echo "For help, see SETUP_GUIDE.md or contact #devops-it-support"
        echo ""
        print_error "Full setup log saved to: $LOG_FILE"
        stop_logging
        exit 1
    fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi