# Legion Enterprise Development Environment Setup

**🚀 Enterprise-grade one-click development environment setup for 100+ users**

This automated setup system configures a complete Legion development environment including Java, Maven, Node.js, MySQL, Docker services, and all necessary configuration files.

## 📁 Project Structure

```
legion-dev-setup/
├── setup.sh                    # Main entry point (shell script)
├── legion_dev_setup.py         # Core Python setup orchestrator
├── setup_config.yaml           # User configuration file
├── requirements.txt             # Python dependencies
├── SETUP_GUIDE.md              # Comprehensive user guide
├── README_SETUP.md             # This file (technical documentation)
└── setup_modules/              # Modular setup components
    ├── installer.py             # Software installation logic
    ├── database_setup.py        # Database configuration & import
    └── validator.py             # Environment validation & verification
```

## 🎯 Quick Start

### For End Users
```bash
# 1. Clone or download setup files
git clone <repo-url> legion-setup && cd legion-setup

# 2. Run the setup
./setup.sh

# 3. Follow the interactive prompts
```

### For Advanced Users
```bash
# Custom configuration
./setup.sh --config my_config.yaml

# Preview mode (no changes)
./setup.sh --dry-run

# Validation only
./setup.sh --validate-only

# Verbose logging
./setup.sh --verbose
```

## 🛠️ Technical Architecture

### Core Components

#### 1. Setup Orchestrator (`legion_dev_setup.py`)
- **Main coordination logic**
- Comprehensive prerequisite checking
- Stage-based setup progression
- Error handling and recovery
- Progress tracking and logging
- User interaction and confirmations

Key Classes:
- `LegionDevSetup`: Main orchestrator class
- `SetupResult`: Standardized result handling
- `SetupStage`: Stage enumeration for progress tracking

#### 2. Software Installer (`setup_modules/installer.py`)
- **Multi-platform software installation**
- Version management and verification
- Download and installation automation
- Path configuration and environment setup

Key Features:
- Homebrew integration (macOS)
- Package manager support (Linux)
- Manual installation fallbacks
- Docker container management
- Environment variable setup

#### 3. Database Setup (`setup_modules/database_setup.py`)
- **MySQL service configuration**
- Database and user creation
- Data import (snapshot or full dump)
- Schema validation and verification

Key Features:
- MySQL service startup and security
- Legion database creation (legiondb, legiondb0)
- Multiple import options (fast snapshot vs. complete dump)
- Collation fix automation
- Connection testing and validation

#### 4. Environment Validator (`setup_modules/validator.py`)
- **Comprehensive environment validation**
- Software version verification
- Network connectivity testing
- Service health monitoring

Validation Categories:
- Software versions and compatibility
- Database connectivity and data integrity
- Docker services and container health
- Network connectivity (internal and external)
- File system permissions and access
- Environment variables and PATH configuration

### Setup Stages

The setup process follows a structured multi-stage approach:

1. **Validation** (5 min): System requirements and prerequisite checks
2. **Software Installation** (15-30 min): Core software packages
3. **Service Configuration** (10-15 min): Docker containers and services
4. **Database Setup** (15-60 min): MySQL setup and data import
5. **Application Build** (10-20 min): Repository clone and initial build
6. **Verification** (5 min): End-to-end testing and validation

### Configuration System

The setup uses a hierarchical YAML configuration system:

```yaml
# User personalizations
user:
  name: "Developer Name"
  email: "dev@company.com"
  github_username: "devuser"

# Installation options
setup_options:
  use_snapshot_import: true      # Fast DB import vs. full dump
  skip_intellij_setup: false    # IDE configuration
  install_homebrew: true        # Package manager setup

# Software versions
versions:
  node: "13.8.0"
  npm: "7.11.2"
  maven: "3.9.9"
  jdk: "17"

# Advanced configuration
advanced:
  parallel_downloads: true       # Performance optimization
  verbose_logging: false        # Debug output
  auto_confirm: false           # Skip user prompts
```

## 🏢 Enterprise Features

### Multi-User Support
- **Concurrent execution**: Multiple users can run setup simultaneously
- **Isolation**: Personal elasticsearch indices and configuration
- **Collision detection**: Automatic handling of port and resource conflicts

### Corporate Network Integration
- **Proxy support**: Automatic detection and configuration
- **SSL handling**: Corporate certificate management
- **Network validation**: Connectivity testing for corporate environments

### Monitoring and Reporting
- **Progress tracking**: Real-time progress with time estimates
- **Comprehensive logging**: Detailed logs for troubleshooting
- **Validation reports**: Environment health assessment
- **Notifications**: Optional Slack/Teams integration

### Security and Compliance
- **Secure credential handling**: No plaintext password storage
- **Permission validation**: Proper file system access verification
- **Audit logging**: Complete setup activity tracking
- **Backup creation**: Automatic backup of existing configurations

## 🔧 Development and Customization

### Adding New Software Components

1. **Extend the installer module**:
```python
# In setup_modules/installer.py
def install_new_tool(self) -> Tuple[bool, str]:
    """Install new development tool."""
    # Implementation here
    return True, "Tool installed successfully"
```

2. **Add to validation**:
```python
# In setup_modules/validator.py
def _validate_new_tool(self) -> Tuple[bool, Dict[str, Any]]:
    """Validate new tool installation."""
    # Validation logic here
    return True, {"status": "validated"}
```

3. **Update configuration schema**:
```yaml
# In setup_config.yaml
versions:
  new_tool: "1.0.0"
```

### Custom Installation Paths

The setup supports custom installation paths for enterprise environments:

```yaml
paths:
  maven_install_path: "/opt/tools/maven"
  jdk_install_path: "/opt/java/jdk-17"
  enterprise_repo_path: "/workspace/legion"
```

### Environment-Specific Configurations

Different configuration templates can be maintained:

```bash
# Development environment
./setup.sh --config configs/dev_config.yaml

# Staging environment  
./setup.sh --config configs/staging_config.yaml

# Production-like local environment
./setup.sh --config configs/prod_local_config.yaml
```

## 🧪 Testing and Quality Assurance

### Validation Framework

The setup includes comprehensive validation:

```python
# Run full environment validation
validator = EnvironmentValidator(config, logger)
results = validator.run_comprehensive_validation()

# Generate detailed report
report = validator.generate_validation_report(results)
```

### Dry Run Mode

Test setup without making changes:

```bash
# Preview all actions
./setup.sh --dry-run

# See what would be installed
python3 legion_dev_setup.py --dry-run --verbose
```

### Recovery and Debugging

Built-in recovery mechanisms:

```bash
# Resume from specific stage
./setup.sh --resume-from=database_setup

# Force continue despite errors
./setup.sh --force-continue

# Generate diagnostic report
./setup.sh --generate-report
```

## 📊 Logging and Monitoring

### Log Structure

Logs are organized hierarchically:

```
~/.legion_setup/
├── logs/
│   ├── setup_TIMESTAMP.log      # Main setup log
│   ├── validation_TIMESTAMP.log # Validation results
│   └── installer_TIMESTAMP.log  # Software installation details
├── backups/                     # Configuration backups
└── reports/                     # Validation and diagnostic reports
```

### Log Levels

- **DEBUG**: Detailed diagnostic information
- **INFO**: General progress information  
- **WARNING**: Non-critical issues
- **ERROR**: Errors that may affect functionality
- **CRITICAL**: Fatal errors that stop execution

### Performance Monitoring

The setup tracks performance metrics:

```python
# Stage timing and resource usage
stage_metrics = {
    'duration': time.time() - start_time,
    'memory_peak': psutil.Process().memory_info().rss,
    'disk_usage': shutil.disk_usage('.').free
}
```

## 🚀 Deployment and Distribution

### Package Distribution

The setup can be packaged for easy distribution:

```bash
# Create distribution package
tar -czf legion-dev-setup-v1.0.0.tar.gz legion-dev-setup/

# Or create installer
python3 create_installer.py --output legion-installer.run
```

### CI/CD Integration

Example GitHub Actions integration:

```yaml
name: Setup Validation
on: [push, pull_request]

jobs:
  validate-setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run setup validation
        run: |
          ./setup.sh --validate-only
          ./setup.sh --dry-run
```

### Docker Support

For containerized testing:

```dockerfile
FROM ubuntu:20.04
COPY legion-dev-setup/ /setup/
RUN /setup/setup.sh --auto-confirm
EXPOSE 8080 3306 9200 6379
```

## 📝 Maintenance and Updates

### Version Management

The setup system supports version tracking:

```python
# Version checking
CURRENT_VERSION = "1.0.0"
MINIMUM_SUPPORTED_VERSION = "0.9.0"

def check_version_compatibility():
    # Version validation logic
    pass
```

### Update Mechanism

Built-in update capability:

```bash
# Check for updates
./setup.sh --check-updates

# Update to latest version
./setup.sh --update

# Update specific component
./setup.sh --update-component=database_setup
```

### Configuration Migration

Support for configuration format changes:

```python
def migrate_config(old_config: dict) -> dict:
    """Migrate configuration to latest format."""
    # Migration logic for breaking changes
    return new_config
```

## 🤝 Contributing

### Development Setup

For contributors working on the setup system:

```bash
# Clone development version
git clone <dev-repo-url> legion-setup-dev
cd legion-setup-dev

# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/

# Lint code
flake8 setup_modules/
black setup_modules/
```

### Code Standards

- **Python**: Follow PEP 8, use type hints
- **Documentation**: Comprehensive docstrings and comments
- **Testing**: Unit tests for all components
- **Error handling**: Graceful failure and recovery

### Submission Process

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Update documentation
5. Submit pull request with detailed description

---

**For user documentation and troubleshooting, see [SETUP_GUIDE.md](SETUP_GUIDE.md)**