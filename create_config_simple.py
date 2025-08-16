#!/usr/bin/env python3
"""
Legion Setup - Simplified Configuration Creator
Only asks for essential information: name, email, github username, ssh passphrase
"""

import os
import sys
from pathlib import Path

# Simple check for PyYAML
try:
    import yaml
except ImportError:
    print("Installing PyYAML...")
    import subprocess
    subprocess.run([sys.executable, '-m', 'pip', 'install', '--user', 'PyYAML'], check=True)
    import yaml

def create_simple_config():
    """Create configuration with minimal prompts."""
    print("""
╔══════════════════════════════════════════════════════════════╗
║            LEGION DEVELOPMENT SETUP - QUICK CONFIG          ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    # First ask if they want to use recommended defaults
    print("📋 SETUP OPTIONS")
    print("-" * 50)
    print("We recommend using the default configuration which will:")
    print("  • Install everything in ~/Development/legion/code/")
    print("  • Set MySQL password to 'mysql123'")
    print("  • Enable verbose logging and auto-confirm")
    print("  • Use fast database snapshot import")
    print("  • Set up SSH keys and clone repositories")
    print()
    print("Use recommended defaults? [Y/n]: ", end='')
    use_defaults = input().strip().lower()
    use_defaults = use_defaults != 'n'  # Default to Yes
    
    print("\n📝 USER INFORMATION (Required)")
    print("-" * 50)
    
    # Get the 3 essential inputs
    print("1️⃣  Your full name (e.g., John Doe):")
    name = input("   > ").strip()
    while not name:
        print("   ❌ Name is required")
        name = input("   > ").strip()
    
    print("\n2️⃣  Your email address:")
    email = input("   > ").strip()
    while not email or '@' not in email:
        print("   ❌ Valid email is required")
        email = input("   > ").strip()
    
    print("\n3️⃣  Your GitHub username:")
    github_username = input("   > ").strip()
    while not github_username:
        print("   ❌ GitHub username is required")
        github_username = input("   > ").strip()
    
    print("\n4️⃣  SSH key passphrase (for git operations):")
    print("   💡 Tip: Use something memorable like 'Legion WFM is awesome'")
    ssh_passphrase = input("   > ").strip()
    while not ssh_passphrase:
        print("   ❌ SSH passphrase cannot be empty (for security)")
        print("   💡 Suggestion: Legion WFM is awesome")
        ssh_passphrase = input("   > ").strip()
    
    print("\n5️⃣  Database dumps folder (download from Google Drive):")
    print("   📥 Download these files from: https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK")
    print("   - storedprocedures.sql")
    print("   - legiondb.sql.zip")
    print("   - legiondb0.sql.zip")
    print("   💡 Default: ~/work/dbdumps")
    dbdumps_folder = input("   Database dumps folder [~/work/dbdumps]: ").strip()
    if not dbdumps_folder:
        dbdumps_folder = "~/work/dbdumps"
    
    # If not using defaults, ask additional questions
    workspace_root = '~/Development/legion'
    code_directory = 'code'
    mysql_password = 'mysql123'
    
    if not use_defaults:
        print("\n📁 CUSTOM PATHS (Press Enter for defaults)")
        print("-" * 50)
        
        custom_workspace = input(f"Workspace root [{workspace_root}]: ").strip()
        if custom_workspace:
            workspace_root = custom_workspace
        
        custom_code_dir = input(f"Code subdirectory [{code_directory}]: ").strip()
        if custom_code_dir:
            code_directory = custom_code_dir
        
        print("\n🔐 DATABASE (Press Enter for defaults)")
        print("-" * 50)
        custom_mysql = input(f"MySQL root password [{mysql_password}]: ").strip()
        if custom_mysql:
            mysql_password = custom_mysql
    
    # Auto-generate elasticsearch modifier from name
    # Take first initial + last name, all lowercase
    name_parts = name.lower().split()
    if len(name_parts) >= 2:
        # First initial + last name (e.g., "John Doe" -> "jdoe")
        es_modifier = name_parts[0][0] + name_parts[-1]
    else:
        # Just use the single name
        es_modifier = name_parts[0] if name_parts else github_username.lower()
    
    # Remove any non-alphanumeric characters and truncate to 20 chars
    es_modifier = ''.join(c for c in es_modifier if c.isalnum())[:20]
    
    # Create the full configuration with user choices
    config = {
        'user': {
            'name': name,
            'email': email,
            'github_username': github_username
        },
        'base_paths': {
            'workspace_root': workspace_root,
            'code_directory': code_directory
        },
        'paths': {
            'enterprise_repo_path': '${base_paths.workspace_root}/${base_paths.code_directory}/enterprise',
            'console_ui_repo_path': '${base_paths.workspace_root}/${base_paths.code_directory}/console-ui',
            'maven_install_path': '',
            'jdk_install_path': '',
            'mysql_data_path': ''
        },
        'setup_options': {
            'skip_intellij_setup': False,
            'skip_database_import': False,
            'use_snapshot_import': True,
            'skip_docker_setup': False,
            'install_homebrew': True,
            'setup_vpn_check': False,
            'setup_ssh_keys': True,
            'clone_repositories': True
        },
        'database': {
            'mysql_root_password': mysql_password,
            'legion_db_password': 'legionwork',
            'elasticsearch_index_modifier': es_modifier,
            'dbdumps_folder': dbdumps_folder
        },
        'git': {
            'generate_ssh_key': True,
            'setup_github_cli': True,
            'ssh_key_type': 'ed25519',
            'ssh_passphrase': ssh_passphrase,
            'git_editor': 'nano',
            'force_fresh_clone': False  # Set to True to always re-clone repositories
        },
        'repositories': {
            'enterprise': {
                'url': 'git@github.com:legionco/enterprise.git',
                'path': '${base_paths.workspace_root}/${base_paths.code_directory}/enterprise',
                'clone_submodules': True
            },
            'console_ui': {
                'url': 'git@github.com:legionco/console-ui.git',
                'path': '${base_paths.workspace_root}/${base_paths.code_directory}/console-ui',
                'clone_submodules': False
            }
        },
        'jfrog': {
            'download_settings_xml': True,
            'artifactory_url': ''
        },
        'database_snapshots': {
            'gdrive_folder_url': 'https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK',
            'file_ids': {
                'storedprocedures': '',  # Auto-detected from folder
                'legiondb': '',
                'legiondb0': ''
            }
        },
        'notifications': {
            'email_on_completion': False,
            'slack_webhook': '',
            'teams_webhook': ''
        },
        'custom_commands': {
            'pre_setup': [],
            'post_setup': [],
            'pre_build': [],
            'post_build': []
        },
        'advanced': {
            'parallel_downloads': True,
            'verbose_logging': True,      # Default to verbose
            'dry_run': False,
            'auto_confirm': True,          # Default to auto-confirm
            'backup_existing_config': True
        },
        'network': {
            'proxy_host': '',
            'proxy_port': '',
            'no_proxy': 'localhost,127.0.0.1'
        },
        'versions': {
            'node': '18',
            'yarn': 'latest',
            'lerna': '6',
            'maven': '3.9.9',
            'jdk': '17',
            'mysql': '8.0',
            'elasticsearch': '8.0.0'
        },
        'aws': {
            'setup_localstack': True,
            'setup_aws_cli': False
        },
        'docker': {
            'memory_gb': 4.0,
            'cpus': 4,
            'swap_gb': 1.0
        },
        'dev_environment': {
            'setup_redis': True,
            'setup_elasticsearch': True,
            'setup_frontend': True,
            'create_intellij_config': True
        }
    }
    
    # Save configuration
    config_file = Path('setup_config.yaml')
    
    # Backup existing if present
    if config_file.exists():
        backup_path = config_file.with_suffix('.yaml.backup')
        config_file.rename(backup_path)
        print(f"\n📁 Existing config backed up to {backup_path.name}")
    
    # Write new configuration
    with open(config_file, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, indent=2, sort_keys=False)
    
    # Show configuration summary
    config_type = "DEFAULT" if use_defaults else "CUSTOM"
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║                   ✅ CONFIGURATION COMPLETE                 ║
╚══════════════════════════════════════════════════════════════╝

Configuration Type: {config_type}

👤 User: {name} <{email}>
🐙 GitHub: @{github_username}
🔍 Elasticsearch ID: {es_modifier}
🔐 SSH Passphrase: {"*" * len(ssh_passphrase)}

📁 Code Location: {workspace_root}/{code_directory}/
🗄️  MySQL Password: {mysql_password}
⚡ Auto-confirm: Yes
📝 Verbose Logging: Yes

🎉 Ready to install! Run:
   ./setup.sh

Setup will take approximately 45-90 minutes.
""")
    
    return True

if __name__ == "__main__":
    try:
        success = create_simple_config()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Configuration cancelled.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        sys.exit(1)