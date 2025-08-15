# Legion Development Environment Setup - Makefile
# Convenience commands for setup management

.PHONY: help install validate clean test docs

# Default target
help:
	@echo "Legion Development Environment Setup"
	@echo "======================================"
	@echo ""
	@echo "Available commands:"
	@echo "  install      Run the full setup process"
	@echo "  validate     Validate existing environment"
	@echo "  dry-run      Preview what would be installed"
	@echo "  clean        Clean up setup artifacts"
	@echo "  test         Run setup tests"
	@echo "  docs         Generate documentation"
	@echo ""
	@echo "Virtual Environment:"
	@echo "  venv         Create Python virtual environment"
	@echo "  venv-clean   Remove virtual environment"
	@echo "  venv-status  Show virtual environment status"
	@echo ""
	@echo "Configuration:"
	@echo "  config       Create interactive configuration (guided setup)"
	@echo "  config-reset Reset and recreate configuration"
	@echo "  edit-config  Edit configuration file manually"
	@echo "  gdrive-ids   Extract Google Drive IDs for database snapshots"
	@echo ""
	@echo "Examples:"
	@echo "  make install          # Standard setup"
	@echo "  make validate         # Check environment"
	@echo "  make dry-run          # Preview actions"

# Installation targets
install: venv config
	@echo "🚀 Starting Legion development environment setup..."
	./setup.sh

validate: venv
	@echo "🔍 Validating development environment..."
	./setup.sh --validate-only

dry-run: venv config
	@echo "👀 Preview mode - showing what would be done..."
	./setup.sh --dry-run

# Configuration management
config: venv
	@if [ ! -f setup_config.yaml ]; then \
		echo "🎯 Creating simple configuration (just 3 questions!)..."; \
		./create_config_venv.sh; \
	else \
		echo "✅ Configuration file already exists: setup_config.yaml"; \
		echo "💡 To recreate configuration, run: make config-reset"; \
	fi

# Extract Google Drive IDs for database snapshots
gdrive-ids: venv
	@echo "🔍 Extracting Google Drive file IDs for database snapshots..."
	@if [ -f venv/bin/python ]; then \
		venv/bin/python extract_gdrive_ids.py; \
	else \
		python3 extract_gdrive_ids.py; \
	fi

config-reset: venv
	@echo "🔄 Resetting configuration..."
	@rm -f setup_config.yaml setup_config.yaml.backup
	@./create_config_venv.sh

edit-config: 
	@if [ ! -f setup_config.yaml ]; then \
		echo "❌ Configuration file not found. Run 'make config' first."; \
		exit 1; \
	fi
	@if command -v code > /dev/null 2>&1; then \
		code setup_config.yaml; \
	elif command -v nano > /dev/null 2>&1; then \
		nano setup_config.yaml; \
	elif command -v vi > /dev/null 2>&1; then \
		vi setup_config.yaml; \
	else \
		echo "Please edit setup_config.yaml with your preferred editor"; \
	fi

# Virtual Environment Setup
venv:
	@if [ ! -d venv ]; then \
		echo "🐍 Setting up Python virtual environment..."; \
		./setup_venv.sh create; \
	else \
		echo "✅ Virtual environment already exists"; \
	fi

# Dependencies (legacy - use venv instead)
deps:
	@echo "📦 Installing Python dependencies..."
	@python3 -m pip install --user -q PyYAML mysql-connector-python requests || \
		(echo "⚠️  Fallback: Installing without --user flag..."; \
		 python3 -m pip install -q PyYAML mysql-connector-python requests)

# Virtual Environment Management
venv-clean:
	@echo "🧹 Cleaning up virtual environment..."
	@./setup_venv.sh clean

venv-status:
	@./setup_venv.sh status

# Maintenance
clean:
	@echo "🧹 Cleaning up setup artifacts..."
	@rm -rf ~/.legion_setup/logs/*.log
	@rm -rf ~/.legion_setup/temp_*
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Cleanup completed"

clean-all: clean venv-clean
	@echo "🧹 Full cleanup - removing all setup data..."
	@rm -rf ~/.legion_setup
	@echo "✅ Full cleanup completed"

# Testing
test: deps
	@echo "🧪 Running setup tests..."
	@python3 -m pytest tests/ -v || echo "⚠️  Install pytest to run tests: pip install pytest"

# Documentation
docs:
	@echo "📚 Setup documentation is ready:"
	@echo "  - README.md: Project overview"
	@echo "  - SETUP_GUIDE.md: User guide and troubleshooting"
	@echo "  - README_SETUP.md: Technical documentation"

# Utilities
status:
	@echo "📊 Legion Development Environment Status"
	@echo "========================================"
	@echo ""
	@echo "Setup Files:"
	@ls -la setup.sh legion_dev_setup.py setup_config.yaml* 2>/dev/null || echo "  Some files missing"
	@echo ""
	@echo "Configuration:"
	@if [ -f setup_config.yaml ]; then \
		echo "  ✅ setup_config.yaml exists"; \
	else \
		echo "  ❌ setup_config.yaml missing (run 'make config')"; \
	fi
	@echo ""
	@echo "Python Dependencies:"
	@python3 -c "import yaml, mysql.connector; print('  ✅ Core dependencies installed')" 2>/dev/null || echo "  ❌ Dependencies missing (run 'make deps')"

info:
	@echo "Legion Development Environment Setup v1.0.0"
	@echo "Platform: $$(uname -s) $$(uname -m)"
	@echo "Python: $$(python3 --version 2>&1)"
	@echo "Setup Directory: $$(pwd)"
	@echo "User: $$(whoami)"