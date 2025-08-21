# Legion Enterprise Development Environment Setup

🚀 **ONE COMMAND setup that builds and deploys everything for Legion development**

Enterprise-grade automated setup with Docker containerization, full build automation, and deployment - ready to run in minutes.

## 🎯 Quick Start - Everything Built & Ready!

```bash
# Clone this repository
git clone https://github.com/legionco/legion-dev-oneclick-setup.git
cd legion-dev-oneclick-setup

# Run setup - builds backend, frontend, and starts all services
./setup.sh

# After setup completes, just run the applications:
# Backend: ./scripts/run-backend.sh
# Frontend: cd ~/Development/legion/code/console-ui && yarn start
```

## 🐳 What Gets Set Up

### Docker Services (All Automatic)
- **MySQL 8.0** with pre-loaded Legion databases from JFrog
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

- **FULLY AUTOMATED**: Setup builds backend, frontend, and configures everything
- **15-20 MINUTES**: Complete setup including Maven and Yarn builds
- **PRE-BUILT MySQL**: 913 tables in legiondb, 840 in legiondb0 ready to use
- **HTTPS READY**: Access via `https://legion.local` with valid certificates
- **PRODUCTION-LIKE**: Same Docker services as production
- **IDEMPOTENT**: Scripts are robust and can be run multiple times safely

## 💻 Requirements

- **OS**: macOS 10.15+ or Linux (Ubuntu 18.04+)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 30GB available
- **Network**: Internet access
- **Permissions**: sudo access (for /etc/hosts and tool installation)

Everything else is installed automatically!

## 🔄 What Happens When You Run `./setup.sh`

1. **Installs Prerequisites** - Docker, Java 17, Maven, Node.js, Yarn (if needed)
2. **Clones Repositories** - Enterprise and Console-UI from GitHub
3. **Starts Docker Services** - MySQL with full data, Redis, Elasticsearch, etc.
4. **Configures HTTPS** - SSL certificates and domain routing
5. **Builds Backend** - Complete Maven build with all modules
6. **Builds Frontend** - Yarn install, lerna bootstrap, and build
7. **Verifies Everything** - Ensures all services are running and ready

No prompts, no decisions - fully automated!

## 🛠️ Architecture

```
     Your Machine                    Docker Containers
┌─────────────────────┐         ┌──────────────────────┐
│                     │         │                      │
│  Backend (Java)     │────────▶│  MySQL (JFrog)       │
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
- **Pre-built Container**: MySQL 8.0 with all Legion data included
- **Full Schema**: 913 tables in legiondb, 840 tables in legiondb0
- **Instant Start**: Database ready immediately when container starts
- **Idempotent Build**: Script automatically rebuilds if needed

### Rebuilding MySQL (If Needed)
```bash
cd docker/mysql
DBDUMPS_FOLDER="/path/to/dbdumps" ./build-mysql-container.sh
```
The build script:
- Automatically stops old containers and removes volumes
- Builds new image with fresh data
- Deploys the new container automatically
- No manual steps required


## 📁 Project Structure

```
legion-dev-oneclick-setup/
├── setup.sh                   # ONE COMMAND entry point
├── docker/
│   ├── docker-compose.yml    # All services configuration
│   ├── Caddyfile            # HTTPS routing
│   └── mysql/               # MySQL container scripts
│       ├── build-mysql-container.sh  # For DevOps team only
│       └── README.md        # MySQL container docs
└── README.md                 # This file

~/Development/legion/code/     # Created by setup
├── enterprise/               # Backend repository
└── console-ui/              # Frontend repository
```

## 🚀 Starting Development

After setup completes, everything is built and ready to run:

### Backend (Enterprise)
```bash
cd ~/work/legion-dev-oneclick-setup
./scripts/run-backend.sh
# API available at http://localhost:8080
```

### Frontend (Console-UI)
```bash
cd ~/Development/legion/code/console-ui
yarn start
# UI available at http://localhost:3000
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
# Rebuild MySQL container with full data:
cd ~/work/legion-dev-oneclick-setup/docker/mysql
DBDUMPS_FOLDER="/Users/kumar.ramaiyer/work/dbdumps" ./build-mysql-container.sh
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
cd ~/work/legion-dev-oneclick-setup/docker
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

### v6.1 (Current) - FULLY AUTOMATED BUILD & DEPLOY
- 🚀 Complete automation: builds backend and frontend
- 🔨 Idempotent scripts: safe to run multiple times  
- 🐳 Automatic MySQL container deployment
- 📦 Smart build system with run-backend.sh
- 🔄 Lerna bootstrap for frontend packages
- ⚡ 15-20 minute total setup with builds

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

Transform your machine into a Legion development powerhouse in **5 minutes**!