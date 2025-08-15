#!/usr/bin/env python3
"""
Legion Setup - Git and GitHub Integration Module
Handles SSH key setup, GitHub authentication, and repository cloning
"""

import os
import sys
import subprocess
import platform
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import json
import time
import getpass

class GitHubSetup:
    def __init__(self, config: Dict, logger):
        self.config = config
        self.logger = logger
        self.platform = platform.system().lower()
        self.ssh_dir = Path.home() / '.ssh'
        self.git_config = config.get('git', {})
        
        # Get repository configurations from config with path resolution
        self.repositories = {}
        
        # Import ConfigResolver to resolve variable paths
        try:
            from .config_resolver import ConfigResolver
            resolver = ConfigResolver(config)
            
            # Get resolved paths from config
            for repo_name, repo_config in config.get('repositories', {}).items():
                resolved_path = resolver.resolve_path(repo_config.get('path', ''))
                self.repositories[repo_name] = {
                    'url': repo_config.get('url', ''),
                    'path': Path(resolved_path),
                    'has_submodules': repo_config.get('clone_submodules', False),
                    'submodules': ['console-ui'] if repo_name == 'enterprise' else []
                }
        except:
            # Fallback to default if config resolution fails
            self.repositories = {
                'enterprise': {
                    'url': 'git@github.com:legionco/enterprise.git',
                    'path': Path.home() / 'Development' / 'legion' / 'code' / 'enterprise',
                    'has_submodules': True,
                    'submodules': ['console-ui']
                },
                'console-ui': {
                    'url': 'git@github.com:legionco/console-ui.git', 
                    'path': Path.home() / 'Development' / 'legion' / 'code' / 'console-ui',
                    'has_submodules': False,
                    'submodules': []
                }
            }

    def setup_git_configuration(self) -> Tuple[bool, str]:
        """Setup global Git configuration."""
        self.logger.info("Setting up Git configuration...")
        
        try:
            user_name = self.config.get('user', {}).get('name', '')
            user_email = self.config.get('user', {}).get('email', '')
            
            if not user_name or not user_email:
                return False, "User name and email are required for Git configuration"
            
            # Configure Git user
            subprocess.run(['git', 'config', '--global', 'user.name', user_name], check=True)
            subprocess.run(['git', 'config', '--global', 'user.email', user_email], check=True)
            
            # Set recommended Git configurations
            git_configs = [
                ('init.defaultBranch', 'main'),
                ('pull.rebase', 'false'),
                ('core.autocrlf', 'input' if self.platform != 'windows' else 'true'),
                ('core.editor', 'nano'),  # Default editor
                ('push.default', 'simple'),
                ('credential.helper', 'store'),  # Store credentials
            ]
            
            for key, value in git_configs:
                subprocess.run(['git', 'config', '--global', key, value], 
                             capture_output=True, text=True)
            
            self.logger.info(f"✅ Git configured for {user_name} <{user_email}>")
            return True, f"Git configured for {user_name} <{user_email}>"
            
        except subprocess.CalledProcessError as e:
            return False, f"Git configuration failed: {str(e)}"
        except Exception as e:
            return False, f"Git configuration error: {str(e)}"

    def setup_ssh_keys(self) -> Tuple[bool, str]:
        """Setup SSH keys for GitHub authentication."""
        self.logger.info("Setting up SSH keys for GitHub...")
        
        try:
            # Create .ssh directory if it doesn't exist
            self.ssh_dir.mkdir(mode=0o700, exist_ok=True)
            
            # Check if SSH key already exists
            ssh_key_path = self.ssh_dir / 'id_ed25519'
            ssh_pub_key_path = self.ssh_dir / 'id_ed25519.pub'
            
            if ssh_key_path.exists() and ssh_pub_key_path.exists():
                self.logger.info("SSH key already exists")
                return self._verify_ssh_key_setup(ssh_pub_key_path, 0)
            
            # Generate new SSH key
            user_email = self.config.get('user', {}).get('email', '')
            if not user_email:
                return False, "User email required for SSH key generation"
            
            # Get passphrase from config (required field now)
            ssh_passphrase = self.config.get('git', {}).get('ssh_passphrase', '')
            if not ssh_passphrase:
                return False, "SSH passphrase is required for security. Please run config setup again."
            
            self.logger.info("Generating new SSH key with passphrase...")
            subprocess.run([
                'ssh-keygen', '-t', 'ed25519', '-C', user_email,
                '-f', str(ssh_key_path), '-N', ssh_passphrase
            ], check=True, capture_output=True, text=True)
            
            # Set proper permissions
            ssh_key_path.chmod(0o600)
            ssh_pub_key_path.chmod(0o644)
            
            # Add SSH key to SSH agent
            self._add_ssh_key_to_agent(ssh_key_path)
            
            # Display public key and instructions
            with open(ssh_pub_key_path, 'r') as f:
                public_key = f.read().strip()
            
            self._show_ssh_key_instructions(public_key)
            
            return True, "SSH key generated successfully"
            
        except subprocess.CalledProcessError as e:
            return False, f"SSH key generation failed: {str(e)}"
        except Exception as e:
            return False, f"SSH key setup error: {str(e)}"

    def _add_ssh_key_to_agent(self, ssh_key_path: Path) -> None:
        """Add SSH key to the SSH agent."""
        import platform
        
        try:
            # Get passphrase from config
            ssh_passphrase = self.config.get('git', {}).get('ssh_passphrase', '')
            
            # On macOS, we need to use the keychain
            if platform.system() == 'Darwin':
                # Add to keychain for automatic unlocking
                subprocess.run(['ssh-add', '--apple-use-keychain', str(ssh_key_path)], 
                             capture_output=True, text=True, input=ssh_passphrase + '\n')
            else:
                # On Linux, just add normally
                subprocess.run(['ssh-add', str(ssh_key_path)], 
                             capture_output=True, text=True, input=ssh_passphrase + '\n')
            
            self.logger.info("SSH key added to agent")
        except subprocess.CalledProcessError:
            self.logger.warning("Could not add SSH key to agent automatically (passphrase will be needed for git operations)")

    def _show_ssh_key_instructions(self, public_key: str) -> None:
        """Show instructions for adding SSH key to GitHub."""
        import platform
        import subprocess
        from pathlib import Path
        
        # Save SSH key to a file in the working directory
        ssh_key_file = Path.cwd() / 'ssh_public_key.txt'
        with open(ssh_key_file, 'w') as f:
            f.write(public_key)
        
        # Try to copy to clipboard on Mac
        clipboard_success = False
        if platform.system() == 'Darwin':  # macOS
            try:
                subprocess.run(['pbcopy'], input=public_key.encode(), check=True)
                clipboard_success = True
            except (subprocess.SubprocessError, FileNotFoundError):
                pass
        
        print(f"""
╔══════════════════════════════════════════════════════════════╗
║                     SSH KEY SETUP REQUIRED                  ║
╚══════════════════════════════════════════════════════════════╝

Your SSH public key has been generated:

{'✅ AUTOMATICALLY COPIED TO CLIPBOARD!' if clipboard_success else '📋 Copy this key:'}
{'-' * 66}
{public_key}
{'-' * 66}

📁 Key also saved to: {ssh_key_file}
   You can open this file if you need to copy it again.
   (This file can be deleted after adding to GitHub)

TO ADD TO GITHUB:
1. Go to: https://github.com/settings/ssh/new
2. {'Paste the key (already in clipboard)' if clipboard_success else 'Copy and paste the key above'}
3. Title: "Legion Development - {platform.node()}"
4. Click "Add SSH key"

IMPORTANT - SAML Authorization Required:
5. After adding the key, go to: https://github.com/settings/keys
6. Find your new SSH key in the list
7. Click "Configure SSO" next to the key
8. Click "Authorize" for the "legionco" organization
9. Complete the SAML authentication if prompted

Have you added AND authorized the SSH key for legionco? (y/n): """, end='')
        
        # Always wait for SSH key confirmation, even with auto_confirm
        # This is critical for setup to work
        while True:
            response = input().strip().lower()
            if response in ['y', 'yes']:
                print("Great! Verifying SSH key with GitHub...")
                break
            elif response in ['n', 'no']:
                print("\nPlease complete these steps:")
                print("1. Add the SSH key to GitHub")
                print("2. Authorize it for the 'legionco' organization (Configure SSO)")
                print("\nHave you added AND authorized the SSH key for legionco? (y/n): ", end='')
            else:
                print("Please enter 'y' for yes or 'n' for no: ", end='')

    def _verify_ssh_key_setup(self, ssh_pub_key_path: Path, retry_count: int = 0) -> Tuple[bool, str]:
        """Verify SSH key is properly set up."""
        max_retries = 3
        
        try:
            # Test SSH connection to GitHub
            result = subprocess.run([
                'ssh', '-T', 'git@github.com', '-o', 'StrictHostKeyChecking=no'
            ], capture_output=True, text=True, timeout=10)
            
            # SSH to GitHub returns exit code 1 on success (weird but true)
            if result.returncode == 1 and 'successfully authenticated' in result.stderr:
                self.logger.info("✅ SSH key verified with GitHub")
                return True, "SSH key verified with GitHub"
            elif 'Permission denied' in result.stderr:
                if retry_count >= max_retries:
                    return False, "SSH key setup failed after multiple attempts"
                
                # Show the key for manual setup
                with open(ssh_pub_key_path, 'r') as f:
                    public_key = f.read().strip()
                self._show_ssh_key_instructions(public_key)
                
                # After user presses Enter, wait a moment then retry
                self.logger.info("Verifying SSH key with GitHub...")
                time.sleep(2)  # Give GitHub a moment to process the key
                
                return self._verify_ssh_key_setup(ssh_pub_key_path, retry_count + 1)  # Retry
            else:
                return False, f"SSH verification failed: {result.stderr}"
                
        except subprocess.TimeoutExpired:
            return False, "SSH connection to GitHub timed out"
        except Exception as e:
            return False, f"SSH verification error: {str(e)}"

    def clone_repositories(self) -> Tuple[bool, str]:
        """Clone both enterprise and console-ui repositories."""
        self.logger.info("Cloning Legion repositories...")
        
        results = []
        overall_success = True
        
        for repo_name, repo_config in self.repositories.items():
            self.logger.info(f"Cloning {repo_name} repository...")
            
            try:
                success, message = self._clone_single_repository(repo_name, repo_config)
                results.append(f"{repo_name}: {message}")
                
                if not success:
                    overall_success = False
                    
            except Exception as e:
                error_msg = f"{repo_name} clone error: {str(e)}"
                results.append(error_msg)
                overall_success = False
        
        result_message = "; ".join(results)
        return overall_success, result_message

    def _clone_single_repository(self, repo_name: str, repo_config: Dict) -> Tuple[bool, str]:
        """Clone a single repository with proper setup."""
        repo_url = repo_config['url']
        repo_path = repo_config['path']
        has_submodules = repo_config.get('has_submodules', False)
        
        try:
            # Create parent directory
            repo_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Check if repository already exists
            if repo_path.exists() and (repo_path / '.git').exists():
                self.logger.info(f"Repository {repo_name} already exists, removing for fresh clone...")
                # Remove existing repository for a fresh clone
                import shutil
                shutil.rmtree(repo_path)
                self.logger.info(f"Removed existing {repo_name} repository")
            
            # Clone the repository (without recursive submodules initially)
            # Use HTTPS for enterprise repo to avoid auth issues with submodules
            if repo_name == 'enterprise':
                https_url = 'https://github.com/legionco/enterprise.git'
                subprocess.run([
                    'git', 'clone', https_url, str(repo_path)
                ], check=True, capture_output=True, text=True, timeout=1800)  # 30 minutes for large repos
                
                # After cloning, update the origin to use SSH for future pushes
                original_cwd = os.getcwd()
                os.chdir(repo_path)
                subprocess.run(['git', 'remote', 'set-url', 'origin', repo_url],
                             capture_output=True, text=True)
                
                # Initialize and update submodules as per README instructions
                self.logger.info("Initializing submodules...")
                result = subprocess.run(['git', 'submodule', 'update', '--init', '--recursive'],
                                      capture_output=True, text=True, timeout=1800)  # 30 minutes for submodules
                if result.returncode != 0:
                    self.logger.warning(f"Some submodules may not be accessible: {result.stderr}")
                    # Continue anyway - some submodules might be private
                
                os.chdir(original_cwd)
                self.logger.info(f"Cloned {repo_name} and initialized available submodules")
            else:
                # For repos without submodules, use SSH directly
                subprocess.run([
                    'git', 'clone', repo_url, str(repo_path)
                ], check=True, capture_output=True, text=True, timeout=1800)  # 30 minutes for large repos
            
            # Post-clone setup
            self._post_clone_setup(repo_name, repo_path, has_submodules)
            
            return True, f"{repo_name} cloned successfully to {repo_path}"
            
        except subprocess.CalledProcessError as e:
            error_output = e.stderr if e.stderr else str(e)
            
            # Check for SAML SSO error
            if 'SAML SSO' in error_output or 'legionco' in error_output:
                saml_help = f"""
                
⚠️  SAML Authorization Required for {repo_name}!

The SSH key needs to be authorized for the Legion organization:
1. Go to: https://github.com/settings/keys
2. Find your SSH key
3. Click "Configure SSO" 
4. Authorize for "legionco" organization
5. Re-run the setup after authorization

"""
                print(saml_help)
                self.logger.error(f"SAML authorization required for {repo_name}")
            
            return False, f"{repo_name} clone failed: {error_output}"
        except subprocess.TimeoutExpired:
            return False, f"{repo_name} clone timed out"
        except Exception as e:
            return False, f"{repo_name} clone error: {str(e)}"

    def _update_existing_repository(self, repo_name: str, repo_path: Path, has_submodules: bool) -> Tuple[bool, str]:
        """Update an existing repository."""
        try:
            # Change to repository directory
            original_cwd = os.getcwd()
            os.chdir(repo_path)
            
            try:
                # Fetch latest changes
                subprocess.run(['git', 'fetch', 'origin'], check=True, capture_output=True, text=True)
                
                # Check current branch
                result = subprocess.run(['git', 'branch', '--show-current'], 
                                      capture_output=True, text=True, check=True)
                current_branch = result.stdout.strip()
                
                # Pull latest changes if on a standard branch
                if current_branch in ['main', 'master', 'develop']:
                    subprocess.run(['git', 'pull', 'origin', current_branch], 
                                 check=True, capture_output=True, text=True)
                    
                    # Update submodules if applicable
                    if has_submodules:
                        # Update submodules (they were cloned with --recurse-submodules)
                        subprocess.run(['git', 'submodule', 'update', '--init', '--recursive'],
                                     capture_output=True, text=True)
                
                return True, f"{repo_name} updated successfully"
                
            finally:
                os.chdir(original_cwd)
                
        except subprocess.CalledProcessError as e:
            return False, f"{repo_name} update failed: {str(e)}"
        except Exception as e:
            return False, f"{repo_name} update error: {str(e)}"

    def _post_clone_setup(self, repo_name: str, repo_path: Path, has_submodules: bool) -> None:
        """Perform post-clone setup tasks."""
        try:
            original_cwd = os.getcwd()
            os.chdir(repo_path)
            
            try:
                # Set up git hooks if they exist
                hooks_dir = repo_path / '.githooks'
                if hooks_dir.exists():
                    subprocess.run(['git', 'config', 'core.hooksPath', '.githooks'], 
                                 capture_output=True, text=True)
                
                # Ensure submodules are on correct branches
                if has_submodules and repo_name == 'enterprise':
                    self._setup_enterprise_submodules(repo_path)
                
                # Set up any repository-specific configurations
                if repo_name == 'enterprise':
                    self._setup_enterprise_specific_config(repo_path)
                elif repo_name == 'console-ui':
                    self._setup_console_ui_specific_config(repo_path)
                    
            finally:
                os.chdir(original_cwd)
                
        except Exception as e:
            self.logger.warning(f"Post-clone setup warning for {repo_name}: {str(e)}")

    def _setup_submodules_with_ssh(self, repo_path: Path) -> None:
        """Setup submodules with SSH URLs to avoid HTTPS authentication prompts."""
        try:
            original_cwd = os.getcwd()
            os.chdir(repo_path)
            
            try:
                # First, check if there are submodules
                gitmodules_path = repo_path / '.gitmodules'
                if gitmodules_path.exists():
                    self.logger.info("Converting submodule URLs to SSH...")
                    
                    # Read the .gitmodules file
                    with open(gitmodules_path, 'r') as f:
                        content = f.read()
                    
                    # Replace HTTPS URLs with SSH URLs
                    original_content = content
                    content = content.replace('https://github.com/', 'git@github.com:')
                    
                    if content != original_content:
                        # Write back the modified content
                        with open(gitmodules_path, 'w') as f:
                            f.write(content)
                        
                        # Stage the change (but don't commit - let user decide)
                        subprocess.run(['git', 'add', '.gitmodules'], capture_output=True, text=True)
                        self.logger.info("Updated .gitmodules to use SSH URLs")
                    
                    # Sync the submodule URLs with the new config
                    subprocess.run(['git', 'submodule', 'sync'], capture_output=True, text=True)
                    
                    # Initialize submodules
                    subprocess.run(['git', 'submodule', 'init'], capture_output=True, text=True)
                    
                    # Update submodules (without recursive to avoid nested HTTPS issues)
                    result = subprocess.run(['git', 'submodule', 'update'], 
                                          capture_output=True, text=True, timeout=300)
                    
                    if result.returncode == 0:
                        self.logger.info("Submodules initialized successfully")
                    else:
                        self.logger.warning(f"Submodule update had issues: {result.stderr}")
                
            finally:
                os.chdir(original_cwd)
                
        except Exception as e:
            self.logger.warning(f"Submodule setup warning: {str(e)}")
    
    def _setup_enterprise_submodules(self, repo_path: Path) -> None:
        """Setup enterprise repository submodules properly."""
        try:
            # Verify submodules are initialized (they should be from clone step)
            result = subprocess.run(['git', 'submodule', 'status'], 
                                  capture_output=True, text=True)
            
            if result.returncode == 0:
                # Check if any submodules need updating to latest
                # Using --remote as per README for forcing sync to latest
                update_result = subprocess.run(['git', 'submodule', 'update', '--recursive', '--remote'],
                                              capture_output=True, text=True)
                if update_result.returncode == 0:
                    self.logger.info("Enterprise submodules synced to latest")
                else:
                    # This is not critical - some submodules might be private
                    self.logger.info("Submodules initialized (some may be private/inaccessible)")
            else:
                self.logger.warning(f"Submodule status check: {result.stderr}")
            
        except subprocess.CalledProcessError as e:
            self.logger.warning(f"Submodule setup warning: {str(e)}")

    def _setup_enterprise_specific_config(self, repo_path: Path) -> None:
        """Setup enterprise repository specific configurations."""
        try:
            # Set up any enterprise-specific git configurations
            subprocess.run(['git', 'config', 'pull.rebase', 'true'], 
                         capture_output=True, text=True)
            
            # Ensure proper line endings for the project
            subprocess.run(['git', 'config', 'core.autocrlf', 'input'], 
                         capture_output=True, text=True)
            
        except Exception as e:
            self.logger.warning(f"Enterprise config warning: {str(e)}")

    def _setup_console_ui_specific_config(self, repo_path: Path) -> None:
        """Setup console-ui repository specific configurations."""
        try:
            # Console-UI specific configurations
            subprocess.run(['git', 'config', 'core.autocrlf', 'false'], 
                         capture_output=True, text=True)
            
        except Exception as e:
            self.logger.warning(f"Console-UI config warning: {str(e)}")

    def setup_github_cli(self) -> Tuple[bool, str]:
        """Setup GitHub CLI tool for enhanced GitHub integration."""
        self.logger.info("Setting up GitHub CLI...")
        
        try:
            # Check if gh is already installed
            result = subprocess.run(['gh', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                self.logger.info("GitHub CLI already installed")
                return self._configure_github_cli()
            
            # Install GitHub CLI
            if self.platform == 'darwin':
                # macOS - use Homebrew
                if self._command_exists('brew'):
                    subprocess.run(['brew', 'install', 'gh'], check=True)
                else:
                    return False, "Homebrew required for GitHub CLI installation on macOS"
                    
            elif self.platform == 'linux':
                # Linux - use package manager or manual install
                if self._command_exists('apt-get'):
                    # Ubuntu/Debian
                    subprocess.run(['sudo', 'apt', 'update'], check=True)
                    subprocess.run(['sudo', 'apt', 'install', '-y', 'gh'], check=True)
                elif self._command_exists('yum') or self._command_exists('dnf'):
                    # RHEL/CentOS/Fedora
                    package_manager = 'dnf' if self._command_exists('dnf') else 'yum'
                    subprocess.run(['sudo', package_manager, 'install', '-y', 'gh'], check=True)
                else:
                    return self._install_github_cli_manual()
            
            return self._configure_github_cli()
            
        except subprocess.CalledProcessError as e:
            return False, f"GitHub CLI installation failed: {str(e)}"
        except Exception as e:
            return False, f"GitHub CLI setup error: {str(e)}"

    def _install_github_cli_manual(self) -> Tuple[bool, str]:
        """Manual GitHub CLI installation for unsupported package managers."""
        try:
            # Download and install GitHub CLI manually
            arch = platform.machine().lower()
            if arch == 'x86_64':
                arch = 'amd64'
            elif arch == 'aarch64':
                arch = 'arm64'
            
            download_url = f"https://github.com/cli/cli/releases/latest/download/gh_linux_{arch}.tar.gz"
            
            # This would require implementing download and extraction logic
            # For now, provide instructions
            self.logger.warning("Manual GitHub CLI installation required")
            return False, "GitHub CLI requires manual installation on this system"
            
        except Exception as e:
            return False, f"Manual GitHub CLI installation error: {str(e)}"

    def _configure_github_cli(self) -> Tuple[bool, str]:
        """Configure GitHub CLI for authentication."""
        try:
            # Check if already authenticated
            result = subprocess.run(['gh', 'auth', 'status'], capture_output=True, text=True)
            if result.returncode == 0:
                self.logger.info("GitHub CLI already authenticated")
                return True, "GitHub CLI already authenticated"
            
            # Authenticate with GitHub
            print("\n🔐 GitHub CLI Authentication Required")
            print("Please follow the prompts to authenticate with GitHub...")
            
            # Use SSH for authentication since we set up SSH keys
            subprocess.run(['gh', 'auth', 'login', '--git-protocol', 'ssh'], check=True)
            
            return True, "GitHub CLI authenticated successfully"
            
        except subprocess.CalledProcessError as e:
            return False, f"GitHub CLI authentication failed: {str(e)}"
        except Exception as e:
            return False, f"GitHub CLI configuration error: {str(e)}"

    def verify_git_setup(self) -> Tuple[bool, Dict[str, Any]]:
        """Verify complete Git and GitHub setup."""
        self.logger.info("Verifying Git and GitHub setup...")
        
        results = {
            'git_config': self._verify_git_config(),
            'ssh_keys': self._verify_ssh_keys(),
            'github_access': self._verify_github_access(),
            'repositories': self._verify_repositories()
        }
        
        all_passed = all(result['success'] for result in results.values())
        
        return all_passed, results

    def _verify_git_config(self) -> Dict[str, Any]:
        """Verify Git configuration."""
        try:
            # Check user name and email
            name_result = subprocess.run(['git', 'config', 'user.name'], 
                                       capture_output=True, text=True)
            email_result = subprocess.run(['git', 'config', 'user.email'], 
                                        capture_output=True, text=True)
            
            has_name = name_result.returncode == 0 and name_result.stdout.strip()
            has_email = email_result.returncode == 0 and email_result.stdout.strip()
            
            return {
                'success': has_name and has_email,
                'name': name_result.stdout.strip() if has_name else None,
                'email': email_result.stdout.strip() if has_email else None,
                'message': 'Git configuration verified' if has_name and has_email else 'Git configuration incomplete'
            }
            
        except Exception as e:
            return {
                'success': False,
                'name': None,
                'email': None,
                'message': f'Git config verification error: {str(e)}'
            }

    def _verify_ssh_keys(self) -> Dict[str, Any]:
        """Verify SSH key setup."""
        ssh_key_path = self.ssh_dir / 'id_ed25519'
        ssh_pub_key_path = self.ssh_dir / 'id_ed25519.pub'
        
        keys_exist = ssh_key_path.exists() and ssh_pub_key_path.exists()
        
        if not keys_exist:
            return {
                'success': False,
                'message': 'SSH keys not found'
            }
        
        # Test SSH connection to GitHub
        try:
            result = subprocess.run([
                'ssh', '-T', 'git@github.com', '-o', 'ConnectTimeout=10'
            ], capture_output=True, text=True, timeout=15)
            
            github_accessible = (result.returncode == 1 and 'successfully authenticated' in result.stderr)
            
            return {
                'success': github_accessible,
                'keys_exist': keys_exist,
                'github_accessible': github_accessible,
                'message': 'SSH keys verified with GitHub' if github_accessible else 'SSH keys exist but GitHub access failed'
            }
            
        except Exception as e:
            return {
                'success': False,
                'keys_exist': keys_exist,
                'github_accessible': False,
                'message': f'SSH verification error: {str(e)}'
            }

    def _verify_github_access(self) -> Dict[str, Any]:
        """Verify GitHub CLI access."""
        try:
            if not self._command_exists('gh'):
                return {
                    'success': False,
                    'message': 'GitHub CLI not installed'
                }
            
            result = subprocess.run(['gh', 'auth', 'status'], capture_output=True, text=True)
            authenticated = result.returncode == 0
            
            return {
                'success': authenticated,
                'authenticated': authenticated,
                'message': 'GitHub CLI authenticated' if authenticated else 'GitHub CLI not authenticated'
            }
            
        except Exception as e:
            return {
                'success': False,
                'authenticated': False,
                'message': f'GitHub CLI verification error: {str(e)}'
            }

    def _verify_repositories(self) -> Dict[str, Any]:
        """Verify repository clones."""
        repo_results = {}
        all_success = True
        
        for repo_name, repo_config in self.repositories.items():
            repo_path = repo_config['path']
            
            exists = repo_path.exists() and (repo_path / '.git').exists()
            
            if exists:
                # Check if it's the correct repository
                try:
                    original_cwd = os.getcwd()
                    os.chdir(repo_path)
                    
                    result = subprocess.run(['git', 'remote', 'get-url', 'origin'], 
                                          capture_output=True, text=True)
                    
                    correct_repo = (result.returncode == 0 and 
                                  repo_config['url'] in result.stdout)
                    
                    os.chdir(original_cwd)
                    
                    repo_results[repo_name] = {
                        'exists': exists,
                        'correct_repo': correct_repo,
                        'path': str(repo_path),
                        'success': correct_repo,
                        'message': f'Repository verified at {repo_path}' if correct_repo else 'Repository exists but incorrect origin'
                    }
                    
                    if not correct_repo:
                        all_success = False
                        
                except Exception as e:
                    repo_results[repo_name] = {
                        'exists': exists,
                        'correct_repo': False,
                        'path': str(repo_path),
                        'success': False,
                        'message': f'Repository verification error: {str(e)}'
                    }
                    all_success = False
            else:
                repo_results[repo_name] = {
                    'exists': exists,
                    'correct_repo': False,
                    'path': str(repo_path),
                    'success': False,
                    'message': f'Repository not found at {repo_path}'
                }
                all_success = False
        
        return {
            'success': all_success,
            'repositories': repo_results,
            'message': 'All repositories verified' if all_success else 'Some repositories missing or incorrect'
        }

    def _command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH."""
        import shutil
        return shutil.which(command) is not None