# Legion Enterprise Development Environment Setup

**Enterprise-grade automated setup for Legion's development environment**

Version: 1.0.0  
Target Users: 100+ developers  
Platforms: macOS, Linux  
Estimated Setup Time: 45-90 minutes  

---

## 🚀 Quick Start

### Prerequisites
- Python 3.7+ installed
- Administrator/sudo access
- Stable internet connection
- 50GB+ available disk space

### One-Click Setup

```bash
# 1. Download the setup files
git clone <repository-url> legion-setup
cd legion-setup

# 2. Configure your preferences
cp setup_config.yaml.template setup_config.yaml
# Edit setup_config.yaml with your preferences

# 3. Run the setup
python3 legion_dev_setup.py
```

### Alternative: Custom Configuration

```bash
# Create custom config file
python3 legion_dev_setup.py --config my_custom_config.yaml

# Dry run to see what would be done
python3 legion_dev_setup.py --dry-run

# Verbose output for troubleshooting
python3 legion_dev_setup.py --verbose
```

---

## 📋 What This Setup Includes

### Core Software Installation
- ✅ **Java**: Amazon Corretto JDK 17
- ✅ **Maven**: 3.9.9 (configurable)
- ✅ **Node.js**: 13.8.0 via NVM
- ✅ **npm**: 7.11.2
- ✅ **MySQL**: 8.0 with Legion databases
- ✅ **Docker**: Elasticsearch and Redis containers
- ✅ **Python Tools**: yasha, mysql-connector-python

### Development Environment
- ✅ **Database Setup**: legiondb and legiondb0 with sample data
- ✅ **Docker Services**: Elasticsearch 8.0.0, Redis cluster
- ✅ **Configuration**: Maven settings.xml from JFrog
- ✅ **Git Repository**: Clone and setup enterprise repo
- ✅ **Build Verification**: Complete Maven build test

### IDE Integration (Optional)
- ✅ **IntelliJ IDEA**: Configuration templates
- ✅ **Run Configurations**: Backend application setup
- ✅ **Code Style**: Legion coding standards
- ✅ **Plugins**: Lombok, annotation processing

---

## ⚙️ Configuration Guide

### Basic Configuration (`setup_config.yaml`)

```yaml
# Minimal required configuration
user:
  name: "Your Name"
  email: "your.email@legion.com"
  github_username: "yourusername"

setup_options:
  use_snapshot_import: true    # Fast database import
  skip_intellij_setup: false  # Include IntelliJ config
  
versions:
  node: "13.8.0"
  npm: "7.11.2" 
  maven: "3.9.9"
```

### Advanced Configuration Options

#### Database Options
```yaml
database:
  mysql_root_password: ""           # Leave blank for prompt
  legion_db_password: "legionwork"  # Default password
  elasticsearch_index_modifier: "yourname"  # Personal ES index

setup_options:
  use_snapshot_import: true   # true = fast (~25min), false = full dump (~1 day)
  skip_database_import: false # Skip if you have existing data
```

#### Network & Corporate Environment
```yaml
network:
  proxy_host: "proxy.company.com"  # Corporate proxy
  proxy_port: "8080"
  no_proxy: "localhost,127.0.0.1"

advanced:
  parallel_downloads: true    # Speed up downloads
  verbose_logging: false     # Debug information
  auto_confirm: false        # Skip confirmations (use with caution)
```

#### Custom Paths
```yaml
paths:
  maven_install_path: "/opt/maven"      # Custom Maven location
  enterprise_repo_path: "~/dev/legion"  # Custom repo location
```

---

## 🛠️ Troubleshooting

### Common Issues

#### Permission Errors
```bash
# Fix common permission issues
sudo chown -R $(whoami) /usr/local
sudo chown -R $(whoami) ~/.m2
```

#### Port Conflicts
```bash
# Check what's using required ports
lsof -i :3306  # MySQL
lsof -i :9200  # Elasticsearch
lsof -i :6379  # Redis

# Kill conflicting processes
sudo kill -9 <PID>
```

#### Docker Issues
```bash
# Restart Docker Desktop
# macOS: Applications → Docker → Restart

# Check Docker status
docker info
docker ps -a

# Check specific containers
docker ps | grep elasticsearch
docker ps | grep redis

# View container logs
docker logs elasticsearch
docker logs redis-master

# Clean up and restart containers
docker rm -f elasticsearch redis-master redis-slave
docker system prune -f

# Manually start Elasticsearch
docker run -d --name elasticsearch \
  -p 9200:9200 -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.0.0

# Test Elasticsearch
curl -X GET "http://localhost:9200/_cluster/health?pretty"

# Test Redis
redis-cli ping
```

#### MySQL Connection Issues
```bash
# Reset MySQL root password
mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';
FLUSH PRIVILEGES;

# Start MySQL service
brew services start mysql          # macOS
sudo systemctl start mysql         # Linux
```

### Database Snapshot Configuration (Optional)

For automatic database snapshot downloads from Google Drive:

1. **Extract Google Drive File IDs:**
```bash
python3 extract_gdrive_ids.py
```

2. **Add IDs to Configuration:**
Edit `setup_config.yaml` and add the file IDs:
```yaml
jfrog:
  db_snapshot_ids:
    storedprocedures: "1ABC..."  # Your file ID
    legiondb: "1DEF..."          # Your file ID
    legiondb0: "1GHI..."          # Your file ID
```

With these configured, the setup will automatically download database snapshots.

### Validation and Diagnostics

#### Run Full System Validation
```bash
python3 legion_dev_setup.py --validate-only
```

#### Check Specific Components
```bash
# Test database connectivity
python3 -c "
import mysql.connector
conn = mysql.connector.connect(host='localhost', user='legion', password='legionwork', database='legiondb')
print('✅ Database connection successful')
conn.close()
"

# Test Elasticsearch
curl -X GET "http://localhost:9200/_cluster/health?pretty"

# Test Redis
docker exec redis-master redis-cli ping
```

#### View Setup Logs
```bash
# Setup logs are saved to:
ls -la ~/.legion_setup/logs/

# View latest log
tail -f ~/.legion_setup/logs/setup_*.log
```

### Recovery Procedures

#### Restart Setup from Failed Step
```bash
# Setup creates checkpoints - you can resume from specific stages
python3 legion_dev_setup.py --resume-from=database_setup
```

#### Clean Installation
```bash
# Remove all setup artifacts and start over
rm -rf ~/.legion_setup
docker rm -f elasticsearch redis-master redis-slave
# Then run setup again
```

---

## 📊 Enterprise Features

### Multi-User Support
- **Concurrent Setups**: Multiple users can run setup simultaneously
- **Personalized Configs**: Each user gets unique ES indices and configs  
- **Collision Avoidance**: Automatic handling of port and resource conflicts

### Corporate Network Support
- **Proxy Configuration**: Automatic proxy detection and configuration
- **Certificate Handling**: Corporate SSL certificate management
- **Network Validation**: Connectivity tests for corporate environments

### Monitoring & Reporting
- **Progress Tracking**: Real-time setup progress with ETA
- **Validation Reports**: Comprehensive environment validation
- **Audit Logs**: Detailed logs for troubleshooting and compliance
- **Notifications**: Optional Slack/Teams notifications on completion

### Security Features
- **Credential Management**: Secure password handling
- **Backup Creation**: Automatic backup of existing configurations
- **Permission Validation**: Ensures proper file system permissions
- **Network Security**: Validates required network access

---

## 🚦 Setup Stages

The setup process consists of these stages:

### 1. Validation (5 minutes)
- System requirements check
- Network connectivity test
- Permission validation
- Existing software detection

### 2. Software Installation (15-30 minutes)
- Java (Amazon Corretto 17)
- Maven with corporate settings
- Node.js via NVM
- MySQL 8.0
- Python packages (yasha, mysql-connector)

### 3. Service Configuration (10-15 minutes)
- Docker containers (Elasticsearch, Redis)
- MySQL database setup
- Network configuration
- Environment variables

### 4. Database Setup (15-60 minutes)
- Database creation (legiondb, legiondb0)
- User and permission setup
- Data import (snapshot or full dump)
- Schema validation

### 5. Application Build (10-20 minutes)
- Repository clone and setup
- Maven dependency resolution
- Initial application build
- Configuration file generation

### 6. Verification (5 minutes)
- End-to-end connectivity tests
- Build verification
- Service health checks
- Configuration validation

---

## 🎯 Post-Setup Tasks

### Immediate Next Steps
1. **Open IntelliJ IDEA**
   ```bash
   # Import the enterprise project
   File → Open → ~/work/enterprise
   ```

2. **Configure Run Configuration**
   - Use the auto-generated backend configuration
   - Or follow README.md instructions for manual setup

3. **Start Development Services**
   ```bash
   # Start all services
   brew services start mysql
   docker start elasticsearch redis-master redis-slave
   ```

4. **Test Application**
   ```bash
   # Run the application
   cd ~/work/enterprise
   mvn clean install -P dev -DskipTests
   # Then run via IntelliJ or command line
   ```

### Accessing Services
- **Application**: http://localhost:8080/legion/?enterprise=LegionCoffee
- **Elasticsearch**: http://localhost:9200/_cat/health
- **MySQL**: `mysql -u legion -p legiondb`
- **Redis**: `docker exec -it redis-master redis-cli`

### Development Workflow
1. **Daily Startup**:
   ```bash
   # Start services (if not auto-starting)
   brew services start mysql
   docker start elasticsearch redis-master redis-slave
   ```

2. **Code Changes**:
   - IntelliJ will auto-compile
   - Use hot reload for rapid development
   - Run tests before commits

3. **Database Changes**:
   - Flyway migrations handle schema changes
   - Test data is preserved between restarts

---

## 📞 Support & Contributing

### Getting Help
- **Internal Slack**: `#devops-it-support`
- **Documentation**: Check README.md in enterprise repo
- **Tickets**: Use [CPL-487 template](https://legiontech.atlassian.net/browse/CPL-487)

### Reporting Issues
```bash
# Generate diagnostic report
python3 legion_dev_setup.py --generate-report

# Include this report when seeking help
```

### Contributing Improvements
- Submit pull requests with setup improvements
- Update this documentation for new features
- Report bugs and enhancement requests

---

## 📚 Additional Resources

### Legion Development Resources
- [Java Code Style Guide](https://legiontech.atlassian.net/wiki/spaces/DEV/pages/491814913/)
- [AWS CLI with Okta Setup](https://legiontech.atlassian.net/wiki/spaces/DevOps/pages/2525102095/)
- [Multiple JDK Management](https://legiontech.atlassian.net/wiki/spaces/DEV/pages/2796945454/)
- [Scheduling Optimization Guide](https://legiontech.atlassian.net/wiki/spaces/DEV/pages/2867069049/)

### External Tool Documentation
- [Maven Documentation](https://maven.apache.org/guides/)
- [Docker Desktop Guide](https://docs.docker.com/desktop/)
- [MySQL 8.0 Reference](https://dev.mysql.com/doc/refman/8.0/en/)
- [Elasticsearch Guide](https://www.elastic.co/guide/en/elasticsearch/reference/8.0/index.html)

---

**🎉 Happy Coding! Your Legion development environment is ready.**