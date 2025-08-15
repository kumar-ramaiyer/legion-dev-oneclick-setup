#!/usr/bin/env python3
"""
Legion Setup - Software Installation Module
Handles installation of required software components
"""

import os
import sys
import subprocess
import platform
import urllib.request
import urllib.error
import tarfile
import zipfile
import shutil
import time
import hashlib
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import tempfile

class SoftwareInstaller:
    def __init__(self, config: Dict, logger):
        self.config = config
        self.logger = logger
        self.platform = platform.system().lower()
        self.temp_dir = Path(tempfile.mkdtemp(prefix='legion_setup_'))
        self.install_paths = config.get('paths', {})
        
    def __del__(self):
        """Cleanup temporary directory."""
        if hasattr(self, 'temp_dir') and self.temp_dir.exists():
            shutil.rmtree(self.temp_dir, ignore_errors=True)

    def install_homebrew(self) -> Tuple[bool, str]:
        """Install Homebrew on macOS."""
        if self.platform != 'darwin':
            return True, "Homebrew installation skipped (not macOS)"
        
        self.logger.info("Installing Homebrew...")
        
        # Alert user that password will be needed
        print("\n" + "="*60)
        print("🔐 HOMEBREW INSTALLATION")
        print("="*60)
        print("Homebrew requires your macOS password to install.")
        print("Please enter your Mac login password when prompted.")
        print("Note: The password won't be visible as you type.")
        print("="*60 + "\n")
        
        try:
            # Download and run Homebrew install script
            install_script = """
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            """.strip()
            
            result = subprocess.run(install_script, shell=True, 
                                  capture_output=True, text=True, timeout=600)
            
            if result.returncode == 0:
                # Add Homebrew to PATH
                self._add_to_path('/opt/homebrew/bin')
                return True, "Homebrew installed successfully"
            else:
                return False, f"Homebrew installation failed: {result.stderr}"
                
        except subprocess.TimeoutExpired:
            return False, "Homebrew installation timed out"
        except Exception as e:
            return False, f"Homebrew installation error: {str(e)}"

    def install_java_corretto(self) -> Tuple[bool, str]:
        """Install Amazon Corretto JDK 17."""
        self.logger.info("Installing Amazon Corretto JDK 17...")
        
        if self.platform == 'darwin':
            return self._install_java_macos()
        elif self.platform == 'linux':
            return self._install_java_linux()
        else:
            return False, f"Java installation not supported on {self.platform}"

    def _install_java_macos(self) -> Tuple[bool, str]:
        """Install Java on macOS."""
        try:
            # Try using Homebrew first
            if shutil.which('brew'):
                result = subprocess.run(
                    ['brew', 'install', '--cask', 'corretto17'],
                    capture_output=True, text=True, timeout=300
                )
                
                if result.returncode == 0:
                    return True, "Amazon Corretto 17 installed via Homebrew"
            
            # Manual installation if Homebrew fails
            download_url = "https://corretto.aws/downloads/latest/amazon-corretto-17-x64-macos-jdk.pkg"
            pkg_file = self.temp_dir / "corretto-17.pkg"
            
            self._download_file(download_url, pkg_file)
            
            # Alert user about password requirement
            print("\n" + "="*60)
            print("🔐 JAVA INSTALLATION")
            print("="*60)
            print("Installing Java requires administrator privileges.")
            print("Please enter your Mac login password when prompted.")
            print("="*60 + "\n")
            
            # Install the package
            result = subprocess.run(
                ['sudo', 'installer', '-pkg', str(pkg_file), '-target', '/'],
                capture_output=True, text=True
            )
            
            if result.returncode == 0:
                return True, "Amazon Corretto 17 installed manually"
            else:
                return False, f"Java installation failed: {result.stderr}"
                
        except Exception as e:
            return False, f"Java installation error: {str(e)}"

    def _install_java_linux(self) -> Tuple[bool, str]:
        """Install Java on Linux."""
        try:
            # Ubuntu/Debian
            if shutil.which('apt-get'):
                commands = [
                    ['sudo', 'apt', 'update'],
                    ['sudo', 'apt', 'install', '-y', 'wget', 'software-properties-common'],
                    ['wget', '-O', '-', 'https://apt.corretto.aws/corretto.key', '|', 'sudo', 'apt-key', 'add', '-'],
                    ['sudo', 'add-apt-repository', 'deb https://apt.corretto.aws stable main'],
                    ['sudo', 'apt', 'update'],
                    ['sudo', 'apt', 'install', '-y', 'java-17-amazon-corretto-jdk']
                ]
            
            # RHEL/CentOS/Fedora
            elif shutil.which('yum') or shutil.which('dnf'):
                package_manager = 'dnf' if shutil.which('dnf') else 'yum'
                commands = [
                    ['sudo', package_manager, 'install', '-y', 'java-17-amazon-corretto-devel']
                ]
            
            else:
                return False, "Unsupported Linux distribution for Java installation"
            
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode != 0:
                    return False, f"Command failed: {' '.join(command)}"
            
            return True, "Amazon Corretto 17 installed successfully"
            
        except Exception as e:
            return False, f"Java installation error: {str(e)}"

    def install_maven(self) -> Tuple[bool, str]:
        """Install Apache Maven."""
        self.logger.info("Installing Apache Maven...")
        
        version = self.config.get('versions', {}).get('maven', '3.9.9')
        
        try:
            # Try Homebrew on macOS first
            if self.platform == 'darwin' and shutil.which('brew'):
                result = subprocess.run(
                    ['brew', 'install', 'maven'],
                    capture_output=True, text=True, timeout=300
                )
                
                if result.returncode == 0:
                    return True, f"Maven installed via Homebrew"
            
            # Manual installation
            return self._install_maven_manual(version)
            
        except Exception as e:
            return False, f"Maven installation error: {str(e)}"

    def _install_maven_manual(self, version: str) -> Tuple[bool, str]:
        """Install Maven manually."""
        try:
            # Download Maven
            download_url = f"https://archive.apache.org/dist/maven/maven-3/{version}/binaries/apache-maven-{version}-bin.tar.gz"
            maven_archive = self.temp_dir / f"apache-maven-{version}-bin.tar.gz"
            
            self._download_file(download_url, maven_archive)
            
            # Extract Maven
            install_path = Path(self.install_paths.get('maven_install_path', '/usr/local/maven'))
            install_path.parent.mkdir(parents=True, exist_ok=True)
            
            with tarfile.open(maven_archive, 'r:gz') as tar:
                tar.extractall(path=install_path.parent)
            
            # Move to final location
            extracted_dir = install_path.parent / f"apache-maven-{version}"
            if install_path.exists():
                shutil.rmtree(install_path)
            extracted_dir.rename(install_path)
            
            # Add to PATH
            maven_bin = install_path / 'bin'
            self._add_to_path(str(maven_bin))
            
            return True, f"Maven {version} installed to {install_path}"
            
        except Exception as e:
            return False, f"Manual Maven installation error: {str(e)}"

    def install_nodejs(self) -> Tuple[bool, str]:
        """Install Node.js using NVM."""
        self.logger.info("Installing Node.js...")
        
        node_version = self.config.get('versions', {}).get('node', 'latest')
        yarn_version = self.config.get('versions', {}).get('yarn', 'latest')
        lerna_version = self.config.get('versions', {}).get('lerna', '6')
        
        try:
            # Install NVM first
            nvm_success, nvm_message = self._install_nvm()
            if not nvm_success:
                return False, f"NVM installation failed: {nvm_message}"
            
            # Determine Node.js version to install
            if node_version == 'latest':
                node_install_cmd = 'nvm install node'  # Installs latest
                node_use_cmd = 'nvm use node'
                node_alias_cmd = 'nvm alias default node'
            else:
                node_install_cmd = f'nvm install {node_version}'
                node_use_cmd = f'nvm use {node_version}'
                node_alias_cmd = f'nvm alias default {node_version}'
            
            # Install Node.js, Yarn, and Lerna
            nvm_script = f"""
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
{node_install_cmd}
{node_use_cmd}
{node_alias_cmd}
npm install -g yarn@{yarn_version if yarn_version != 'latest' else 'latest'}
npm install -g lerna@{lerna_version}
            """.strip()
            
            result = subprocess.run(
                ['bash', '-c', nvm_script],
                capture_output=True, text=True, timeout=600
            )
            
            if result.returncode == 0:
                return True, f"Node.js (latest), Yarn, and Lerna {lerna_version} installed"
            else:
                return False, f"Node.js installation failed: {result.stderr}"
                
        except Exception as e:
            return False, f"Node.js installation error: {str(e)}"

    def _install_nvm(self) -> Tuple[bool, str]:
        """Install Node Version Manager (NVM)."""
        try:
            # Download and install NVM
            install_script = """
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
            """.strip()
            
            result = subprocess.run(
                install_script, shell=True,
                capture_output=True, text=True, timeout=300
            )
            
            if result.returncode == 0:
                return True, "NVM installed successfully"
            else:
                return False, f"NVM installation failed: {result.stderr}"
                
        except Exception as e:
            return False, f"NVM installation error: {str(e)}"

    def install_mysql(self) -> Tuple[bool, str]:
        """Install MySQL 8.0."""
        self.logger.info("Installing MySQL 8.0...")
        
        try:
            if self.platform == 'darwin':
                return self._install_mysql_macos()
            elif self.platform == 'linux':
                return self._install_mysql_linux()
            else:
                return False, f"MySQL installation not supported on {self.platform}"
                
        except Exception as e:
            return False, f"MySQL installation error: {str(e)}"

    def _install_mysql_macos(self) -> Tuple[bool, str]:
        """Install MySQL on macOS."""
        try:
            if shutil.which('brew'):
                # Install MySQL using Homebrew
                result = subprocess.run(
                    ['brew', 'install', 'mysql'],
                    capture_output=True, text=True, timeout=600
                )
                
                if result.returncode == 0:
                    # Start MySQL service
                    subprocess.run(['brew', 'services', 'start', 'mysql'])
                    return True, "MySQL installed and started via Homebrew"
                else:
                    return False, f"MySQL installation failed: {result.stderr}"
            else:
                return False, "Homebrew required for MySQL installation on macOS"
                
        except Exception as e:
            return False, f"MySQL installation error: {str(e)}"

    def _install_mysql_linux(self) -> Tuple[bool, str]:
        """Install MySQL on Linux."""
        try:
            # Ubuntu/Debian
            if shutil.which('apt-get'):
                commands = [
                    ['sudo', 'apt', 'update'],
                    ['sudo', 'apt', 'install', '-y', 'mysql-server-8.0'],
                    ['sudo', 'systemctl', 'start', 'mysql'],
                    ['sudo', 'systemctl', 'enable', 'mysql']
                ]
            
            # RHEL/CentOS/Fedora
            elif shutil.which('yum') or shutil.which('dnf'):
                package_manager = 'dnf' if shutil.which('dnf') else 'yum'
                commands = [
                    ['sudo', package_manager, 'install', '-y', 'mysql-server'],
                    ['sudo', 'systemctl', 'start', 'mysqld'],
                    ['sudo', 'systemctl', 'enable', 'mysqld']
                ]
            
            else:
                return False, "Unsupported Linux distribution for MySQL installation"
            
            for command in commands:
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode != 0:
                    return False, f"Command failed: {' '.join(command)}"
            
            return True, "MySQL installed and started successfully"
            
        except Exception as e:
            return False, f"MySQL installation error: {str(e)}"

    def install_yarn(self) -> Tuple[bool, str]:
        """Install Yarn package manager."""
        self.logger.info("Installing Yarn...")
        
        try:
            # Install using npm
            result = subprocess.run(
                ['npm', 'install', '-g', 'yarn'],
                capture_output=True, text=True, timeout=300
            )
            
            if result.returncode == 0:
                return True, "Yarn installed successfully"
            else:
                # Try with sudo if permission denied
                if 'permission' in result.stderr.lower() or 'access' in result.stderr.lower():
                    result = subprocess.run(
                        ['sudo', 'npm', 'install', '-g', 'yarn'],
                        capture_output=True, text=True, timeout=300
                    )
                    if result.returncode == 0:
                        return True, "Yarn installed successfully (with sudo)"
                
                return False, f"Yarn installation failed: {result.stderr}"
                
        except FileNotFoundError:
            return False, "npm not found - install Node.js first"
        except Exception as e:
            return False, f"Yarn installation error: {str(e)}"
    
    def install_lerna(self) -> Tuple[bool, str]:
        """Install Lerna v6 for monorepo management."""
        self.logger.info("Installing Lerna v6...")
        
        try:
            # Install Lerna v6 specifically
            result = subprocess.run(
                ['npm', 'install', '-g', 'lerna@6'],
                capture_output=True, text=True, timeout=300
            )
            
            if result.returncode == 0:
                return True, "Lerna v6 installed successfully"
            else:
                # Try with sudo if permission denied
                if 'permission' in result.stderr.lower() or 'access' in result.stderr.lower():
                    result = subprocess.run(
                        ['sudo', 'npm', 'install', '-g', 'lerna@6'],
                        capture_output=True, text=True, timeout=300
                    )
                    if result.returncode == 0:
                        return True, "Lerna v6 installed successfully (with sudo)"
                
                return False, f"Lerna installation failed: {result.stderr}"
                
        except FileNotFoundError:
            return False, "npm not found - install Node.js first"
        except Exception as e:
            return False, f"Lerna installation error: {str(e)}"
    
    def install_python_packages(self) -> Tuple[bool, str]:
        """Install required Python packages."""
        self.logger.info("Installing Python packages...")
        
        packages = ['yasha', 'mysql-connector-python', 'PyYAML']
        
        try:
            # Install pipx if not available
            if not shutil.which('pipx'):
                if self.platform == 'darwin' and shutil.which('brew'):
                    subprocess.run(['brew', 'install', 'pipx'], check=True)
                else:
                    subprocess.run([sys.executable, '-m', 'pip', 'install', 'pipx'], check=True)
                
                # Ensure pipx path
                subprocess.run(['pipx', 'ensurepath'], check=True)
            
            # Install yasha using pipx
            result = subprocess.run(
                ['pipx', 'install', 'yasha'],
                capture_output=True, text=True
            )
            
            if result.returncode != 0:
                return False, f"Failed to install yasha: {result.stderr}"
            
            # Install other packages using pip
            other_packages = ['mysql-connector-python', 'PyYAML']
            result = subprocess.run(
                [sys.executable, '-m', 'pip', 'install'] + other_packages,
                capture_output=True, text=True
            )
            
            if result.returncode != 0:
                return False, f"Failed to install Python packages: {result.stderr}"
            
            return True, f"Python packages installed: {', '.join(packages)}"
            
        except Exception as e:
            return False, f"Python packages installation error: {str(e)}"

    def setup_docker_elasticsearch(self) -> Tuple[bool, str]:
        """Setup Docker and Elasticsearch."""
        self.logger.info("Setting up Docker and Elasticsearch...")
        
        try:
            # Check if Docker is running
            result = subprocess.run(['docker', 'info'], capture_output=True, text=True)
            if result.returncode != 0:
                return False, "Docker is not running. Please start Docker Desktop."
            
            # Create elastic network
            subprocess.run(['docker', 'network', 'create', 'elastic'], 
                         capture_output=True, text=True)
            
            # Pull Elasticsearch image
            es_version = self.config.get('versions', {}).get('elasticsearch', '8.0.0')
            es_image = f"docker.elastic.co/elasticsearch/elasticsearch:{es_version}"
            
            result = subprocess.run(
                ['docker', 'pull', es_image],
                capture_output=True, text=True, timeout=600
            )
            
            if result.returncode != 0:
                return False, f"Failed to pull Elasticsearch image: {result.stderr}"
            
            # Stop any existing Elasticsearch containers
            subprocess.run(
                ['docker', 'rm', '-f', 'elasticsearch'],
                capture_output=True, text=True
            )
            
            # Start Elasticsearch container
            docker_cmd = [
                'docker', 'run', '--name', 'elasticsearch',
                '-p', '9200:9200', '-p', '9300:9300',
                '-e', 'discovery.type=single-node',
                '-e', 'xpack.security.enabled=false',
                '-d', es_image
            ]
            
            result = subprocess.run(docker_cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                return False, f"Failed to start Elasticsearch: {result.stderr}"
            
            # Wait for Elasticsearch to be ready
            self.logger.info("Waiting for Elasticsearch to be ready...")
            for _ in range(30):  # Wait up to 30 seconds
                try:
                    response = urllib.request.urlopen('http://localhost:9200', timeout=5)
                    if response.getcode() == 200:
                        break
                except Exception:
                    time.sleep(1)
            else:
                return False, "Elasticsearch failed to start properly"
            
            return True, f"Elasticsearch {es_version} started successfully"
            
        except Exception as e:
            return False, f"Docker/Elasticsearch setup error: {str(e)}"

    def setup_redis(self) -> Tuple[bool, str]:
        """Setup Redis using Docker."""
        self.logger.info("Setting up Redis...")
        
        try:
            # Create docker-compose content for Redis
            docker_compose_content = """version: '3.8'
services:
  redis-master:
    image: redis
    container_name: redis-master
    ports:
      - "6379:6379"
  
  redis-slave:
    image: redis
    container_name: redis-slave
    depends_on:
      - redis-master
    command: ["redis-server", "--replicaof", "redis-master", "6379"]
    ports:
      - "6380:6379"
"""
            
            # Write docker-compose file
            compose_file = self.temp_dir / 'docker-compose.yml'
            with open(compose_file, 'w') as f:
                f.write(docker_compose_content)
            
            # Stop any existing Redis containers
            subprocess.run(
                ['docker', 'rm', '-f', 'redis-master', 'redis-slave'],
                capture_output=True, text=True
            )
            
            # Start Redis using docker-compose
            result = subprocess.run(
                ['docker-compose', '-f', str(compose_file), 'up', '-d'],
                capture_output=True, text=True
            )
            
            if result.returncode != 0:
                return False, f"Failed to start Redis: {result.stderr}"
            
            # Test Redis connectivity
            time.sleep(5)  # Wait for Redis to start
            test_result = subprocess.run(
                ['docker', 'exec', 'redis-master', 'redis-cli', 'ping'],
                capture_output=True, text=True
            )
            
            if test_result.returncode == 0 and 'PONG' in test_result.stdout:
                return True, "Redis master and slave started successfully"
            else:
                return False, "Redis started but connectivity test failed"
                
        except Exception as e:
            return False, f"Redis setup error: {str(e)}"

    def _download_file(self, url: str, dest_path: Path) -> None:
        """Download a file with progress tracking."""
        self.logger.info(f"Downloading {url}")
        
        try:
            with urllib.request.urlopen(url) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                
                with open(dest_path, 'wb') as f:
                    downloaded = 0
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if total_size > 0:
                            progress = (downloaded / total_size) * 100
                            print(f"\rDownloading: {progress:.1f}%", end='', flush=True)
                
                print("\n")  # Add extra spacing after progress for clarity
                
        except urllib.error.URLError as e:
            raise Exception(f"Failed to download {url}: {str(e)}")

    def _add_to_path(self, path: str) -> None:
        """Add a directory to the system PATH."""
        shell_files = [
            Path.home() / '.bashrc',
            Path.home() / '.bash_profile',
            Path.home() / '.zshrc'
        ]
        
        export_line = f'export PATH="{path}:$PATH"'
        
        for shell_file in shell_files:
            if shell_file.exists():
                # Check if path is already in file
                with open(shell_file, 'r') as f:
                    content = f.read()
                
                if path not in content:
                    with open(shell_file, 'a') as f:
                        f.write(f'\n# Added by Legion setup\n{export_line}\n')
                        
                    self.logger.info(f"Added {path} to PATH in {shell_file}")

    def verify_installation(self, software: str) -> Tuple[bool, str]:
        """Verify that software was installed correctly."""
        verification_commands = {
            'java': ['java', '-version'],
            'maven': ['mvn', '--version'],
            'node': ['node', '--version'],
            'npm': ['npm', '--version'],
            'mysql': ['mysql', '--version'],
            'docker': ['docker', '--version'],
            'yasha': ['yasha', '--version']
        }
        
        if software not in verification_commands:
            return False, f"Unknown software: {software}"
        
        try:
            result = subprocess.run(
                verification_commands[software],
                capture_output=True, text=True, timeout=30
            )
            
            if result.returncode == 0:
                version_output = result.stdout.strip() or result.stderr.strip()
                return True, f"{software} verified: {version_output}"
            else:
                return False, f"{software} verification failed: {result.stderr}"
                
        except subprocess.TimeoutExpired:
            return False, f"{software} verification timed out"
        except FileNotFoundError:
            return False, f"{software} not found in PATH"
        except Exception as e:
            return False, f"{software} verification error: {str(e)}"