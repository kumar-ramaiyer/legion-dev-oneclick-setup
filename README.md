# Legion Enterprise Development Environment Setup

🚀 **One-click automated setup for Legion's development environment**

Enterprise-grade setup automation designed for 100+ developers across macOS and Linux platforms.

## Quick Start - TRUE ONE CLICK!

```bash
# 1. Clone or download this setup package
cd legion-dev-oneclick-setup

# 2. Run the setup - that's it!
./setup.sh

# The script will:
#   - Ask you just 4 questions (name, email, github, ssh passphrase)
#   - Install everything automatically  
#   - No command line options needed!
#   - Always runs in verbose mode for transparency
```

## What Gets Installed

- ✅ **Java 17** (Amazon Corretto) - Specifically checks for version 17
- ✅ **Maven 3.9.9+** with JFrog Artifactory settings
- ✅ **Node.js 18+** with npm (compatible with both enterprise and console-ui)
- ✅ **Yarn** (latest) for frontend package management
- ✅ **Lerna v6** for monorepo management
- ✅ **MySQL 8.0** with proper UTF8MB4 character set
- ✅ **Yasha** for template processing
- ✅ **Python packages** (PyYAML, mysql-connector-python)
- ✅ **Docker Desktop** with automatic container setup:
  - Elasticsearch 8.0.0 (single-node, no security)
  - Redis master/slave for distributed locking (ports 6379/6380)
  - LocalStack for AWS service emulation
- ✅ **Git & GitHub** SSH key setup with required passphrase
- ✅ **GLPK library** (installed after Maven build on macOS)
- ✅ **IntelliJ IDEA** run configurations (optional)

## Documentation

- 📖 **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Comprehensive user guide and troubleshooting
- 🔧 **[README_SETUP.md](README_SETUP.md)** - Technical documentation for developers

## Configuration

The setup will ask you just 4 questions:
1. **Your full name** - Used for Git configuration
2. **Your email address** - Used for Git commits  
3. **Your GitHub username** - For repository access
4. **SSH key passphrase** - Required for security (e.g., "Legion WFM is awesome")

That's it! Everything else is automated with smart defaults:
- MySQL password: `mysql123`
- Installation path: `~/Development/legion/code/`
- Node.js: Version 18+ (works with both repos)
- Docker resources: 4 CPUs, 4GB RAM
- Verbose logging: Always enabled for transparency
- Build profile: Development (`-P dev`)
- Timeout: 30 minutes for large repository clones

## Requirements

- **OS**: macOS 10.15+ or Linux (Ubuntu 18.04+, RHEL 7+)
- **Python**: 3.7+
- **Disk Space**: 50GB+ available
- **Network**: Internet access for downloads
- **Permissions**: Administrator/sudo access

## Support

- 📞 **Slack**: `#devops-it-support`
- 🎫 **Tickets**: [CPL-487 template](https://legiontech.atlassian.net/browse/CPL-487)
- 📚 **Docs**: See SETUP_GUIDE.md for detailed help

## 🔄 How It Works - The Complete Algorithm

### Setup Process Overview

The setup follows a carefully orchestrated 6-stage process that transforms a fresh macOS/Linux system into a fully configured Legion development environment:

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│ 1. Environment  │────▶│ 2. Software  │────▶│ 3. Repository   │
│   Validation    │     │ Installation │     │     Cloning     │
└─────────────────┘     └──────────────┘     └─────────────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│ 6. Final Setup  │◀────│ 5. Database  │◀────│ 4. Docker       │
│    Summary      │     │     Setup    │     │   Containers    │
└─────────────────┘     └──────────────┘     └─────────────────┘
```

### Stage-by-Stage Breakdown

#### Stage 1: Environment Validation (2-3 minutes)
- **System Requirements Check**: OS version, available disk space (50GB+), RAM
- **Python Environment Setup**: Creates virtual environment in `./venv`
- **Network Connectivity Test**: Verifies access to GitHub, JFrog, npm registry
- **Port Availability Check**: Ensures required ports are free (3306, 8080, 9200, 6379)
- **Existing Installation Detection**: Checks for partial setups to avoid conflicts

#### Stage 2: Software Installation (10-15 minutes)
- **Package Manager Setup**: Installs/updates Homebrew on macOS
- **Java Installation**: Amazon Corretto JDK 17 (specifically checks for version 17)
- **Maven Setup**: Version 3.9.9+ with JFrog Artifactory settings.xml
- **Node.js Environment**: Version 18+ with npm, yarn, and lerna v6
- **MySQL Server**: Version 8.0 with UTF8MB4 character set and collation
- **Python Packages**: Yasha, PyYAML, mysql-connector-python via pipx
- **Git Configuration**: User details, SSH keys with passphrase, GitHub CLI
- **Docker Desktop**: Installation and resource allocation (4 CPUs, 4GB RAM)

#### Stage 3: Repository Setup (30-45 minutes for large repos)
- **SSH Key Generation**: Ed25519 keys with required passphrase
- **Repository Cloning**: Uses HTTPS initially, then sets SSH for future operations
- **Submodule Handling**: Uses `git submodule update --init --recursive`
- **Timeout Configuration**: 30-minute timeout for large repository clones
- **Config Files**: Creates application.yml and local.values.yml

#### Stage 4: Docker Container Setup (5-7 minutes)
- **Elasticsearch Container**:
  ```yaml
  Image: elasticsearch:8.0.0
  Memory: 512MB
  Ports: 9200, 9300
  Config: Single-node, no security
  ```
- **Redis Master/Slave**:
  ```yaml
  Master: Port 6379
  Slave: Port 6380
  Purpose: Distributed locking
  ```
- **LocalStack**:
  ```yaml
  Services: S3, SQS, Lambda emulation
  Port: 4566
  ```

#### Stage 5: Database Setup (15-45 minutes)
- **Database Creation**: legiondb, legiondb0 with proper privileges
- **Snapshot Download**: Automated Google Drive download (3.2GB compressed)
- **Data Import**: Fast snapshot restore or full SQL import
- **Schema Updates**: Stored procedures, triggers, collation fixes
- **User Setup**: Creates development user with full access

#### Stage 6: Build & Verification (15-25 minutes)
- **Maven Build**: `mvn clean install -P dev -DskipTests -Dcheckstyle.skip -Djavax.net.ssl.trustStorePassword=changeit`
- **GLPK Library**: Installs optimization library after build (macOS)
- **Frontend Setup**: Yarn install, Lerna bootstrap, Lerna build for console-ui
- **Service Validation**: Tests all connections and endpoints
- **IDE Configuration**: IntelliJ run configurations (optional)

### 📊 Setup Completion Summary

After successful completion, you'll see a comprehensive summary showing:

```
====================================================================
                 LEGION DEVELOPMENT SETUP COMPLETE! 
====================================================================

📋 CONFIGURATION SUMMARY:
─────────────────────────────────────────────────────────────────
  User Name:           [Your Name]
  Email:              [your.email@example.com]
  GitHub Username:    [your-github-username]
  Elasticsearch ID:   [auto-generated]
  Repository Path:    ~/Development/legion/code/enterprise
  MySQL Password:     [configured]

✅ INSTALLED SOFTWARE:
─────────────────────────────────────────────────────────────────
  ✓ Homebrew         3.6.0
  ✓ Java (Corretto)  17.0.8
  ✓ Maven            3.9.9
  ✓ Node.js          18.17.0
  ✓ npm              9.6.7
  ✓ Yarn             1.22.19
  ✓ MySQL            8.0.34
  ✓ Docker Desktop   4.22.0
  ✓ Git              2.41.0
  ✓ GitHub CLI       2.32.0

🐳 DOCKER CONTAINERS:
─────────────────────────────────────────────────────────────────
  ✓ Elasticsearch    Running on http://localhost:9200
  ✓ Redis Master     Running on localhost:6379
  ✓ Redis Slave      Running on localhost:6380
  ✓ LocalStack       Running on http://localhost:4566

🗄️ DATABASE STATUS:
─────────────────────────────────────────────────────────────────
  ✓ MySQL Service    Running (PID: 12345)
  ✓ legiondb         250 tables, 3.8GB data
  ✓ legiondb0        180 tables, 2.1GB data
  ✓ Connection Test  Success (3ms latency)

🏗️ BUILD STATUS:
─────────────────────────────────────────────────────────────────
  ✓ Maven Build      SUCCESS [Total time: 4:32 min]
  ✓ Tests Skipped    Will run on first commit
  ✓ Console UI       Dependencies installed
  ✓ Application.yml  Configured for local development

📁 KEY LOCATIONS:
─────────────────────────────────────────────────────────────────
  Repository:        ~/Development/legion/code/enterprise
  Maven Settings:    ~/.m2/settings.xml
  SSH Key:          ~/.ssh/id_ed25519
  Logs:             ~/.legion_setup/logs/
  IntelliJ Config:  ~/Development/legion/code/enterprise/.idea/

🚀 NEXT STEPS:
─────────────────────────────────────────────────────────────────
  1. Open IntelliJ IDEA and import the project
  2. Run Application.java with 'local' profile
  3. Access console at http://localhost:8080
  4. Login with test credentials (see Confluence)

⏱️ Total Setup Time: 47 minutes 23 seconds
====================================================================
```

## 🔒 Python Virtual Environment Isolation

**ALL Python operations run in an isolated virtual environment** to prevent conflicts with your system Python:

- ✅ **Automatic venv creation**: The setup automatically creates `./venv` on first run
- ✅ **Isolated dependencies**: All Python packages install only in the virtual environment
- ✅ **No system pollution**: Your system Python remains untouched
- ✅ **Consistent execution**: All scripts automatically use venv Python

### Virtual Environment Commands:
```bash
make venv         # Create virtual environment
make venv-deps    # Ensure all dependencies are installed
make venv-status  # Check virtual environment status
make venv-clean   # Remove virtual environment
```

## 📁 Directory Structure

The setup uses a hybrid approach for file organization:

### Local Project Directory (`./`)
```
legion-dev-oneclick-setup/
├── venv/                       # Python virtual environment (git-ignored)
├── setup_config.yaml           # Your configuration file
├── setup.sh                    # Main entry point
├── legion_dev_setup.py         # Core orchestrator
├── setup_modules/              # Setup components
├── scripts/                    # Helper scripts (all use venv)
└── docs/                       # Documentation files
```

### Home Directory (`~/.legion_setup/`)
```
~/.legion_setup/
├── logs/                       # Persistent setup logs
│   ├── setup_full_*.log      # Complete setup logs
│   ├── validation_*.log      # Validation results
│   └── installer_*.log       # Installation details
├── backups/                    # Configuration backups
│   └── settings.xml.backup    # Maven settings backup
└── temp/                       # Temporary download files
```

### Why This Structure?
- **Virtual Environment** (`./venv`): Project-specific to avoid conflicts
- **Configuration** (`./setup_config.yaml`): Project-specific for version control
- **Logs** (`~/.legion_setup/logs/`): Persistent across repo clones for debugging
- **Backups** (`~/.legion_setup/backups/`): Safe location for original configs

## 🔍 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Check what's using a port
   lsof -i :3306  # For MySQL
   lsof -i :9200  # For Elasticsearch
   ```

2. **Database Import Fails**
   - Check disk space: `df -h`
   - Verify MySQL is running: `mysql.server status`
   - Check logs: `tail -f ~/.legion_setup/logs/setup_full_*.log`

3. **Maven Build Errors**
   - Verify JFrog token in `~/.m2/settings.xml`
   - Clear Maven cache: `rm -rf ~/.m2/repository`
   - Check Java version: `java -version`

4. **Virtual Environment Issues**
   ```bash
   # Recreate virtual environment
   ./scripts/setup_venv.sh clean
   ./scripts/setup_venv.sh create
   ```

## 🛠️ Advanced Features

### Partial Setup Recovery
The setup automatically detects and recovers from partial installations:
- Skips already installed software
- Resumes from last successful stage
- Preserves existing configurations

### Parallel Processing
Where possible, the setup runs tasks in parallel:
- Concurrent software downloads
- Parallel Docker container startup
- Simultaneous database operations

### Intelligent Defaults
- Auto-generates Elasticsearch modifier from user name
- Sets optimal Docker resource limits
- Configures Maven with parallel builds
- Enables MySQL query cache

---

**🎉 Ready to start? Run `./setup.sh` and transform your machine into a Legion development powerhouse in under an hour!**
