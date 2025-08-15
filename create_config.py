#!/usr/bin/env python3
"""
Legion Setup - Interactive Configuration Creator
Collects user information and creates personalized setup_config.yaml
"""

import os
import sys
import platform
from pathlib import Path
from typing import Dict, Any, Optional, Tuple

# Check and install required dependencies
def check_dependencies():
    """Check and install required Python packages."""
    required_packages = ['PyYAML']
    missing_packages = []
    
    for package in required_packages:
        try:
            if package == 'PyYAML':
                import yaml
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"📦 Installing required packages: {', '.join(missing_packages)}")
        try:
            import subprocess
            for package in missing_packages:
                subprocess.run([sys.executable, '-m', 'pip', 'install', '--user', package], 
                             check=True, capture_output=True)
            print("✅ Dependencies installed successfully")
            
            # Re-import after installation
            global yaml
            import yaml
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to install dependencies: {e}")
            print("Please install manually: pip install PyYAML")
            sys.exit(1)

# Install dependencies before proceeding
check_dependencies()
import yaml

class InteractiveConfigCreator:
    def __init__(self):
        self.platform = platform.system().lower()
        self.config = {}
        
    def create_interactive_config(self) -> Dict[str, Any]:
        """Create configuration through interactive prompts."""
        print("""
╔══════════════════════════════════════════════════════════════╗
║            LEGION DEVELOPMENT SETUP CONFIGURATION           ║
╚══════════════════════════════════════════════════════════════╝

Let's set up your personalized Legion development environment!
Press Enter to use default values shown in [brackets].
""")
        
        # User information
        self._collect_user_info()
        
        # Installation paths
        self._collect_paths()
        
        # Setup options
        self._collect_setup_options()
        
        # Database configuration
        self._collect_database_config()
        
        # Git and GitHub configuration
        self._collect_git_config()
        
        # Advanced options
        self._collect_advanced_options()
        
        return self.config
    
    def _collect_user_info(self):
        """Collect user information."""
        print("\n📝 USER INFORMATION")
        print("=" * 50)
        
        # Name
        name = self._prompt_input(
            "Your full name",
            required=True,
            help_text="This will be used for Git configuration"
        )
        
        # Email
        email = self._prompt_input(
            "Your email address",
            required=True,
            help_text="This will be used for Git configuration and SSH key generation"
        )
        
        # GitHub username
        github_username = self._prompt_input(
            "Your GitHub username",
            required=True,
            help_text="Used for repository access permissions"
        )
        
        self.config['user'] = {
            'name': name,
            'email': email,
            'github_username': github_username
        }
    
    def _collect_paths(self):
        """Collect installation path preferences."""
        print("\n📁 INSTALLATION PATHS")
        print("=" * 50)
        print("Leave blank to use recommended defaults.")
        
        # Base workspace configuration
        workspace_root = self._prompt_input(
            "Development workspace root",
            default="~/Development/legion",
            help_text="Root directory for all Legion development files"
        )
        
        code_directory = self._prompt_input(
            "Code subdirectory name",
            default="code",
            help_text="Subdirectory name for source code repositories"
        )
        
        # Maven install path (optional)
        maven_path = self._prompt_input(
            "Custom Maven installation path",
            default="",
            help_text="Leave blank for system default (/usr/local/maven)"
        )
        
        # Store base paths configuration
        self.config['base_paths'] = {
            'workspace_root': workspace_root,
            'code_directory': code_directory
        }
        
        # Use variable references for paths
        self.config['paths'] = {
            'enterprise_repo_path': "${base_paths.workspace_root}/${base_paths.code_directory}/enterprise",
            'console_ui_repo_path': "${base_paths.workspace_root}/${base_paths.code_directory}/console-ui",
            'maven_install_path': maven_path,
            'jdk_install_path': "",
            'mysql_data_path': ""
        }
    
    def _collect_setup_options(self):
        """Collect setup preferences."""
        print("\n⚙️  SETUP OPTIONS")
        print("=" * 50)
        
        # Database import option
        use_snapshot = self._prompt_yes_no(
            "Use fast database snapshot import? (recommended)",
            default=True,
            help_text="'Yes' = 25 minutes, 'No' = several hours but complete data"
        )
        
        # IntelliJ setup
        setup_intellij = self._prompt_yes_no(
            "Set up IntelliJ IDEA configuration?",
            default=True,
            help_text="Configures IDE settings, plugins, and run configurations"
        )
        
        # SSH keys
        setup_ssh = self._prompt_yes_no(
            "Generate SSH keys for GitHub?",
            default=True,
            help_text="Creates SSH keys and guides you through GitHub setup"
        )
        
        # Repository cloning
        clone_repos = self._prompt_yes_no(
            "Clone Legion repositories (enterprise + console-ui)?",
            default=True,
            help_text="Automatically clones both repositories to separate folders"
        )
        
        # Homebrew installation (macOS only)
        install_homebrew = True
        if self.platform == 'darwin':
            install_homebrew = self._prompt_yes_no(
                "Install Homebrew package manager?",
                default=True,
                help_text="Required for installing software on macOS"
            )
        
        self.config['setup_options'] = {
            'skip_intellij_setup': not setup_intellij,
            'skip_database_import': False,
            'use_snapshot_import': use_snapshot,
            'skip_docker_setup': False,
            'install_homebrew': install_homebrew,
            'setup_vpn_check': False,
            'setup_ssh_keys': setup_ssh,
            'clone_repositories': clone_repos
        }
    
    def _collect_database_config(self):
        """Collect database configuration."""
        print("\n🗄️  DATABASE CONFIGURATION")
        print("=" * 50)
        
        # Elasticsearch index modifier
        elasticsearch_modifier = self._prompt_input(
            "Personal Elasticsearch index identifier",
            required=True,
            help_text="Lowercase, no spaces, max 20 chars (e.g., 'johndoe', 'jsmith')",
            validator=self._validate_elasticsearch_modifier
        )
        
        # MySQL passwords
        print("\nMySQL root password can be set during installation.")
        mysql_root_password = self._prompt_input(
            "MySQL root password (leave blank to set during setup)",
            default="",
            help_text="Leave blank to be prompted securely during setup",
            sensitive=True
        )
        
        legion_db_password = self._prompt_input(
            "Legion database password",
            default="legionwork",
            help_text="Password for legion database user"
        )
        
        self.config['database'] = {
            'mysql_root_password': mysql_root_password,
            'legion_db_password': legion_db_password,
            'elasticsearch_index_modifier': elasticsearch_modifier
        }
    
    def _collect_git_config(self):
        """Collect Git and GitHub configuration."""
        print("\n🔐 GIT & GITHUB CONFIGURATION") 
        print("=" * 50)
        
        # SSH key type
        ssh_key_type = self._prompt_choice(
            "SSH key type",
            choices=['ed25519', 'rsa'],
            default='ed25519',
            help_text="ed25519 is more secure and faster"
        )
        
        # Git editor
        git_editor = self._prompt_choice(
            "Default Git editor",
            choices=['nano', 'vim', 'code', 'emacs'],
            default='nano',
            help_text="Editor for Git commit messages"
        )
        
        # GitHub CLI
        setup_github_cli = self._prompt_yes_no(
            "Install GitHub CLI tool?",
            default=True,
            help_text="Useful for managing GitHub issues, PRs, etc."
        )
        
        self.config['git'] = {
            'generate_ssh_key': True,
            'setup_github_cli': setup_github_cli,
            'ssh_key_type': ssh_key_type,
            'git_editor': git_editor
        }
        
        # Repository configuration
        self.config['repositories'] = {
            'enterprise': {
                'url': 'git@github.com:legionco/enterprise.git',
                'path': self.config['paths']['enterprise_repo_path'],
                'clone_submodules': True
            },
            'console_ui': {
                'url': 'git@github.com:legionco/console-ui.git',
                'path': self.config['paths']['console_ui_repo_path'],
                'clone_submodules': False
            }
        }
    
    def _collect_advanced_options(self):
        """Collect advanced configuration options."""
        print("\n🔧 ADVANCED OPTIONS")
        print("=" * 50)
        
        # Verbose logging
        verbose_logging = self._prompt_yes_no(
            "Enable verbose logging?",
            default=False,
            help_text="Shows detailed debug information during setup"
        )
        
        # Parallel downloads
        parallel_downloads = self._prompt_yes_no(
            "Enable parallel downloads?",
            default=True,
            help_text="Speeds up installation by downloading multiple components simultaneously"
        )
        
        # Auto confirm
        auto_confirm = self._prompt_yes_no(
            "Skip confirmation prompts? (auto-confirm)",
            default=False,
            help_text="⚠️  Use with caution - skips safety confirmations"
        )
        
        # Corporate proxy (if needed)
        has_proxy = self._prompt_yes_no(
            "Are you behind a corporate proxy?",
            default=False,
            help_text="Configure proxy settings for network access"
        )
        
        proxy_host = ""
        proxy_port = ""
        if has_proxy:
            proxy_host = self._prompt_input(
                "Proxy hostname",
                required=True,
                help_text="e.g., proxy.company.com"
            )
            proxy_port = self._prompt_input(
                "Proxy port",
                required=True,
                help_text="e.g., 8080"
            )
        
        # Set up all the advanced configuration
        self.config['advanced'] = {
            'parallel_downloads': parallel_downloads,
            'verbose_logging': verbose_logging,
            'dry_run': False,
            'auto_confirm': auto_confirm,
            'backup_existing_config': True
        }
        
        self.config['network'] = {
            'proxy_host': proxy_host,
            'proxy_port': proxy_port,
            'no_proxy': "localhost,127.0.0.1"
        }
        
        # Add remaining default configurations
        self._add_default_configs()
    
    def _add_default_configs(self):
        """Add remaining default configurations."""
        # Version preferences
        self.config['versions'] = {
            'node': '13.8.0',
            'npm': '7.11.2',
            'maven': '3.9.9',
            'jdk': '17',
            'mysql': '8.0',
            'elasticsearch': '8.0.0'
        }
        
        # AWS configuration
        self.config['aws'] = {
            'setup_localstack': True,
            'setup_aws_cli': False  # Requires manual Okta setup
        }
        
        # Docker configuration
        self.config['docker'] = {
            'memory_gb': 4.0,
            'cpus': 4,
            'swap_gb': 1.0
        }
        
        # Development environment
        self.config['dev_environment'] = {
            'setup_redis': True,
            'setup_elasticsearch': True,
            'setup_frontend': True,
            'create_intellij_config': not self.config['setup_options']['skip_intellij_setup']
        }
        
        # JFrog configuration
        self.config['jfrog'] = {
            'download_settings_xml': True,
            'artifactory_url': ""
        }
        
        # Custom commands (empty by default)
        self.config['custom_commands'] = {
            'pre_setup': [],
            'post_setup': [],
            'pre_build': [],
            'post_build': []
        }
        
        # Notifications
        self.config['notifications'] = {
            'email_on_completion': False,
            'slack_webhook': "",
            'teams_webhook': ""
        }
    
    def _prompt_input(self, prompt: str, default: str = "", required: bool = False, 
                     help_text: str = "", sensitive: bool = False, validator=None) -> str:
        """Prompt user for input with validation."""
        while True:
            try:
                # Show help text
                if help_text:
                    print(f"  💡 {help_text}")
                
                # Create prompt string
                if default:
                    prompt_str = f"{prompt} [{default}]: "
                else:
                    prompt_str = f"{prompt}: "
                
                # Get input
                if sensitive:
                    import getpass
                    value = getpass.getpass(prompt_str)
                else:
                    # Ensure we're reading from stdin
                    sys.stdout.write(prompt_str)
                    sys.stdout.flush()
                    value = sys.stdin.readline().strip()
                
                # Use default if empty
                if not value and default:
                    value = default
                
                # Check required
                if required and not value:
                    print("  ❌ This field is required. Please enter a value.")
                    continue
                
                # Validate if validator provided
                if validator and value:
                    is_valid, error_msg = validator(value)
                    if not is_valid:
                        print(f"  ❌ {error_msg}")
                        continue
                
                return value
                
            except (EOFError, KeyboardInterrupt):
                print("\n⚠️  Input cancelled. Exiting configuration.")
                sys.exit(1)
    
    def _prompt_yes_no(self, prompt: str, default: bool = True, help_text: str = "") -> bool:
        """Prompt user for yes/no input."""
        try:
            if help_text:
                print(f"  💡 {help_text}")
            
            default_str = "Y/n" if default else "y/N"
            sys.stdout.write(f"{prompt} [{default_str}]: ")
            sys.stdout.flush()
            response = sys.stdin.readline().strip().lower()
            
            if not response:
                return default
            
            return response in ['y', 'yes', 'true', '1']
            
        except (EOFError, KeyboardInterrupt):
            print("\n⚠️  Input cancelled. Exiting configuration.")
            sys.exit(1)
    
    def _prompt_choice(self, prompt: str, choices: list, default: str = "", help_text: str = "") -> str:
        """Prompt user to choose from a list of options."""
        try:
            if help_text:
                print(f"  💡 {help_text}")
            
            print(f"  Options: {', '.join(choices)}")
            
            while True:
                if default:
                    sys.stdout.write(f"{prompt} [{default}]: ")
                else:
                    sys.stdout.write(f"{prompt}: ")
                sys.stdout.flush()
                response = sys.stdin.readline().strip().lower()
                
                if not response and default:
                    return default
                
                if response in choices:
                    return response
                
                print(f"  ❌ Please choose from: {', '.join(choices)}")
                
        except (EOFError, KeyboardInterrupt):
            print("\n⚠️  Input cancelled. Exiting configuration.")
            sys.exit(1)
    
    def _validate_elasticsearch_modifier(self, value: str) -> Tuple[bool, str]:
        """Validate Elasticsearch index modifier."""
        if len(value) > 20:
            return False, "Must be 20 characters or less"
        
        if not value.islower():
            return False, "Must be lowercase letters only"
        
        if '_' in value or ' ' in value:
            return False, "No underscores or spaces allowed"
        
        if not value.isalnum():
            return False, "Must contain only letters and numbers"
        
        return True, ""
    
    def save_config(self, config: Dict[str, Any], file_path: Path) -> bool:
        """Save configuration to YAML file."""
        try:
            # Create backup if file exists
            if file_path.exists():
                backup_path = file_path.with_suffix('.yaml.backup')
                file_path.rename(backup_path)
                print(f"  📁 Existing config backed up to {backup_path.name}")
            
            # Write new configuration
            with open(file_path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, indent=2, sort_keys=False)
            
            print(f"  ✅ Configuration saved to {file_path}")
            return True
            
        except Exception as e:
            print(f"  ❌ Error saving configuration: {str(e)}")
            return False
    
    def show_config_summary(self, config: Dict[str, Any]):
        """Show a summary of the created configuration."""
        print(f"""
╔══════════════════════════════════════════════════════════════╗
║                   CONFIGURATION SUMMARY                     ║
╚══════════════════════════════════════════════════════════════╝

👤 User: {config['user']['name']} <{config['user']['email']}>
🐙 GitHub: {config['user']['github_username']}

📁 Repositories:
  • Enterprise: {config['paths']['enterprise_repo_path']}
  • Console-UI: {config['paths']['console_ui_repo_path']}

🗄️  Database:
  • Import Type: {'Snapshot (Fast)' if config['setup_options']['use_snapshot_import'] else 'Full Dump (Complete)'}
  • ES Index: {config['database']['elasticsearch_index_modifier']}

🔐 Git/GitHub:
  • SSH Keys: {'✅' if config['setup_options']['setup_ssh_keys'] else '❌'}
  • GitHub CLI: {'✅' if config['git']['setup_github_cli'] else '❌'}
  • Clone Repos: {'✅' if config['setup_options']['clone_repositories'] else '❌'}

⚙️  Setup Options:
  • IntelliJ: {'✅' if not config['setup_options']['skip_intellij_setup'] else '❌'}
  • Homebrew: {'✅' if config['setup_options']['install_homebrew'] else '❌'}
  • Verbose Logs: {'✅' if config['advanced']['verbose_logging'] else '❌'}

🎯 Ready to run: ./setup.sh
        """)

def main():
    """Main entry point for interactive configuration creation."""
    creator = InteractiveConfigCreator()
    
    try:
        # Create configuration
        config = creator.create_interactive_config()
        
        # Save configuration
        config_file = Path('setup_config.yaml')
        if creator.save_config(config, config_file):
            # Show summary
            creator.show_config_summary(config)
            
            print("\n🎉 Configuration complete! You can now run:")
            print("   ./setup.sh")
            print("\nTo modify settings later, edit setup_config.yaml or run this again.")
            return True
        else:
            return False
            
    except KeyboardInterrupt:
        print("\n\n⚠️  Configuration cancelled by user.")
        return False
    except Exception as e:
        print(f"\n❌ Configuration error: {str(e)}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)