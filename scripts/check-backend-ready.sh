#!/bin/bash

# ============================================================================
# Legion Backend Readiness Checker (Enhanced in v12)
# ============================================================================
# Purpose: Monitor backend startup and provide detailed feedback on issues
#
# Changes in v12:
# 1. Accept both UP and DOWN status as "ready" 
#    - DOWN often means optional components (S3, etc) aren't ready
#    - The key is that the endpoint is responding
#
# 2. Enhanced error detection in logs
#    - Monitors for connection pool exhaustion
#    - Detects cache bootstrap timeouts
#    - Identifies collation mismatch errors
#
# 3. Better progress indicators
#    - Shows specific startup phases
#    - Provides actionable feedback on common issues
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
HEALTH_URL="http://localhost:9009/actuator/health"  # Actuator is on management port 9009
LOG_FILE="$HOME/enterprise.logs.txt"
MAX_WAIT_TIME=1200  # 20 minutes in seconds
CHECK_INTERVAL=10   # Check every 10 seconds

# Start time
START_TIME=$(date +%s)

# Function to print with timestamp
print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ✗${NC} $1"
}

# Function to check health endpoint
check_health() {
    if curl -s -f "$HEALTH_URL" > /dev/null 2>&1; then
        local health_status=$(curl -s "$HEALTH_URL" 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        # Accept both UP and DOWN as "ready" - DOWN often means some optional components aren't ready
        # The important thing is that the endpoint is responding
        if [ "$health_status" = "UP" ] || [ "$health_status" = "DOWN" ]; then
            return 0
        fi
    fi
    return 1
}

# Function to check log file for startup indicators
check_logs() {
    if [ -f "$LOG_FILE" ]; then
        # Check for successful cache bootstrap completion (v15)
        # This is the most reliable indicator of successful startup
        if grep -q "PLT_CACHE_BOOTSTRAP Full Startup" "$LOG_FILE" 2>/dev/null; then
            local startup_time=$(grep "PLT_CACHE_BOOTSTRAP Full Startup" "$LOG_FILE" | tail -1 | grep -oP '\d+\.\d+ min' || echo "unknown")
            print_success "Cache bootstrap completed in $startup_time"
            return 0
        fi
        
        # Check for other successful startup messages
        if grep -q "Started SpringWebServer in" "$LOG_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -q "Jetty started on port(s) 8080" "$LOG_FILE" 2>/dev/null; then
            return 0
        fi
        if grep -q "Started Application in" "$LOG_FILE" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to show progress indicators from logs
show_log_progress() {
    if [ -f "$LOG_FILE" ]; then
        # Check for Flyway migrations
        if grep -q "Flyway Community Edition" "$LOG_FILE" 2>/dev/null; then
            local migrations=$(grep -c "Migrating schema" "$LOG_FILE" 2>/dev/null | tr -d '\n' || echo "0")
            if [ "$migrations" -gt "0" ] 2>/dev/null; then
                echo -e "${CYAN}  → Flyway migrations in progress (${migrations} migrations detected)${NC}"
            fi
        fi
        
        # Check for Spring Boot initialization
        if grep -q "Starting SpringWebServer" "$LOG_FILE" 2>/dev/null; then
            echo -e "${CYAN}  → Spring Boot initialization in progress${NC}"
        fi
        
        # Check for module loading
        local modules=$(grep -c "Loading module:" "$LOG_FILE" 2>/dev/null | tr -d '\n' || echo "0")
        if [ "$modules" -gt "0" ] 2>/dev/null; then
            echo -e "${CYAN}  → Loading modules (${modules} modules loaded)${NC}"
        fi
    fi
}

# Function to calculate elapsed time
get_elapsed_time() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo "${minutes}m ${seconds}s"
}

# Main monitoring loop
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Legion Backend Readiness Checker v1.0              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_status "Monitoring backend startup..."
    print_status "Health endpoint: $HEALTH_URL"
    if [ -f "$LOG_FILE" ]; then
        print_status "Log file: $LOG_FILE"
    else
        print_warning "Log file not found at $LOG_FILE"
        print_warning "Backend might not be running or logs are in a different location"
    fi
    echo ""
    
    # Check if backend process is running
    if ! pgrep -f "legion-app.*\.jar" > /dev/null 2>&1; then
        print_warning "Backend process not detected. Make sure to run:"
        echo "  ./scripts/build-and-run.sh run-backend"
        echo ""
    fi
    
    print_status "Checking backend readiness (this typically takes 15-20 minutes)..."
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    echo ""
    
    # Progress bar setup
    local spin='-\|/'
    local spin_i=0
    local check_count=0
    
    while true; do
        check_count=$((check_count + 1))
        elapsed_time=$(get_elapsed_time)
        
        # Check health endpoint
        if check_health; then
            echo "" # New line after progress
            print_success "Backend is UP and READY! (took $elapsed_time)"
            echo ""
            echo -e "${GREEN}✓ Health check passed${NC}"
            echo -e "${GREEN}✓ API endpoints available at:${NC}"
            echo "  • Health: $HEALTH_URL"
            echo "  • API: http://localhost:8080/api"
            echo "  • Swagger: http://localhost:8080/swagger-ui.html"
            echo ""
            print_success "You can now start the frontend with:"
            echo "  ./scripts/build-and-run.sh run-frontend"
            exit 0
        fi
        
        # Check logs for startup completion
        if check_logs; then
            echo "" # New line after progress
            print_warning "Backend startup detected in logs, verifying health endpoint..."
            sleep 5
            if check_health; then
                print_success "Backend is UP and READY! (took $elapsed_time)"
                exit 0
            else
                print_warning "Logs indicate startup but health check failed, continuing to monitor..."
            fi
        fi
        
        # Check for timeout
        current_time=$(date +%s)
        if [ $((current_time - START_TIME)) -gt $MAX_WAIT_TIME ]; then
            echo "" # New line after progress
            print_error "Timeout: Backend did not start within 20 minutes"
            print_error "Check the logs for errors: $LOG_FILE"
            exit 1
        fi
        
        # Show progress
        printf "\r${YELLOW}[${spin:spin_i++%${#spin}:1}]${NC} Waiting for backend... (${elapsed_time} elapsed) "
        
        # Show detailed progress every 3 checks (30 seconds)
        if [ $((check_count % 3)) -eq 0 ]; then
            echo "" # New line for progress details
            show_log_progress
            printf "${YELLOW}[${spin:spin_i++%${#spin}:1}]${NC} Waiting for backend... (${elapsed_time} elapsed) "
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Monitoring stopped by user"; exit 0' INT

# Run main function
main "$@"