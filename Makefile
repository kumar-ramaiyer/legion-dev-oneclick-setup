# Legion Development Environment Setup - Makefile
# Convenience commands for setup management

.PHONY: help install validate clean test docs venv venv-clean venv-status venv-deps cleanup-env test-e2e validate-files

# Default target
help:
	@echo "Legion Development Environment Setup"
	@echo "======================================"
	@echo ""
	@echo "Available commands:"
	@echo "  install         Run the full setup process"
	@echo "  validate        Validate existing environment"
	@echo "  validate-files  Validate setup files and structure"
	@echo "  dry-run         Preview what would be installed"
	@echo "  clean           Clean up setup artifacts"
	@echo "  cleanup-env     Complete environment cleanup for validation"
	@echo "  test-e2e        Run end-to-end validation test"
	@echo "  test            Run setup tests"
	@echo "  docs            Generate documentation"
	@echo ""
	@echo "Virtual Environment:"
	@echo "  venv            Create Python virtual environment"
	@echo "  venv-clean      Remove virtual environment"
	@echo "  venv-status     Show virtual environment status"
	@echo "  venv-deps       Ensure all dependencies are installed"
	@echo "  venv-info       Show Python environment information"
	@echo ""
	@echo "Configuration:"
	@echo "  config          Create interactive configuration (guided setup)"
	@echo "  config-reset    Reset and recreate configuration"
	@echo "  edit-config     Edit configuration file manually"
	@echo "  gdrive-ids      Extract Google Drive IDs for database snapshots"
	@echo ""
	@echo "Examples:"
	@echo "  make install            # Standard setup"
	@echo "  make validate-files     # Check file structure"
	@echo "  make cleanup-env        # Clean for fresh validation"
	@echo "  make test-e2e           # Complete end-to-end test"

# Installation targets
install: venv config
	@echo "🚀 Starting Legion development environment setup..."
	./setup.sh

validate: venv
	@echo "🔍 Validating development environment..."
	./setup.sh --validate-only

validate-files:
	@echo "🔍 Validating setup files and structure..."
	@./scripts/validate_setup.sh

dry-run: venv config
	@echo "👀 Preview mode - showing what would be done..."
	./setup.sh --dry-run

# Configuration management
config: venv
	@if [ ! -f setup_config.yaml ]; then \
		echo "🎯 Creating simple configuration (just 3 questions!)..."; \
		./scripts/create_config_venv.sh; \
	else \
		echo "✅ Configuration file already exists: setup_config.yaml"; \
		echo "💡 To recreate configuration, run: make config-reset"; \
	fi

# Extract Google Drive IDs for database snapshots
gdrive-ids: venv
	@echo "🔍 Extracting Google Drive file IDs for database snapshots..."
	@venv/bin/python scripts/extract_gdrive_ids.py

config-reset: venv
	@echo "🔄 Resetting configuration..."
	@rm -f setup_config.yaml setup_config.yaml.backup
	@./scripts/create_config_venv.sh

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
		./scripts/setup_venv.sh create; \
	else \
		echo "✅ Virtual environment already exists"; \
	fi

# Dependencies (legacy - use venv instead)
deps: venv
	@echo "📦 Installing Python dependencies in virtual environment..."
	@venv/bin/pip install -q PyYAML mysql-connector-python requests gdown python-dotenv psutil

# Virtual Environment Management
venv-clean:
	@echo "🧹 Cleaning up virtual environment..."
	@./scripts/setup_venv.sh clean

venv-status:
	@./scripts/setup_venv.sh status

venv-deps:
	@echo "📦 Ensuring virtual environment dependencies..."
	@./scripts/ensure_venv_deps.sh

venv-info:
	@./scripts/show_python_env.sh

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

# Complete environment cleanup for validation
cleanup-env:
	@echo "🔄 Running complete environment cleanup for validation..."
	@./scripts/cleanup.sh

# End-to-end validation test
test-e2e:
	@echo "🧪 Running end-to-end validation test..."
	@./scripts/test_e2e.sh

# Testing
test: venv
	@echo "🧪 Running setup tests..."
	@venv/bin/python -m pytest tests/ -v || echo "⚠️  Install pytest to run tests: venv/bin/pip install pytest"

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
	@if [ -f venv/bin/python ]; then \
		venv/bin/python -c "import yaml, mysql.connector; print('  ✅ Core dependencies installed')" 2>/dev/null || echo "  ❌ Dependencies missing (run 'make venv')"; \
	else \
		echo "  ❌ Virtual environment missing (run 'make venv')"; \
	fi

info:
	@echo "Legion Development Environment Setup v1.0.0"
	@echo "Platform: $$(uname -s) $$(uname -m)"
	@echo "System Python: $$(python3 --version 2>&1)"
	@if [ -f venv/bin/python ]; then \
		echo "Venv Python: $$(venv/bin/python --version 2>&1)"; \
	else \
		echo "Venv Python: Not installed"; \
	fi
	@echo "Setup Directory: $$(pwd)"
	@echo "User: $$(whoami)"