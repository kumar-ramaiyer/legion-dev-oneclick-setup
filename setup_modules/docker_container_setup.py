#!/usr/bin/env python3
"""
Legion Setup - Docker and Container Services Module
===================================================

This module manages Docker Desktop installation and container orchestration for Legion:
- Docker Desktop installation and resource configuration
- Elasticsearch container for search and analytics
- Redis master/slave for distributed locking
- LocalStack for AWS service emulation
- Container health verification

Key Features:
- Cross-platform Docker installation (macOS/Linux)
- Automatic resource allocation based on system specs
- Docker Compose orchestration for multi-container setups
- Health checks and retry logic for container startup
- Configuration file updates for service integration

Container Architecture:
- Elasticsearch: Single-node cluster on port 9200
- Redis Master: Primary instance on port 6379
- Redis Slave: Replica instance on port 6380
- LocalStack: AWS services on port 4566

Author: Legion DevOps Team
Version: 1.0.0
"""

import os
import sys
import subprocess
import platform
import time
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import tempfile
import shutil

class DockerContainerSetup:
    """
    Manages Docker Desktop and container services for Legion development.
    
    This class handles the complete lifecycle of Docker and containerized services:
    - Installation and configuration of Docker Desktop
    - Container network creation and management
    - Service orchestration with health checks
    - Configuration file updates for service endpoints
    
    Attributes:
        config: Main configuration dictionary
        logger: Logger instance for output
        platform: Current OS platform (darwin/linux/windows)
        docker_config: Docker-specific configuration
        elasticsearch_config: Elasticsearch settings
        docker_memory: Allocated RAM in GB for Docker
        docker_cpus: Number of CPUs for Docker
        docker_swap: Swap memory in GB
        es_modifier: Elasticsearch index name modifier
    """
    
    def __init__(self, config: Dict, logger):
        """
        Initialize Docker container setup handler.
        
        Args:
            config: Configuration dictionary with Docker and service settings
            logger: Logger instance for output and debugging
        """
        self.config = config
        self.logger = logger
        self.platform = platform.system().lower()
        self.docker_config = config.get('docker', {})
        self.elasticsearch_config = config.get('database', {})
        
        # Docker settings from config
        self.docker_memory = self.docker_config.get('memory_gb', 4.0)
        self.docker_cpus = self.docker_config.get('cpus', 4)
        self.docker_swap = self.docker_config.get('swap_gb', 1.0)
        
        # Elasticsearch settings
        self.es_modifier = self.elasticsearch_config.get('elasticsearch_index_modifier', 'developer')
        
    def setup_docker_desktop(self) -> Tuple[bool, str]:
        """
        Install and configure Docker Desktop with optimal resources.
        
        Process:
        1. Check if Docker is already installed
        2. Install Docker Desktop via Homebrew (macOS) or script (Linux)
        3. Configure resource limits (CPU, memory, swap)
        4. Start Docker Desktop and wait for readiness
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        self.logger.info("Setting up Docker Desktop...")
        
        try:
            # Check if Docker is already installed
            if self._check_docker_installed():
                self.logger.info("Docker Desktop already installed")
                return self._configure_docker_resources()
            
            # Install Docker Desktop based on platform
            if self.platform == 'darwin':
                return self._install_docker_macos()
            elif self.platform == 'linux':
                return self._install_docker_linux()
            else:
                return False, f"Docker installation not supported on {self.platform}"
                
        except Exception as e:
            return False, f"Docker setup error: {str(e)}"
    
    def _check_docker_installed(self) -> bool:
        """
        Check if Docker is installed and accessible.
        
        Verifies Docker installation by running 'docker --version'.
        
        Returns:
            bool: True if Docker is installed and accessible, False otherwise
        """
        try:
            result = subprocess.run(['docker', '--version'], 
                                  capture_output=True, text=True)
            return result.returncode == 0
        except FileNotFoundError:
            return False
    
    def _install_docker_macos(self) -> Tuple[bool, str]:
        """
        Install Docker Desktop on macOS using Homebrew.
        
        Process:
        1. Install Docker Desktop cask via Homebrew
        2. Launch Docker Desktop application
        3. Wait for Docker daemon to be ready (up to 60 seconds)
        4. Configure resource limits
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        try:
            print("""
╔══════════════════════════════════════════════════════════════╗
║                   DOCKER DESKTOP SETUP                      ║
╚══════════════════════════════════════════════════════════════╝

Docker Desktop needs to be installed for container services.

Installing Docker Desktop via Homebrew...
""")
            
            # Try to install via Homebrew
            result = subprocess.run(['brew', 'install', '--cask', 'docker'],
                                  capture_output=True, text=True, timeout=600)
            
            if result.returncode == 0:
                self.logger.info("Docker Desktop installed via Homebrew")
                
                # Start Docker Desktop
                subprocess.run(['open', '-a', 'Docker'], capture_output=True)
                
                # Wait for Docker to start
                print("Waiting for Docker Desktop to start...")
                for i in range(30):
                    if self._check_docker_installed():
                        break
                    time.sleep(2)
                
                return self._configure_docker_resources()
            else:
                return False, "Failed to install Docker Desktop via Homebrew"
                
        except Exception as e:
            return False, f"Docker installation error: {str(e)}"
    
    def _install_docker_linux(self) -> Tuple[bool, str]:
        """
        Install Docker Engine on Linux systems.
        
        Uses the official Docker installation script from get.docker.com.
        Adds the current user to the docker group for non-root access.
        
        Note: User needs to log out and back in for group changes to take effect.
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        try:
            # Install Docker Engine
            install_script = """
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
            """
            
            subprocess.run(install_script, shell=True, check=True)
            return True, "Docker Engine installed on Linux"
            
        except Exception as e:
            return False, f"Docker installation error: {str(e)}"
    
    def _configure_docker_resources(self) -> Tuple[bool, str]:
        """
        Configure Docker Desktop resource limits.
        
        Updates Docker Desktop settings.json with:
        - CPU count allocation
        - Memory limit in MiB
        - Swap memory limit in MiB
        
        Restarts Docker Desktop to apply changes on macOS.
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        try:
            # Docker Desktop settings location varies by platform
            if self.platform == 'darwin':
                settings_path = Path.home() / 'Library/Group Containers/group.com.docker/settings.json'
            else:
                settings_path = Path.home() / '.docker/desktop/settings.json'
            
            if settings_path.exists():
                # Read current settings
                with open(settings_path, 'r') as f:
                    settings = json.load(f)
                
                # Update resources
                settings['cpus'] = self.docker_cpus
                settings['memoryMiB'] = int(self.docker_memory * 1024)
                settings['swapMiB'] = int(self.docker_swap * 1024)
                
                # Write updated settings
                with open(settings_path, 'w') as f:
                    json.dump(settings, f, indent=2)
                
                self.logger.info(f"Docker configured: {self.docker_cpus} CPUs, {self.docker_memory}GB RAM, {self.docker_swap}GB swap")
                
                # Restart Docker to apply settings
                if self.platform == 'darwin':
                    subprocess.run(['osascript', '-e', 'quit app "Docker"'], capture_output=True)
                    time.sleep(2)
                    subprocess.run(['open', '-a', 'Docker'], capture_output=True)
                
                return True, "Docker Desktop configured successfully"
            else:
                self.logger.warning("Docker settings file not found, using defaults")
                return True, "Docker Desktop installed (manual configuration needed)"
                
        except Exception as e:
            self.logger.warning(f"Could not configure Docker resources: {str(e)}")
            return True, "Docker installed (manual configuration recommended)"
    
    def setup_elasticsearch(self) -> Tuple[bool, str]:
        """
        Setup and start Elasticsearch container for Legion.
        
        Configuration:
        - Version: 8.0.0
        - Mode: Single-node cluster
        - Security: Disabled for local development
        - Network: elastic (Docker network)
        - Ports: 9200 (HTTP), 9300 (transport)
        
        Process:
        1. Create elastic Docker network
        2. Pull Elasticsearch image
        3. Stop any existing container
        4. Start new container with configuration
        5. Wait for cluster health check
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        self.logger.info("Setting up Elasticsearch...")
        
        try:
            # Create elastic network
            subprocess.run(['docker', 'network', 'create', 'elastic'],
                         capture_output=True, text=True)
            
            # Pull Elasticsearch image
            print("📥 Pulling Elasticsearch 8.0.0 image...")
            pull_result = subprocess.run(
                ['docker', 'pull', 'docker.elastic.co/elasticsearch/elasticsearch:8.0.0'],
                capture_output=True, text=True
            )
            
            if pull_result.returncode != 0 and 'already exists' not in pull_result.stderr:
                return False, f"Failed to pull Elasticsearch image: {pull_result.stderr}"
            
            # Stop any existing Elasticsearch container
            subprocess.run(['docker', 'rm', '-f', 'elasticsearch'],
                         capture_output=True, text=True)
            
            # Run Elasticsearch container
            print("🚀 Starting Elasticsearch container...")
            run_command = [
                'docker', 'run', '-d',
                '--name', 'elasticsearch',
                '--network', 'elastic',
                '-p', '9200:9200',
                '-p', '9300:9300',
                '-e', 'discovery.type=single-node',
                '-e', 'xpack.security.enabled=false',
                'docker.elastic.co/elasticsearch/elasticsearch:8.0.0'
            ]
            
            run_result = subprocess.run(run_command, capture_output=True, text=True)
            
            if run_result.returncode != 0:
                return False, f"Failed to start Elasticsearch: {run_result.stderr}"
            
            # Wait for Elasticsearch to be ready
            print("⏳ Waiting for Elasticsearch to be ready...")
            for i in range(30):
                try:
                    import requests
                    response = requests.get('http://localhost:9200/_cluster/health', timeout=2)
                    if response.status_code == 200:
                        self.logger.info("✅ Elasticsearch is running")
                        break
                except:
                    time.sleep(2)
            
            # Verify Elasticsearch is running
            verify_result = subprocess.run(
                ['curl', '-X', 'GET', 'http://localhost:9200/_aliases?pretty=true'],
                capture_output=True, text=True
            )
            
            if verify_result.returncode == 0:
                return True, "Elasticsearch container running successfully"
            else:
                return False, "Elasticsearch container started but not responding"
                
        except Exception as e:
            return False, f"Elasticsearch setup error: {str(e)}"
    
    def setup_redis(self) -> Tuple[bool, str]:
        """
        Setup Redis master-slave containers for distributed locking.
        
        Architecture:
        - Redis Master: Primary instance on port 6379
        - Redis Slave: Replica of master on port 6380
        - Replication: Automatic from slave to master
        
        Uses Docker Compose for orchestration.
        Creates persistent configuration in ~/.legion_setup/docker/.
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        self.logger.info("Setting up Redis for locking...")
        
        try:
            # Create docker-compose file for Redis
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
            
            # Save docker-compose file
            compose_dir = Path.home() / '.legion_setup' / 'docker'
            compose_dir.mkdir(parents=True, exist_ok=True)
            compose_file = compose_dir / 'redis-docker-compose.yml'
            
            with open(compose_file, 'w') as f:
                f.write(docker_compose_content)
            
            # Stop any existing Redis containers
            subprocess.run(['docker', 'rm', '-f', 'redis-master', 'redis-slave'],
                         capture_output=True, text=True)
            
            # Start Redis containers
            print("🚀 Starting Redis containers...")
            compose_result = subprocess.run(
                ['docker-compose', '-f', str(compose_file), 'up', '-d'],
                capture_output=True, text=True
            )
            
            if compose_result.returncode != 0:
                # Try with docker compose (newer syntax)
                compose_result = subprocess.run(
                    ['docker', 'compose', '-f', str(compose_file), 'up', '-d'],
                    capture_output=True, text=True
                )
            
            if compose_result.returncode != 0:
                return False, f"Failed to start Redis containers: {compose_result.stderr}"
            
            # Wait for Redis to be ready
            print("⏳ Waiting for Redis to be ready...")
            time.sleep(5)
            
            # Test Redis connectivity
            test_result = subprocess.run(
                ['nc', '-zv', 'localhost', '6379'],
                capture_output=True, text=True, timeout=5
            )
            
            if test_result.returncode == 0 or 'succeeded' in test_result.stderr.lower():
                self.logger.info("✅ Redis is running on ports 6379 (master) and 6380 (slave)")
                return True, "Redis containers running successfully"
            else:
                self.logger.warning("Redis started but connectivity test failed")
                return True, "Redis containers started (manual verification needed)"
                
        except Exception as e:
            return False, f"Redis setup error: {str(e)}"
    
    def setup_localstack(self) -> Tuple[bool, str]:
        """
        Setup LocalStack for local AWS service emulation.
        
        LocalStack provides local implementations of AWS services:
        - S3 for object storage
        - SQS for message queuing
        - Lambda for serverless functions
        - DynamoDB for NoSQL database
        
        Installation via Homebrew (macOS) or pip (Linux).
        Runs as Docker container on port 4566.
        
        Note: This is an optional component.
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        self.logger.info("Setting up LocalStack...")
        
        try:
            # Install LocalStack CLI
            if self.platform == 'darwin':
                brew_result = subprocess.run(
                    ['brew', 'install', 'localstack'],
                    capture_output=True, text=True
                )
                
                if brew_result.returncode != 0:
                    # Try pip install
                    pip_result = subprocess.run(
                        [sys.executable, '-m', 'pip', 'install', 'localstack'],
                        capture_output=True, text=True
                    )
                    
                    if pip_result.returncode != 0:
                        return False, "Failed to install LocalStack"
            else:
                # Install via pip on Linux
                pip_result = subprocess.run(
                    [sys.executable, '-m', 'pip', 'install', 'localstack'],
                    capture_output=True, text=True
                )
                
                if pip_result.returncode != 0:
                    return False, "Failed to install LocalStack"
            
            # Pull LocalStack Docker image
            print("📥 Pulling LocalStack image...")
            pull_result = subprocess.run(
                ['docker', 'pull', 'localstack/localstack'],
                capture_output=True, text=True
            )
            
            # Start LocalStack
            print("🚀 Starting LocalStack...")
            start_result = subprocess.run(
                ['localstack', 'start', '-d'],
                capture_output=True, text=True, timeout=60
            )
            
            if start_result.returncode == 0:
                self.logger.info("✅ LocalStack is running")
                return True, "LocalStack started successfully"
            else:
                self.logger.warning("LocalStack may not have started properly")
                return True, "LocalStack installed (manual start may be needed)"
                
        except Exception as e:
            self.logger.warning(f"LocalStack setup warning: {str(e)}")
            return True, "LocalStack setup skipped (optional component)"
    
    def configure_elasticsearch_yaml(self) -> Tuple[bool, str]:
        """
        Configure Elasticsearch and Redis settings in local.values.yml.
        
        Updates enterprise repository's local.values.yml with:
        - Elasticsearch host configuration (localhost:9200)
        - Elasticsearch index modifier (e.g., 'developer')
        - Redis master/slave endpoints for locking
        - AWS Elasticsearch VPC settings (empty for local)
        
        Creates the file if it doesn't exist.
        Preserves existing non-conflicting settings.
        
        Returns:
            Tuple[bool, str]: (Success status, descriptive message)
        """
        self.logger.info("Configuring Elasticsearch settings...")
        
        try:
            # Find enterprise repository path
            from .config_resolver import ConfigResolver
            resolver = ConfigResolver(self.config)
            resolved_config = resolver.resolve_variables()
            
            enterprise_path = Path(resolved_config.get('repositories', {}).get('enterprise', {}).get('path', 
                '~/Development/legion/code/enterprise')).expanduser()
            
            if not enterprise_path.exists():
                return False, "Enterprise repository not found"
            
            # Path to local.values.yml
            values_file = enterprise_path / 'src' / 'main' / 'resources' / 'local.values.yml'
            
            if not values_file.exists():
                self.logger.warning("local.values.yml not found, will be created during build")
                return True, "Elasticsearch configuration will be set during build"
            
            # Read current values
            import yaml
            with open(values_file, 'r') as f:
                values = yaml.safe_load(f) or {}
            
            # Update Elasticsearch configuration
            values['elasticsearch_index_modifier'] = self.es_modifier
            
            # Local Elasticsearch settings
            values['elasticsearch_host'] = {
                'host': 'localhost',
                'port': 9200,
                'protocol_scheme': 'http',
                'aws_elasticsearch_vpc_region': '',
                'aws_elasticsearch_vpc_access_key_id': '',
                'aws_elasticsearch_vpc_secret_access_key': '',
                'aws_elasticsearch_vpc_secret_access_key_secure': ''
            }
            
            # Redis configuration for locking
            values['redis'] = {
                'master': {
                    'host': 'localhost',
                    'port': 6379
                },
                'slave': {
                    'host': 'localhost',
                    'port': 6380
                }
            }
            
            # Write updated values
            with open(values_file, 'w') as f:
                yaml.dump(values, f, default_flow_style=False, sort_keys=False)
            
            self.logger.info(f"✅ Configured Elasticsearch with modifier: {self.es_modifier}")
            return True, "Elasticsearch and Redis configured in local.values.yml"
            
        except Exception as e:
            self.logger.warning(f"Configuration update warning: {str(e)}")
            return True, "Manual configuration of local.values.yml may be needed"
    
    def verify_containers(self) -> Tuple[bool, Dict]:
        """
        Verify status of all container services.
        
        Performs health checks on:
        - Docker: Daemon accessibility
        - Elasticsearch: Cluster health endpoint
        - Redis: TCP connectivity on port 6379
        - LocalStack: Health check endpoint
        
        Critical services: Docker, Elasticsearch, Redis
        Optional services: LocalStack
        
        Returns:
            Tuple[bool, Dict]: (All critical services running, 
                               service_name -> status dictionary)
        """
        self.logger.info("Verifying container services...")
        
        results = {}
        
        # Check Docker
        try:
            docker_result = subprocess.run(['docker', 'ps'], 
                                         capture_output=True, text=True)
            results['docker'] = docker_result.returncode == 0
        except:
            results['docker'] = False
        
        # Check Elasticsearch
        try:
            es_result = subprocess.run(
                ['curl', '-s', 'http://localhost:9200/_cluster/health'],
                capture_output=True, text=True, timeout=5
            )
            results['elasticsearch'] = es_result.returncode == 0 and 'status' in es_result.stdout
        except:
            results['elasticsearch'] = False
        
        # Check Redis
        try:
            redis_result = subprocess.run(
                ['nc', '-zv', 'localhost', '6379'],
                capture_output=True, text=True, timeout=5
            )
            results['redis'] = redis_result.returncode == 0 or 'succeeded' in redis_result.stderr.lower()
        except:
            results['redis'] = False
        
        # Check LocalStack
        try:
            ls_result = subprocess.run(
                ['curl', '-s', 'http://localhost:4566/_localstack/health'],
                capture_output=True, text=True, timeout=5
            )
            results['localstack'] = 'running' in ls_result.stdout.lower()
        except:
            results['localstack'] = False
        
        all_critical_running = results['docker'] and results['elasticsearch'] and results['redis']
        
        return all_critical_running, results