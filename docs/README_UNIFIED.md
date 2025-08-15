# Legion Unified Development Setup

## Overview
This is a unified setup guide for both Legion Enterprise (backend) and Console-UI (frontend) projects.

## Version Requirements

### Common Software
- **Java:** JDK 17 (Amazon Corretto)
- **Maven:** 3.9.9 (latest stable)
- **MySQL:** 8.0+
- **Docker:** Latest
- **Git:** Latest
- **Homebrew:** Latest (macOS)

### Node.js Strategy
Since the projects have conflicting Node.js requirements:
- **Enterprise (Backend):** Requires Node.js 13.8.0 with npm 7.11.2
- **Console-UI (Frontend):** Requires Node.js 16+ (we'll use latest)

**Solution:** Use NVM to switch between versions:
- Default: Latest Node.js (for console-ui)
- Use `nvm use 13.8.0` when working on enterprise backend

### Frontend-Specific
- **Yarn:** Latest (for console-ui monorepo)
- **Lerna:** 5.4.0 or 6.x (NOT v7)

### Backend-Specific
- **Elasticsearch:** 8.0.0 (via Docker)
- **Redis:** Latest (via Docker)
- **LocalStack:** Latest (for AWS simulation)

## Installation Order

1. **System Tools**
   - Homebrew (macOS)
   - Git
   - Docker Desktop

2. **Languages & Runtimes**
   - Java 17 (Amazon Corretto)
   - NVM (Node Version Manager)
   - Node.js (latest via NVM)
   - Node.js 13.8.0 (via NVM for backend compatibility)

3. **Build Tools**
   - Maven 3.9.9
   - Yarn (global)
   - Lerna@6 (global)

4. **Databases & Services**
   - MySQL 8.0
   - Docker containers (Elasticsearch, Redis, LocalStack)

5. **IDEs**
   - IntelliJ IDEA Community Edition
   - VS Code (optional)

## Project Structure
```
~/Development/legion/
├── code/
│   ├── enterprise/        # Backend (Java/Maven)
│   └── console-ui/        # Frontend (React/Angular)
├── data/                  # Database dumps
└── config/                # Configuration files
```

## Quick Setup Commands

### Install Node Versions
```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Install latest Node.js (for console-ui)
nvm install node
nvm alias default node

# Install Node 13.8.0 (for enterprise)
nvm install 13.8.0
npm install -g npm@7.11.2  # While using 13.8.0
```

### Switch Node Versions
```bash
# For console-ui (frontend) work
nvm use default  # Uses latest

# For enterprise (backend) work
nvm use 13.8.0
```

### Frontend Setup (console-ui)
```bash
nvm use default  # Use latest Node
npm install -g yarn
npm install -g lerna@6
cd ~/Development/legion/code/console-ui
yarn
yarn lerna bootstrap
```

### Backend Setup (enterprise)
```bash
nvm use 13.8.0  # Use Node 13.8.0
cd ~/Development/legion/code/enterprise
mvn clean install -DskipTests
```

## Environment Variables
Add to your `~/.zshrc` or `~/.bashrc`:
```bash
# Java
export JAVA_HOME=$(/usr/libexec/java_home -v 17)

# Maven
export MAVEN_HOME=/usr/local/maven
export PATH=$PATH:$MAVEN_HOME/bin

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Auto-switch Node versions based on directory
# Add .nvmrc files to project roots:
# - console-ui/.nvmrc: "node" (for latest)
# - enterprise/.nvmrc: "13.8.0"
autoload -U add-zsh-hook
load-nvmrc() {
  if [[ -f .nvmrc && -r .nvmrc ]]; then
    nvm use
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
```

## Docker Services
```bash
# Elasticsearch
docker run -d --name elasticsearch \
  -p 9200:9200 -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.0.0

# Redis Master
docker run -d --name redis-master \
  -p 6379:6379 \
  redis:latest

# Redis Slave
docker run -d --name redis-slave \
  -p 6380:6379 \
  redis:latest

# LocalStack (AWS services)
docker run -d --name localstack \
  -p 4566:4566 \
  localstack/localstack:latest
```

## Troubleshooting

### Node Version Issues
- Always check which Node version you're using: `node -v`
- Enterprise backend specifically needs 13.8.0
- Console-UI works with latest Node.js
- Use `.nvmrc` files in project roots for auto-switching

### Yarn vs NPM
- **Console-UI:** MUST use Yarn (not npm)
- **Enterprise:** Can use npm (when in Node 13.8.0)
- Never mix package managers in the same project

### Lerna Version
- Must use Lerna 5.x or 6.x
- Lerna 7.x will NOT work with console-ui
- Install specific version: `npm install -g lerna@6`

### Port Conflicts
Default ports used:
- 3306: MySQL
- 6379: Redis Master
- 6380: Redis Slave
- 8080: Enterprise backend
- 9000: Console-UI frontend
- 9200: Elasticsearch

## Verification Commands
```bash
# Check all versions
java -version          # Should show 17
mvn --version          # Should show 3.9.9
node -v                # Latest when in console-ui
nvm use 13.8.0 && node -v  # Should show 13.8.0
yarn --version         # Should be installed
lerna --version        # Should show 5.x or 6.x
docker --version       # Should be installed
mysql --version        # Should show 8.0+
```