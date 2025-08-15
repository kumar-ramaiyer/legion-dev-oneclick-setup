# Legion Enterprise Development Environment Setup

🚀 **One-click automated setup for Legion's development environment**

Enterprise-grade setup automation designed for 100+ developers across macOS and Linux platforms.

## Quick Start

```bash
# 1. Clone or download this setup package
cd legion-dev-setup

# 2. Run the setup (interactive)
./setup.sh

# 3. Follow the prompts and enjoy your configured environment!
```

## What Gets Installed

- ✅ **Java 17** (Amazon Corretto)
- ✅ **Maven 3.9.9+** with JFrog Artifactory settings
- ✅ **Node.js (latest)** with Yarn & Lerna
- ✅ **MySQL 8.0** with Legion databases (auto-downloaded from Google Drive)
- ✅ **Docker Desktop** with automatic container setup:
  - Elasticsearch 8.0.0 (single-node, no security)
  - Redis master/slave for distributed locking
  - LocalStack for AWS service emulation
- ✅ **Git & GitHub** SSH key setup with SAML SSO
- ✅ **IntelliJ IDEA** run configurations (optional)

## Documentation

- 📖 **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Comprehensive user guide and troubleshooting
- 🔧 **[README_SETUP.md](README_SETUP.md)** - Technical documentation for developers

## Configuration

Edit `setup_config.yaml` to customize your installation:

```yaml
user:
  name: "Your Name"
  email: "your.email@company.com"
  github_username: "yourusername"

setup_options:
  use_snapshot_import: true    # Fast database setup
  skip_intellij_setup: false  # Include IDE config
```

## Advanced Usage

```bash
# Preview what will be installed
./setup.sh --dry-run

# Custom configuration
./setup.sh --config my_config.yaml

# Validate existing environment
./setup.sh --validate-only

# Verbose output for debugging
./setup.sh --verbose
```

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

## Project Structure

```
legion-dev-setup/
├── setup.sh                    # Main entry point
├── legion_dev_setup.py         # Core setup orchestrator
├── setup_config.yaml           # User configuration
├── requirements.txt             # Python dependencies
├── SETUP_GUIDE.md              # User documentation
├── README_SETUP.md             # Technical documentation
└── setup_modules/              # Modular components
    ├── installer.py             # Software installation
    ├── database_setup.py        # Database configuration
    └── validator.py             # Environment validation
```

---

**🎉 Ready to start? Run `./setup.sh` and get coding in minutes!**
