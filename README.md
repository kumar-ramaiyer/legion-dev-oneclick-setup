# Legion Enterprise Development Environment Setup

🚀 **ONE COMMAND Docker-based setup for Legion's development environment**

Enterprise-grade automated setup with Docker containerization, designed for 100+ developers across macOS and Linux platforms.

## 🎯 Quick Start - One Command!

```bash
# Clone this repository
git clone https://github.com/legionco/legion-dev-oneclick-setup.git
cd legion-dev-oneclick-setup

# Run the unified setup - ONE COMMAND for everything!
./setup.sh

# That's it! Access your development environment at:
# https://legion.local
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

- **ONE COMMAND**: Just run `./setup.sh` - everything else is automatic
- **5-10 MINUTES**: Complete setup with pre-built MySQL from JFrog
- **ZERO CONFIG**: No manual database imports or configuration files
- **HTTPS READY**: Access via `https://legion.local` with valid certificates
- **PRODUCTION-LIKE**: Same Docker services as production
- **ISOLATED**: All services in containers, no system pollution

## 💻 Requirements

- **OS**: macOS 10.15+ or Linux (Ubuntu 18.04+)
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 30GB available
- **Network**: Internet access
- **Permissions**: sudo access (for /etc/hosts and tool installation)

Everything else is installed automatically!

## 🔄 What Happens When You Run `./setup.sh`

1. **Checks & Installs Docker** - If not present
2. **Clones Repositories** - Enterprise and Console-UI from GitHub
3. **Starts Docker Services** - MySQL, Redis, Elasticsearch, etc.
4. **Configures HTTPS** - SSL certificates and domain routing
5. **Installs Dev Tools** - Java 17, Maven, Node.js, Yarn
6. **Verifies Setup** - Builds projects and checks services

You just answer "Y" to proceed and optionally your GitHub username!

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

- **Pre-built MySQL Container**: Data already loaded, hosted on JFrog
- **Instant Setup**: No 45-minute import wait  
- **Consistent Data**: Everyone gets the same database state
- **Fail-Fast Design**: Setup stops if MySQL image not available
- **Priority Check**: Local image → JFrog → Fail with clear instructions


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

After setup completes:

### Backend (Enterprise)
```bash
cd ~/Development/legion/code/enterprise
mvn spring-boot:run -Dspring.profiles.active=local
# API available at https://legion.local/api
```

### Frontend (Console-UI)
```bash
cd ~/Development/legion/code/console-ui
yarn start
# UI available at https://legion.local
```

### Direct Access
- Backend: `http://localhost:8080`
- Frontend: `http://localhost:3000`
- Caddy automatically routes HTTPS traffic

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

### Docker Not Starting?
```bash
# macOS: Open Docker Desktop app
open -a Docker

# Linux: Start Docker service
sudo systemctl start docker
```

### JFrog Login Issues?
```bash
# Login with your Okta/LDAP credentials
docker login legiontech.jfrog.io
```

### Port Conflicts?
```bash
# Stop conflicting services or change ports in docker-compose.yml
lsof -i :3306  # Check what's using MySQL port
```

### Legion MySQL Image Not Found?
```bash
# Error: "Legion MySQL image not found!"
# This means the DevOps team needs to build and push the image

# For DevOps team:
cd docker/mysql
./build-mysql-container.sh

# For developers: 
# Contact #devops-it-support for image availability
```

### Reset Everything?
```bash
cd docker
docker-compose down -v  # Remove all containers and volumes
./setup.sh  # Run setup again
```

## 📈 Performance

- **Setup Time**: 5-10 minutes total
- **Docker Images**: ~5GB download (one-time)
- **RAM Usage**: ~4GB for all containers
- **Disk Space**: ~20GB after setup

## 🆘 Support

- **Slack**: `#devops-it-support`
- **Logs**: Check `~/.legion_setup/logs/`
- **Docker Docs**: [docker/README.md](docker/README.md)
- **MySQL Container**: [docker/mysql/README.md](docker/mysql/README.md)

## 🎯 Version History

### v6.0 (Current) - ONE COMMAND SETUP
- 🚀 Single unified Docker-based approach
- 🎯 One command: `./setup.sh`
- 🐳 All services containerized
- 🔒 Automatic HTTPS with mkcert
- 📦 Pre-built MySQL from JFrog
- ⚡ 5-10 minute total setup

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