#!/usr/bin/env python3
"""
Legion Setup - Validation and Verification Module
Comprehensive validation of the Legion development environment
"""

import os
import sys
import subprocess
import platform
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import json
import yaml

class EnvironmentValidator:
    def __init__(self, config: Dict, logger):
        self.config = config
        self.logger = logger
        self.platform = platform.system().lower()
        self.validation_results = {}
        
    def run_comprehensive_validation(self) -> Dict[str, Any]:
        """Run comprehensive validation of the entire environment."""
        self.logger.info("🔍 Running comprehensive environment validation...")
        
        validation_tests = [
            ("Software Versions", self._validate_software_versions),
            ("Database Connectivity", self._validate_database_connectivity),
            ("Docker Services", self._validate_docker_services),
            ("Network Connectivity", self._validate_network_connectivity),
            ("File System Permissions", self._validate_file_permissions),
            ("Environment Variables", self._validate_environment_variables),
            ("Port Availability", self._validate_port_availability),
            ("Maven Build System", self._validate_maven_build),
            ("Application Configuration", self._validate_app_configuration),
            ("IDE Integration", self._validate_ide_integration)
        ]
        
        results = {}
        overall_success = True
        
        for test_name, test_func in validation_tests:
            self.logger.info(f"Running {test_name} validation...")
            try:
                success, details = test_func()
                results[test_name] = {
                    'success': success,
                    'details': details,
                    'timestamp': time.time()
                }
                
                if success:
                    self.logger.info(f"✅ {test_name}: PASSED")
                else:
                    self.logger.error(f"❌ {test_name}: FAILED - {details.get('message', 'Unknown error')}")
                    overall_success = False
                    
            except Exception as e:
                self.logger.error(f"❌ {test_name}: ERROR - {str(e)}")
                results[test_name] = {
                    'success': False,
                    'details': {'message': f"Validation error: {str(e)}"},
                    'timestamp': time.time()
                }
                overall_success = False
        
        results['overall_success'] = overall_success
        results['validation_timestamp'] = time.time()
        
        return results

    def _validate_software_versions(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate that all required software is installed with correct versions."""
        required_software = {
            'python3': {'min_version': '3.7.0', 'command': [sys.executable, '--version']},
            'java': {'min_version': '17.0.0', 'command': ['java', '-version']},
            'maven': {'min_version': '3.6.3', 'command': ['mvn', '--version']},
            'node': {'min_version': '16.0.0', 'command': ['node', '--version']},
            'npm': {'min_version': '7.0.0', 'command': ['npm', '--version']},
            'mysql': {'min_version': '8.0.0', 'command': ['mysql', '--version']},
            'docker': {'min_version': '20.0.0', 'command': ['docker', '--version']},
            'git': {'min_version': '2.0.0', 'command': ['git', '--version']},
            'yasha': {'min_version': '1.0.0', 'command': ['yasha', '--version']}
        }
        
        results = {}
        all_passed = True
        
        for software, requirements in required_software.items():
            try:
                result = subprocess.run(
                    requirements['command'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    version_output = result.stdout or result.stderr
                    version = self._extract_version(version_output)
                    
                    # Check version requirements
                    version_ok = True
                    version_message = f"Found version: {version}"
                    
                    if 'min_version' in requirements:
                        if self._version_compare(version, requirements['min_version']) < 0:
                            version_ok = False
                            version_message = f"Version {version} is below minimum {requirements['min_version']}"
                    
                    elif 'expected_version' in requirements:
                        expected = requirements['expected_version']
                        if not version.startswith(expected.split('.')[0]):  # Major version match
                            version_ok = False
                            version_message = f"Version {version} does not match expected {expected}"
                    
                    results[software] = {
                        'installed': True,
                        'version': version,
                        'version_ok': version_ok,
                        'message': version_message
                    }
                    
                    if not version_ok:
                        all_passed = False
                else:
                    results[software] = {
                        'installed': False,
                        'version': None,
                        'version_ok': False,
                        'message': f"Command failed: {result.stderr}"
                    }
                    all_passed = False
                    
            except subprocess.TimeoutExpired:
                results[software] = {
                    'installed': False,
                    'version': None,
                    'version_ok': False,
                    'message': "Version check timed out"
                }
                all_passed = False
                
            except FileNotFoundError:
                results[software] = {
                    'installed': False,
                    'version': None,
                    'version_ok': False,
                    'message': "Software not found in PATH"
                }
                all_passed = False
        
        return all_passed, {'software_versions': results}

    def _validate_database_connectivity(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate database connectivity and setup."""
        results = {}
        all_passed = True
        
        # Test MySQL service
        mysql_running = self._test_mysql_service()
        results['mysql_service'] = mysql_running
        
        if not mysql_running['success']:
            all_passed = False
            return all_passed, results
        
        # Test database connections
        databases_to_test = ['legiondb', 'legiondb0']
        database_results = {}
        
        try:
            import mysql.connector
            from mysql.connector import Error
            
            legion_password = self.config.get('database', {}).get('legion_db_password', 'legionwork')
            
            for database in databases_to_test:
                try:
                    connection = mysql.connector.connect(
                        host='localhost',
                        user='legion',
                        password=legion_password,
                        database=database,
                        connection_timeout=10
                    )
                    
                    cursor = connection.cursor()
                    
                    # Count tables
                    cursor.execute("SHOW TABLES")
                    table_count = len(cursor.fetchall())
                    
                    # Test basic query
                    cursor.execute("SELECT 1")
                    cursor.fetchone()
                    
                    database_results[database] = {
                        'connected': True,
                        'table_count': table_count,
                        'message': f"Connected successfully, {table_count} tables found"
                    }
                    
                    cursor.close()
                    connection.close()
                    
                except Error as e:
                    database_results[database] = {
                        'connected': False,
                        'table_count': 0,
                        'message': f"Connection failed: {str(e)}"
                    }
                    all_passed = False
                    
        except ImportError:
            database_results['error'] = "mysql-connector-python not installed"
            all_passed = False
        
        results['database_connections'] = database_results
        return all_passed, results

    def _validate_docker_services(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate Docker services are running correctly."""
        results = {}
        all_passed = True
        
        # Check Docker daemon
        try:
            result = subprocess.run(
                ['docker', 'info'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            docker_running = result.returncode == 0
            results['docker_daemon'] = {
                'running': docker_running,
                'message': "Docker daemon is running" if docker_running else "Docker daemon not running"
            }
            
            if not docker_running:
                all_passed = False
                return all_passed, results
                
        except (subprocess.SubprocessError, FileNotFoundError):
            results['docker_daemon'] = {
                'running': False,
                'message': "Docker not found or not accessible"
            }
            all_passed = False
            return all_passed, results
        
        # Check required containers
        required_containers = {
            'elasticsearch': 9200,
            'redis-master': 6379,
            'redis-slave': 6380
        }
        
        container_results = {}
        
        for container, port in required_containers.items():
            # Check if container exists and is running
            container_status = self._check_docker_container(container)
            
            # Check if service is responding on expected port
            port_accessible = self._test_port_connectivity('localhost', port)
            
            container_results[container] = {
                'container_running': container_status,
                'port_accessible': port_accessible,
                'port': port,
                'message': f"Container: {'✅' if container_status else '❌'}, Port {port}: {'✅' if port_accessible else '❌'}"
            }
            
            if not (container_status and port_accessible):
                all_passed = False
        
        results['containers'] = container_results
        return all_passed, results

    def _validate_network_connectivity(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate network connectivity to required services."""
        results = {}
        all_passed = True
        
        # Test external connectivity
        external_urls = [
            'https://github.com',
            'https://maven.apache.org',
            'https://registry.npmjs.org',
            'https://hub.docker.com'
        ]
        
        external_results = {}
        for url in external_urls:
            try:
                response = urllib.request.urlopen(url, timeout=10)
                accessible = response.getcode() == 200
                external_results[url] = {
                    'accessible': accessible,
                    'status_code': response.getcode() if accessible else None,
                    'message': f"HTTP {response.getcode()}" if accessible else "Not accessible"
                }
                
                if not accessible:
                    all_passed = False
                    
            except urllib.error.URLError as e:
                external_results[url] = {
                    'accessible': False,
                    'status_code': None,
                    'message': f"Error: {str(e)}"
                }
                all_passed = False
        
        results['external_connectivity'] = external_results
        
        # Test local services
        local_services = {
            'MySQL': ('localhost', 3306),
            'Elasticsearch': ('localhost', 9200),
            'Redis Master': ('localhost', 6379),
            'Redis Slave': ('localhost', 6380)
        }
        
        local_results = {}
        for service, (host, port) in local_services.items():
            accessible = self._test_port_connectivity(host, port)
            local_results[service] = {
                'accessible': accessible,
                'host': host,
                'port': port,
                'message': f"Port {port} {'accessible' if accessible else 'not accessible'}"
            }
            
            # Don't fail for Redis slave if it's not critical
            if not accessible and service != 'Redis Slave':
                all_passed = False
        
        results['local_services'] = local_results
        return all_passed, results

    def _validate_file_permissions(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate file system permissions for required directories."""
        results = {}
        all_passed = True
        
        # Check critical directories
        directories_to_check = [
            str(Path.home()),
            str(Path.home() / '.m2'),
            '/usr/local',
            '/tmp',
            str(Path.home() / 'work')
        ]
        
        permission_results = {}
        
        for directory in directories_to_check:
            if os.path.exists(directory):
                readable = os.access(directory, os.R_OK)
                writable = os.access(directory, os.W_OK)
                executable = os.access(directory, os.X_OK)
                
                permission_results[directory] = {
                    'exists': True,
                    'readable': readable,
                    'writable': writable,
                    'executable': executable,
                    'message': f"R:{'✅' if readable else '❌'} W:{'✅' if writable else '❌'} X:{'✅' if executable else '❌'}"
                }
                
                # Check if we have necessary permissions
                if not (readable and writable and executable):
                    all_passed = False
            else:
                permission_results[directory] = {
                    'exists': False,
                    'readable': False,
                    'writable': False,
                    'executable': False,
                    'message': "Directory does not exist"
                }
                
                # /usr/local might not exist on some systems, that's okay
                if directory != '/usr/local':
                    all_passed = False
        
        results['directory_permissions'] = permission_results
        
        # Check important files
        important_files = []
        
        maven_settings = Path.home() / '.m2' / 'settings.xml'
        if maven_settings.exists():
            important_files.append(str(maven_settings))
        
        file_results = {}
        for file_path in important_files:
            if os.path.exists(file_path):
                readable = os.access(file_path, os.R_OK)
                file_results[file_path] = {
                    'exists': True,
                    'readable': readable,
                    'message': f"Readable: {'✅' if readable else '❌'}"
                }
                
                if not readable:
                    all_passed = False
            else:
                file_results[file_path] = {
                    'exists': False,
                    'readable': False,
                    'message': "File does not exist"
                }
        
        results['file_permissions'] = file_results
        return all_passed, results

    def _validate_environment_variables(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate required environment variables."""
        results = {}
        all_passed = True
        
        # Check JAVA_HOME
        java_home = os.environ.get('JAVA_HOME')
        results['JAVA_HOME'] = {
            'set': java_home is not None,
            'value': java_home,
            'valid': False,
            'message': ''
        }
        
        if java_home:
            java_bin = Path(java_home) / 'bin' / 'java'
            if java_bin.exists():
                results['JAVA_HOME']['valid'] = True
                results['JAVA_HOME']['message'] = f"Valid Java installation at {java_home}"
            else:
                results['JAVA_HOME']['message'] = f"JAVA_HOME set but invalid: {java_home}"
                all_passed = False
        else:
            # Check if Java is in PATH
            if self._command_exists('java'):
                results['JAVA_HOME']['message'] = "JAVA_HOME not set but Java found in PATH"
                results['JAVA_HOME']['valid'] = True
            else:
                results['JAVA_HOME']['message'] = "JAVA_HOME not set and Java not found in PATH"
                all_passed = False
        
        # Check PATH contains required tools
        path_dirs = os.environ.get('PATH', '').split(os.pathsep)
        required_tools = ['java', 'mvn', 'node', 'npm', 'mysql', 'docker']
        
        path_results = {}
        for tool in required_tools:
            found_in_path = self._command_exists(tool)
            path_results[tool] = {
                'in_path': found_in_path,
                'message': f"{'Found' if found_in_path else 'Not found'} in PATH"
            }
            
            if not found_in_path:
                all_passed = False
        
        results['PATH_tools'] = path_results
        
        # Check Maven-specific environment
        m2_home = os.environ.get('M2_HOME') or os.environ.get('MAVEN_HOME')
        results['MAVEN_HOME'] = {
            'set': m2_home is not None,
            'value': m2_home,
            'message': f"Maven home: {m2_home}" if m2_home else "Maven home not set (may use system install)"
        }
        
        return all_passed, results

    def _validate_port_availability(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate that required ports are available or properly used."""
        results = {}
        all_passed = True
        
        # Ports that should be available (not in use by other services)
        available_ports = [8080]  # Spring Boot default port
        
        # Ports that should be in use (by our services)
        required_ports = {
            3306: 'MySQL',
            9200: 'Elasticsearch',
            6379: 'Redis Master',
            6380: 'Redis Slave'
        }
        
        port_results = {}
        
        # Check available ports
        for port in available_ports:
            in_use = self._is_port_in_use(port)
            port_results[port] = {
                'port': port,
                'should_be_free': True,
                'is_free': not in_use,
                'status': 'Available' if not in_use else 'In use by other service',
                'message': f"Port {port} is {'free' if not in_use else 'occupied'}"
            }
            
            if in_use:
                all_passed = False
        
        # Check required ports
        for port, service in required_ports.items():
            in_use = self._is_port_in_use(port)
            port_results[port] = {
                'port': port,
                'should_be_free': False,
                'service': service,
                'is_running': in_use,
                'status': f'{service} running' if in_use else f'{service} not running',
                'message': f"Port {port} ({service}) is {'active' if in_use else 'inactive'}"
            }
            
            # Redis slave is optional
            if not in_use and service != 'Redis Slave':
                all_passed = False
        
        results['port_status'] = port_results
        return all_passed, results

    def _validate_maven_build(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate Maven build system configuration."""
        results = {}
        all_passed = True
        
        # Check Maven settings
        settings_file = Path.home() / '.m2' / 'settings.xml'
        results['settings_xml'] = {
            'exists': settings_file.exists(),
            'path': str(settings_file),
            'message': f"Maven settings {'found' if settings_file.exists() else 'missing'}"
        }
        
        if not settings_file.exists():
            all_passed = False
        
        # Check enterprise project
        enterprise_path = Path.home() / 'work' / 'enterprise'
        results['enterprise_project'] = {
            'exists': enterprise_path.exists(),
            'path': str(enterprise_path),
            'message': f"Enterprise project {'found' if enterprise_path.exists() else 'missing'}"
        }
        
        if enterprise_path.exists():
            # Check for pom.xml
            pom_file = enterprise_path / 'pom.xml'
            results['pom_xml'] = {
                'exists': pom_file.exists(),
                'path': str(pom_file),
                'message': f"Maven POM {'found' if pom_file.exists() else 'missing'}"
            }
            
            if not pom_file.exists():
                all_passed = False
        else:
            all_passed = False
        
        return all_passed, results

    def _validate_app_configuration(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate application configuration files."""
        results = {}
        all_passed = True
        
        enterprise_path = Path.home() / 'work' / 'enterprise'
        
        if not enterprise_path.exists():
            results['error'] = "Enterprise project not found"
            return False, results
        
        # Check configuration files
        config_files = [
            'config/target/resources/local/application.yml',
            'config/src/main/resources/templates/local/local.values.yml'
        ]
        
        config_results = {}
        
        for config_file in config_files:
            file_path = enterprise_path / config_file
            config_results[config_file] = {
                'exists': file_path.exists(),
                'path': str(file_path),
                'message': f"Configuration {'found' if file_path.exists() else 'missing'}"
            }
            
            if not file_path.exists() and 'target' not in config_file:
                # Only fail for source files, not generated target files
                all_passed = False
        
        results['configuration_files'] = config_results
        return all_passed, results

    def _validate_ide_integration(self) -> Tuple[bool, Dict[str, Any]]:
        """Validate IDE integration setup."""
        results = {}
        all_passed = True
        
        # Check if IntelliJ setup was requested
        skip_intellij = self.config.get('setup_options', {}).get('skip_intellij_setup', False)
        
        if skip_intellij:
            results['status'] = 'skipped'
            results['message'] = 'IntelliJ setup was skipped per configuration'
            return True, results
        
        # Check for IntelliJ installation
        intellij_paths = [
            '/Applications/IntelliJ IDEA CE.app',
            '/Applications/IntelliJ IDEA.app',
            Path.home() / 'Applications' / 'IntelliJ IDEA CE.app',
            Path.home() / 'Applications' / 'IntelliJ IDEA.app'
        ]
        
        intellij_found = any(Path(path).exists() for path in intellij_paths)
        
        results['intellij_installed'] = {
            'found': intellij_found,
            'message': f"IntelliJ IDEA {'found' if intellij_found else 'not found'}"
        }
        
        if not intellij_found:
            # Not a critical failure since IDE can be installed separately
            results['warning'] = "IntelliJ IDEA not detected. Manual installation may be required."
        
        return all_passed, results

    # Helper methods
    
    def _extract_version(self, version_output: str) -> str:
        """Extract version number from command output."""
        import re
        
        # Common version patterns
        patterns = [
            r'(\d+\.\d+\.\d+)',
            r'version "(\d+\.\d+\.\d+)',
            r'v(\d+\.\d+\.\d+)',
            r'(\d+\.\d+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, version_output)
            if match:
                return match.group(1)
        
        return version_output.strip()

    def _version_compare(self, version1: str, version2: str) -> int:
        """Compare two version strings."""
        def normalize(v):
            return [int(x) for x in v.split('.')]
        
        try:
            v1_parts = normalize(version1)
            v2_parts = normalize(version2)
            
            max_len = max(len(v1_parts), len(v2_parts))
            v1_parts.extend([0] * (max_len - len(v1_parts)))
            v2_parts.extend([0] * (max_len - len(v2_parts)))
            
            if v1_parts < v2_parts:
                return -1
            elif v1_parts > v2_parts:
                return 1
            else:
                return 0
        except ValueError:
            # Fallback to string comparison if version format is unusual
            if version1 < version2:
                return -1
            elif version1 > version2:
                return 1
            else:
                return 0

    def _test_mysql_service(self) -> Dict[str, Any]:
        """Test MySQL service status."""
        try:
            # Try to connect to MySQL
            result = subprocess.run(
                ['mysql', '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                # Try actual connection test
                test_result = subprocess.run(
                    ['mysql', '-u', 'root', '--execute', 'SELECT 1'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                return {
                    'success': test_result.returncode == 0,
                    'version_check': True,
                    'connection_test': test_result.returncode == 0,
                    'message': 'MySQL service is running' if test_result.returncode == 0 else 'MySQL installed but connection failed'
                }
            else:
                return {
                    'success': False,
                    'version_check': False,
                    'connection_test': False,
                    'message': 'MySQL not found or not accessible'
                }
                
        except (subprocess.SubprocessError, FileNotFoundError):
            return {
                'success': False,
                'version_check': False,
                'connection_test': False,
                'message': 'MySQL not found'
            }

    def _check_docker_container(self, container_name: str) -> bool:
        """Check if a Docker container is running."""
        try:
            result = subprocess.run(
                ['docker', 'ps', '--filter', f'name={container_name}', '--format', '{{.Names}}'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            return container_name in result.stdout
            
        except (subprocess.SubprocessError, FileNotFoundError):
            return False

    def _test_port_connectivity(self, host: str, port: int) -> bool:
        """Test if a port is accessible."""
        import socket
        
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(5)
                result = s.connect_ex((host, port))
                return result == 0
        except Exception:
            return False

    def _is_port_in_use(self, port: int) -> bool:
        """Check if a port is in use."""
        return self._test_port_connectivity('localhost', port)

    def _command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH."""
        import shutil
        return shutil.which(command) is not None

    def generate_validation_report(self, results: Dict[str, Any]) -> str:
        """Generate a human-readable validation report."""
        report = []
        report.append("╔══════════════════════════════════════════════════════════════╗")
        report.append("║              ENVIRONMENT VALIDATION REPORT                  ║")
        report.append("╚══════════════════════════════════════════════════════════════╝")
        report.append("")
        
        overall_status = "✅ PASSED" if results.get('overall_success', False) else "❌ FAILED"
        report.append(f"Overall Status: {overall_status}")
        report.append(f"Validation Time: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(results.get('validation_timestamp', time.time())))}")
        report.append("")
        
        for test_name, test_result in results.items():
            if test_name in ['overall_success', 'validation_timestamp']:
                continue
                
            status = "✅ PASS" if test_result.get('success', False) else "❌ FAIL"
            report.append(f"{test_name}: {status}")
            
            if 'details' in test_result and test_result['details']:
                for key, value in test_result['details'].items():
                    if isinstance(value, dict):
                        report.append(f"  {key}:")
                        for subkey, subvalue in value.items():
                            if isinstance(subvalue, dict):
                                status_icon = "✅" if subvalue.get('success', subvalue.get('accessible', subvalue.get('connected', False))) else "❌"
                                message = subvalue.get('message', str(subvalue))
                                report.append(f"    {status_icon} {subkey}: {message}")
                            else:
                                report.append(f"    - {subkey}: {subvalue}")
                    else:
                        report.append(f"  {key}: {value}")
            
            report.append("")
        
        return "\n".join(report)

    def save_validation_report(self, results: Dict[str, Any], file_path: Optional[Path] = None) -> Path:
        """Save validation results to file."""
        if file_path is None:
            file_path = Path.home() / '.legion_setup' / 'logs' / f'validation_report_{int(time.time())}.txt'
        
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Generate text report
        text_report = self.generate_validation_report(results)
        
        with open(file_path, 'w') as f:
            f.write(text_report)
        
        # Also save JSON version for programmatic access
        json_path = file_path.with_suffix('.json')
        with open(json_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        return file_path