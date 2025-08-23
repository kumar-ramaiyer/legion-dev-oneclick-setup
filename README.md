# Legion Enterprise Development Environment Setup

🚀 **ONE COMMAND setup that builds and deploys everything for Legion development**

Enterprise-grade automated setup with Docker containerization, full build automation, and deployment - ready to run in minutes.

## 🎯 Quick Start - Everything Built & Ready!

```bash
# Clone this repository
git clone https://github.com/legionco/legion-dev-oneclick-setup.git
cd legion-dev-oneclick-setup

# Build MySQL data volume with full database (one-time, ~30 mins)
cd docker/mysql
./build-mysql-container.sh
# When prompted, enter path to dbdumps folder or press Enter for default
cd ../..

# Run setup - builds BOTH backend and frontend, starts all Docker services
./setup.sh

# After setup completes, everything is built! Just run the applications:
# Backend: ./scripts/build-and-run.sh run-backend
# Frontend: ./scripts/build-and-run.sh run-frontend
```

## ⏱️ Quick Start Guide - IMPORTANT TIMING INFO

### Step-by-Step After Setup:
1. **Start Backend First** (15-20 min startup)
   ```bash
   ./scripts/build-and-run.sh run-backend
   # ⏰ WAIT 15-20 MINUTES for full startup!
   ```

2. **Monitor Backend Readiness** (in a separate terminal)
   ```bash
   # Automated monitoring - will notify when ready:
   ./scripts/check-backend-ready.sh
   
   # OR manually check:
   curl http://localhost:8080/actuator/health
   ```

3. **Start Frontend** (only after backend is ready)
   ```bash
   ./scripts/build-and-run.sh run-frontend
   # Ready in ~1 minute
   ```

4. **Login to Application**
   - Go to: https://legion.local
   - Get credentials from: [Test Accounts Wiki](https://legiontech.atlassian.net/wiki/spaces/HQS/pages/1320943704/Login+Account)

## 🐳 What Gets Set Up

### Docker Services (All Automatic)
- **MySQL 8.0** with pre-loaded Legion databases (uses Docker volume)
- **Elasticsearch 8.0** for search and analytics
- **Redis Master/Slave** for distributed locking
- **Caddy** reverse proxy with automatic HTTPS
- **LocalStack** for AWS services emulation (S3, SQS auto-configured)
- **MailHog** for email testing
- **Jaeger** for distributed tracing

### LocalStack AWS Services (Auto-Configured)
The setup automatically creates:
- **S3 Buckets**:
  - `localstack-legion-data-service`
  - `localstack-legion-historical-data`
- **SQS Queues**:
  - `legion-email-queue`
  - `legion-notification-queue`

### Development Tools (Installed if Missing)
- **Docker Desktop** with optimized settings
- **Java 17** (Amazon Corretto)
- **Maven 3.9+** with JFrog settings
- **Node.js 18** with Yarn
- **Git** with SSH keys
- **SSL Certificates** (mkcert)
- **AWS CLI** with awscli-local for LocalStack

## 🔒 Automatic HTTPS Setup

The setup automatically:
- Installs mkcert for local certificate authority
- Generates trusted SSL certificates for `legion.local`
- Configures Caddy for HTTPS routing
- Updates `/etc/hosts` for local domains

Access everything via HTTPS:
- `https://legion.local` - Main application
- `https://mail.legion.local` - Email testing (MailHog)
- `https://tracing.legion.local` - Distributed tracing (Jaeger)

## ⚡ Key Benefits

- **FULLY AUTOMATED**: Setup builds BOTH backend AND frontend automatically
- **COMPLETE SETUP**: ~45-50 minutes total (30 min MySQL build + 15-20 min setup with builds)
- **PRE-BUILT MySQL**: 913 tables in legiondb, 840 in legiondb0 ready to use
- **APPLICATIONS BUILT**: Backend JAR and frontend bundles ready after setup
- **HTTPS READY**: Access via `https://legion.local` with valid certificates
- **PRODUCTION-LIKE**: Same Docker services as production
- **IDEMPOTENT**: Scripts are robust and can be run multiple times safely

## 💻 Requirements

- **OS**: macOS 10.15+ or Linux (Ubuntu 18.04+)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 30GB available
- **Network**: Internet access
- **Permissions**: sudo access (for /etc/hosts and tool installation)
- **Database Dumps**: Required for MySQL container (get from team)
  - `legiondb.sql.zip` (5.6GB)
  - `legiondb0.sql.zip` (306MB)
  - `storedprocedures.sql` (67KB)

Everything else is installed automatically!

## 🔄 What Happens When You Run `./setup.sh`

1. **Installs Prerequisites** - Docker, Java 17, Maven, Node.js, Yarn (if needed)
2. **Clones Repositories** - Enterprise and Console-UI from GitHub
3. **Starts Docker Services** - MySQL with full data, Redis, Elasticsearch, etc.
4. **Configures HTTPS** - SSL certificates and domain routing
5. **Builds Backend** - Complete Maven build with all modules (~10 mins)
6. **Builds Frontend** - Yarn install, lerna bootstrap, and full build (~5 mins)
7. **Verifies Everything** - Ensures all services are running and ready

No prompts, no decisions - fully automated! After setup, both applications are fully built and ready to run.

## 🔧 Runtime Fixes Applied (v14)

The setup automatically applies these critical fixes:

### Database Fixes
- **Collation Standardization**: Converts tables to utf8mb4_general_ci
- **Dynamic Group WorkRole**: Replaces invalid enum values
- **Enterprise Schema Mappings**: Adds dev/test enterprise IDs

### Configuration Optimizations
- **Connection Pool**: 300 max connections, 20 min pool, 30s timeout
- **Cache Timeouts**: 60 minute bootstrap, individual cache tolerances
- **Health Checks**: Disabled problematic multischema DB checks

### Fix Scripts Available
```bash
# Apply fixes manually if needed:
scripts/fix-mysql-collation.sh        # Fix collation errors
scripts/fix-dynamicgroup-workrole-db.sh  # Fix enum errors
scripts/fix-connection-pool-config.sh    # Optimize connections
scripts/fix-cache-timeout-config.sh      # Fix cache timeouts
```

## 🛠️ Architecture

```
     Your Machine                    Docker Containers
┌─────────────────────┐         ┌──────────────────────┐
│                     │         │                      │
│  Backend (Java)     │────────▶│  MySQL (Volume Data) │
│  localhost:8080     │         │  Elasticsearch       │
│                     │         │  Redis Master/Slave  │
│  Frontend (React)   │         │  LocalStack (AWS)    │
│  localhost:3000     │         │  MailHog             │
│                     │         │  Jaeger              │
└─────────────────────┘         └──────────────────────┘
           │                              ▲
           │                              │
           └──────────────────────────────┘
                   via Docker networks

   Browser Access:
   https://legion.local ──────▶ Caddy (HTTPS Proxy)
                                     │
                                ┌────┴────┐
                                ▼         ▼
                           Backend   Frontend
```


## 🗄️ Database Management

### Automatic MySQL Setup
- **Docker Volume Based**: MySQL 8.0 with data stored in Docker volume
- **Full Schema**: 913 tables in legiondb, 840 tables in legiondb0
- **EnterpriseSchema Fixed**: Correct columns (createdDate, lastModifiedDate) for backend compatibility
- **Instant Start**: Database ready immediately when container starts
- **Idempotent Build**: Script automatically rebuilds if needed

### Building/Rebuilding MySQL Data
```bash
cd docker/mysql
./build-mysql-container.sh
# Enter path to dbdumps when prompted (or press Enter for ~/Downloads/dbdumps)
```
The build script:
- Automatically stops old containers and removes volumes
- Creates a Docker volume with all data imported
- Fixes EnterpriseSchema table structure for backend compatibility
- Tests the data import and verifies table counts
- No manual steps required


## 📁 Project Structure

```
legion-dev-oneclick-setup/
├── setup.sh                   # ONE COMMAND entry point
├── scripts/
│   ├── build-and-run.sh     # Build and run backend/frontend
│   └── check-backend-ready.sh # Automated backend readiness checker
├── docker/
│   ├── docker-compose.yml    # All services configuration
│   ├── Caddyfile            # HTTPS routing
│   └── mysql/               # MySQL container scripts
│       ├── build-mysql-container.sh  # MySQL data import script
│       └── README.md        # MySQL container docs
└── README.md                 # This file

~/Development/legion/code/     # Created by setup
├── enterprise/               # Backend repository
└── console-ui/              # Frontend repository
```

## 🚀 Starting Development

After setup completes, both backend and frontend are ALREADY BUILT. You just need to run them:

### ⚠️ IMPORTANT: Backend Startup Time
**The backend takes 15-20 minutes to start** on first run due to:
- Flyway database migrations (automatic, cannot be skipped)
- Spring Boot initialization with 100+ modules
- Jetty server startup and warmup

**Wait for the backend to fully start before launching the frontend!**

### Backend (Enterprise)
```bash
cd legion-dev-oneclick-setup
./scripts/build-and-run.sh run-backend
# Note: First startup takes 15-20 minutes! Be patient.
```

### 🔍 How to Know Backend is Ready

#### 🚀 **Automated Method (Recommended)**
Use our backend readiness checker script that monitors both logs and health endpoint:
```bash
# In a separate terminal, run:
./scripts/check-backend-ready.sh

# This script will:
# - Monitor the health endpoint every 10 seconds
# - Check logs for startup indicators
# - Show progress updates (Flyway migrations, module loading)
# - Notify you when backend is fully ready
# - Exit automatically when backend is UP
```

#### Manual Methods:

1. **Health Check URL** (quickest method):
   ```bash
   # Keep checking this URL until it returns data (port 9009 for management endpoints)
   curl http://localhost:9009/actuator/health
   # Note: Status may show "DOWN" due to optional components, but endpoint responding means backend is ready
   ```

2. **Console Log Indicators** - Look for these messages:
   ```
   # ✅ When you see this, the backend is READY:
   "Started SpringWebServer in XXX seconds"
   
   # OR look for:
   "Jetty started on port(s) 8080"
   
   # OR the Jetty ASCII art:
   ╭──────────────────────────────────────╮
   │   Jetty Server Started Successfully  │
   ╰──────────────────────────────────────╯
   ```

3. **API Endpoints to Test**:
   ```bash
   # Once started, verify with:
   curl http://localhost:9009/actuator/health  # Management port
   curl http://localhost:8080/api/v1/ping     # Main application port
   ```

### Frontend (Console-UI)
```bash
# ONLY start after backend is fully running!
cd legion-dev-oneclick-setup
./scripts/build-and-run.sh run-frontend
# UI available at http://localhost:3000
```

### 🔐 Login Credentials

Once both backend and frontend are running, use these test accounts:

**For full list of test accounts and passwords, see:**
[Legion Test Accounts Wiki](https://legiontech.atlassian.net/wiki/spaces/HQS/pages/1320943704/Login+Account)

Common test accounts:
- Various role-based test users available
- Check the wiki link above for specific usernames and passwords
- Different accounts have different permission levels for testing

### Build Commands
```bash
# Build everything
./scripts/build-and-run.sh build-all

# Build only backend
./scripts/build-and-run.sh build-backend

# Build only frontend
./scripts/build-and-run.sh build-frontend
```

### Access Points
- Main App: `https://legion.local` (via Caddy proxy)
- Backend API: `http://localhost:8080`
- Backend Management: `http://localhost:9009` (actuator endpoints)
- Frontend Direct: `http://localhost:3000`
- Health Check: `http://localhost:9009/actuator/health`
- All services route through Caddy for HTTPS

## ✅ Verification

### Check Services
```bash
# View all running containers
cd docker && docker-compose ps

# Test database connection
mysql -h localhost -u legion -plegionwork -e "SHOW DATABASES;"

# Check Elasticsearch
curl http://localhost:9200/_cluster/health

# Test Redis
redis-cli ping
```

### Access Points
- Main App: `https://legion.local`
- Email Testing: `https://mail.legion.local`
- Tracing: `https://tracing.legion.local`

## 🔧 Troubleshooting

### Backend Build Fails?
```bash
# If build fails, try manually:
cd ~/Development/legion/code/enterprise
mvn clean install -P dev -DskipTests
```

### Frontend Build Fails?
```bash
# Ensure lerna bootstrap runs first:
cd ~/Development/legion/code/console-ui
npx lerna bootstrap
yarn build
```

### MySQL Missing Tables?
```bash
# Rebuild MySQL data volume:
cd docker/mysql
./build-mysql-container.sh
# Enter dbdumps path when prompted
```

### Port Conflicts?
```bash
# Check what's using ports:
lsof -i :3306  # MySQL
lsof -i :8080  # Backend
lsof -i :3000  # Frontend
```

### LocalStack/AWS Errors?
```bash
# If you see AWS connection errors in backend logs:
# 1. Verify LocalStack is running:
docker ps | grep localstack

# 2. Create/verify S3 buckets and SQS queues:
awslocal s3 ls
awslocal s3 mb s3://localstack-legion-data-service
awslocal s3 mb s3://localstack-legion-historical-data

awslocal sqs list-queues
awslocal sqs create-queue --queue-name legion-email-queue
awslocal sqs create-queue --queue-name legion-notification-queue

# 3. Test LocalStack connectivity:
curl http://localhost:4566/_localstack/health
```

### Reset Everything?
```bash
cd docker
docker-compose down -v  # Remove all containers and volumes
cd ..
./setup.sh  # Run setup again
```

## 📈 Performance

- **Setup Time**: 15-20 minutes (including builds)
- **Backend Build**: 5-10 minutes (first time)
- **Frontend Build**: 2-5 minutes
- **Docker Images**: ~8GB total
- **RAM Usage**: ~6GB for all services
- **Disk Space**: ~25GB after full setup

## 🆘 Support

- **Slack**: `#devops-it-support`
- **Logs**: Check `~/.legion_setup/logs/`
- **Docker Docs**: [docker/README.md](docker/README.md)
- **MySQL Container**: [docker/mysql/README.md](docker/mysql/README.md)

## 🎯 Version History

### v14 (Current) - RUNTIME FIXES & PERFORMANCE OPTIMIZATIONS
- 🚀 **Connection Pool Optimization**: 300 connections (was 100), 30s timeout
- ⏱️ **Cache Timeout Fixes**: 60 minute bootstrap timeout, 600s validation tolerance
- 🔧 **MySQL Collation Fix**: Standardized to utf8mb4_general_ci
- 🛠️ **Dynamic Group Fix**: WorkRole enum deserialization resolved
- 📝 **Modular Fix Scripts**: Separate scripts for each fix type
- 🏗️ **Post-Import Automation**: Fixes applied automatically after MySQL import
- ⚡ **Idempotent Configuration**: Safe to run multiple times
- 📊 **Health Check Optimization**: Disabled problematic DB health checks

### v6.2 - VOLUME-BASED MySQL & CENTRALIZED CONFIG
- 🗄️ MySQL data in Docker volume (not image) for reliability
- 🔧 Fixed EnterpriseSchema columns (createdDate/lastModifiedDate) 
- 📋 Centralized configuration (docker/config.sh) for consistent naming
- 🔨 Idempotent scripts: safe to run multiple times
- 🚀 Complete automation: builds backend and frontend
- 📦 Unified build system with build-and-run.sh
- ⚡ 15-20 minute setup + 30 min MySQL import (first time)

### Previous Versions
- v5.0: Dual approach (Docker + Traditional)
- v4.0: Python virtual environment isolation
- v3.0: Subprocess fixes, smart repo updates
- v2.0: 4-question setup
- v1.0: Initial automation

---

**🎉 Ready to start?**

```bash
git clone https://github.com/legionco/legion-dev-oneclick-setup.git
cd legion-dev-oneclick-setup
./setup.sh
```

Transform your machine into a Legion development powerhouse!

**Note**: First-time MySQL data import takes ~30 minutes. Subsequent runs are much faster.