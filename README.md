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

## 🐳 What Gets Set Up

### Docker Services (All Automatic)
- **MySQL 8.0** with pre-loaded Legion databases (uses Docker volume)
- **Elasticsearch 8.0** for search and analytics
- **Redis Master/Slave** for distributed locking
- **Caddy** reverse proxy with automatic HTTPS
- **LocalStack** for AWS services emulation
- **MailHog** for email testing
- **Jaeger** for distributed tracing

### Development Tools (Installed if Missing)
- **Docker Desktop** with optimized settings
- **Java 17** (Amazon Corretto)
- **Maven 3.9+** with JFrog settings
- **Node.js 18** with Yarn
- **Git** with SSH keys
- **SSL Certificates** (mkcert)

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

### Backend (Enterprise)
```bash
cd legion-dev-oneclick-setup
./scripts/build-and-run.sh run-backend
# API available at http://localhost:8080
```

### Frontend (Console-UI)
```bash
cd legion-dev-oneclick-setup
./scripts/build-and-run.sh run-frontend
# UI available at http://localhost:3000
```

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
- Backend Direct: `http://localhost:8080`
- Frontend Direct: `http://localhost:3000`
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
# The setup uses run-backend.sh which skips Flyway migrations
# If build fails, try manually:
cd ~/Development/legion/code/enterprise
mvn clean install -P dev -DskipTests -Dflyway.skip=true
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

### v6.2 (Current) - VOLUME-BASED MySQL & CENTRALIZED CONFIG
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