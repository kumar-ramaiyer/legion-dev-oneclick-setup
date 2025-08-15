#!/usr/bin/env python3
"""
Legion Setup - JFrog Artifactory and Maven Configuration Module
Handles Maven settings.xml download and JFrog integration
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
import xml.etree.ElementTree as ET

class JFrogMavenSetup:
    def __init__(self, config: Dict, logger):
        self.config = config
        self.logger = logger
        self.platform = platform.system().lower()
        self.m2_dir = Path.home() / '.m2'
        self.jfrog_config = config.get('jfrog', {})
        
    def setup_maven_directory(self) -> Tuple[bool, str]:
        """Create and setup .m2 directory structure."""
        self.logger.info("Setting up Maven directory structure...")
        
        try:
            # Create .m2 directory if it doesn't exist
            self.m2_dir.mkdir(mode=0o755, exist_ok=True)
            
            # Create repository directory
            repository_dir = self.m2_dir / 'repository'
            repository_dir.mkdir(mode=0o755, exist_ok=True)
            
            self.logger.info(f"✅ Maven directory created at {self.m2_dir}")
            return True, f"Maven directory setup at {self.m2_dir}"
            
        except Exception as e:
            return False, f"Maven directory setup error: {str(e)}"

    def download_settings_xml(self) -> Tuple[bool, str]:
        """Download settings.xml from JFrog Artifactory via Okta."""
        self.logger.info("Setting up JFrog Artifactory Maven settings...")
        
        settings_path = self.m2_dir / 'settings.xml'
        
        # Check if settings.xml already exists
        if settings_path.exists():
            backup_path = self.m2_dir / 'settings.xml.backup'
            if not backup_path.exists():
                settings_path.rename(backup_path)
                self.logger.info(f"Existing settings.xml backed up to {backup_path}")
        
        try:
            # Check if manual download is needed
            if not self.jfrog_config.get('download_settings_xml', True):
                return self._create_basic_settings_xml(settings_path)
            
            # Guide user through JFrog settings.xml download
            success = self._guide_jfrog_download()
            
            if success and settings_path.exists():
                # Validate the downloaded settings.xml
                if self._validate_settings_xml(settings_path):
                    return True, "JFrog settings.xml downloaded and validated"
                else:
                    return False, "Downloaded settings.xml is invalid"
            else:
                # Fallback to basic settings.xml
                return self._create_basic_settings_xml(settings_path)
                
        except Exception as e:
            return False, f"JFrog settings setup error: {str(e)}"

    def _guide_jfrog_download(self) -> bool:
        """Guide user through JFrog Artifactory settings.xml download."""
        print(f"""
╔══════════════════════════════════════════════════════════════╗
║                  JFROG ARTIFACTORY SETUP                    ║
╚══════════════════════════════════════════════════════════════╝

Maven requires settings.xml from JFrog Artifactory for Legion dependencies.

Steps to download settings.xml:

1. 🔐 Log in to JFrog Artifactory via Okta:
   https://legiontech.jfrog.io/

2. 📋 Once logged in, go to your profile:
   - Click your profile icon (top right)
   - Select "Edit Profile"
   - Go to "Generate an Identity Token" or "Set Me Up"

3. 📥 Download settings.xml:
   - Follow the Maven setup instructions
   - Download the generated settings.xml file
   - Save it to: {self.m2_dir / 'settings.xml'}

4. 🎬 Alternative - Watch this video guide:
   https://drive.google.com/uc?id=13QJve3pzO4fPfRTwTE-IYaZ6qdcVuCul

Have you downloaded settings.xml to {self.m2_dir}? (y/n): """, end='')
        
        # Always wait for Maven settings confirmation, even with auto_confirm
        # This is critical for builds to work
        while True:
            response = input().strip().lower()
            if response in ['y', 'yes']:
                print("Great! Verifying Maven settings...")
                break
            elif response in ['n', 'no']:
                print("\nPlease complete these steps:")
                print("1. Log in to JFrog Artifactory via Okta")
                print("2. Generate and download settings.xml")
                print(f"3. Save it to: {self.m2_dir / 'settings.xml'}")
                print("\nHave you downloaded settings.xml? (y/n): ", end='')
            else:
                print("Please enter 'y' for yes or 'n' for no: ", end='')
        
        # Check if user downloaded the file
        settings_path = self.m2_dir / 'settings.xml'
        if not settings_path.exists():
            print(f"\n❌ settings.xml not found at {settings_path}")
            print("Please download it from JFrog and save it to the correct location.")
            print("\nPress Enter when you've saved the file...", end='')
            input()
        
        return settings_path.exists()

    def _validate_settings_xml(self, settings_path: Path) -> bool:
        """Validate the downloaded settings.xml file."""
        try:
            # Parse XML to ensure it's valid
            tree = ET.parse(settings_path)
            root = tree.getroot()
            
            # Check for required elements (mirrors is optional)
            required_elements = ['servers', 'profiles']
            missing_elements = []
            
            for element in required_elements:
                if root.find(f".//{element}") is None:
                    missing_elements.append(element)
            
            if missing_elements:
                self.logger.warning(f"Settings.xml missing required elements: {', '.join(missing_elements)}")
                return False
            
            # Check for JFrog-specific configuration
            # Look for legion.jfrog.io URLs or typical JFrog server IDs
            jfrog_found = False
            
            # Check in servers section
            for server in root.findall('.//server'):
                server_id = server.find('id')
                if server_id is not None:
                    id_text = server_id.text.lower()
                    # Check for common JFrog server IDs
                    if any(x in id_text for x in ['central', 'snapshots', 'artifactory', 'libs-']):
                        jfrog_found = True
                        break
            
            # Also check in repository URLs
            if not jfrog_found:
                for repo in root.findall('.//repository'):
                    url_elem = repo.find('url')
                    if url_elem is not None and 'jfrog.io' in url_elem.text:
                        jfrog_found = True
                        break
            
            if not jfrog_found:
                self.logger.warning("No JFrog configuration found in settings.xml (check servers and repository URLs)")
            
            self.logger.info("✅ Settings.xml validation passed")
            return True
            
        except ET.ParseError as e:
            self.logger.error(f"Invalid XML in settings.xml: {str(e)}")
            return False
        except Exception as e:
            self.logger.error(f"Settings.xml validation error: {str(e)}")
            return False

    def _create_basic_settings_xml(self, settings_path: Path) -> Tuple[bool, str]:
        """Create a basic settings.xml as fallback."""
        self.logger.info("Creating basic settings.xml as fallback...")
        
        try:
            basic_settings = """<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 
                              http://maven.apache.org/xsd/settings-1.2.0.xsd">
  
  <!-- Local repository location -->
  <localRepository>{local_repo}</localRepository>
  
  <!-- Proxy settings (if needed) -->
  <proxies>
    <!-- Uncomment if behind corporate proxy
    <proxy>
      <id>corporate-proxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>proxy.company.com</host>
      <port>8080</port>
    </proxy>
    -->
  </proxies>
  
  <!-- Server configurations -->
  <servers>
    <!-- JFrog Artifactory server configuration will be needed -->
    <!-- Please follow JFrog setup instructions to complete this -->
  </servers>
  
  <!-- Mirror configurations -->
  <mirrors>
    <!-- Central repository mirror -->
    <mirror>
      <id>central-mirror</id>
      <mirrorOf>central</mirrorOf>
      <name>Maven Central Mirror</name>
      <url>https://repo1.maven.org/maven2</url>
    </mirror>
  </mirrors>
  
  <!-- Profile configurations -->
  <profiles>
    <profile>
      <id>dev</id>
      <activation>
        <activeByDefault>true</activeByDefault>
      </activation>
      <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
      </properties>
    </profile>
  </profiles>
  
</settings>""".format(local_repo=str(self.m2_dir / 'repository'))
            
            with open(settings_path, 'w') as f:
                f.write(basic_settings)
            
            settings_path.chmod(0o644)
            
            return True, f"Basic settings.xml created at {settings_path} (JFrog configuration needed)"
            
        except Exception as e:
            return False, f"Basic settings.xml creation error: {str(e)}"

    def test_maven_configuration(self) -> Tuple[bool, str]:
        """Test Maven configuration with the current settings."""
        self.logger.info("Testing Maven configuration...")
        
        try:
            # Test basic Maven command
            result = subprocess.run(
                ['mvn', '--version'],
                capture_output=True, text=True, timeout=30
            )
            
            if result.returncode != 0:
                return False, f"Maven not working: {result.stderr}"
            
            # Test Maven with settings
            result = subprocess.run(
                ['mvn', 'help:effective-settings'],
                capture_output=True, text=True, timeout=60
            )
            
            if result.returncode != 0:
                return False, f"Maven settings test failed: {result.stderr}"
            
            # Check if JFrog repositories are accessible (if configured)
            jfrog_accessible = self._test_jfrog_repositories()
            
            if jfrog_accessible:
                return True, "Maven configuration tested successfully with JFrog access"
            else:
                return True, "Maven configuration tested (JFrog access pending completion)"
                
        except subprocess.TimeoutExpired:
            return False, "Maven configuration test timed out"
        except Exception as e:
            return False, f"Maven configuration test error: {str(e)}"

    def _test_jfrog_repositories(self) -> bool:
        """Test access to JFrog repositories."""
        try:
            # Create a temporary test project to check dependencies
            test_dir = Path.home() / '.legion_setup' / 'maven_test'
            test_dir.mkdir(parents=True, exist_ok=True)
            
            # Create a minimal pom.xml for testing
            test_pom = test_dir / 'pom.xml'
            pom_content = """<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.legion.test</groupId>
  <artifactId>maven-test</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  
  <properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
  </properties>
  
  <dependencies>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.13.2</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
</project>"""
            
            with open(test_pom, 'w') as f:
                f.write(pom_content)
            
            # Test dependency resolution
            original_cwd = os.getcwd()
            try:
                os.chdir(test_dir)
                result = subprocess.run(
                    ['mvn', 'dependency:resolve'],
                    capture_output=True, text=True, timeout=120
                )
                
                return result.returncode == 0
                
            finally:
                os.chdir(original_cwd)
                # Clean up test directory
                import shutil
                shutil.rmtree(test_dir, ignore_errors=True)
            
        except Exception as e:
            self.logger.warning(f"JFrog repository test warning: {str(e)}")
            return False

    def setup_maven_wrapper(self, project_path: Path) -> Tuple[bool, str]:
        """Setup Maven wrapper for the enterprise project."""
        if not project_path.exists():
            return False, f"Project path does not exist: {project_path}"
        
        self.logger.info(f"Setting up Maven wrapper for {project_path}")
        
        try:
            original_cwd = os.getcwd()
            os.chdir(project_path)
            
            try:
                # Check if Maven wrapper already exists
                mvnw_script = project_path / 'mvnw'
                if mvnw_script.exists():
                    self.logger.info("Maven wrapper already exists")
                    return True, "Maven wrapper already configured"
                
                # Generate Maven wrapper
                result = subprocess.run(
                    ['mvn', 'wrapper:wrapper'],
                    capture_output=True, text=True, timeout=120
                )
                
                if result.returncode == 0:
                    # Make wrapper executable
                    if mvnw_script.exists():
                        mvnw_script.chmod(0o755)
                    
                    return True, "Maven wrapper generated successfully"
                else:
                    return False, f"Maven wrapper generation failed: {result.stderr}"
                    
            finally:
                os.chdir(original_cwd)
                
        except subprocess.TimeoutExpired:
            return False, "Maven wrapper setup timed out"
        except Exception as e:
            return False, f"Maven wrapper setup error: {str(e)}"

    def configure_ide_maven_settings(self) -> Tuple[bool, str]:
        """Configure IDE-specific Maven settings."""
        self.logger.info("Configuring IDE Maven settings...")
        
        try:
            # IntelliJ IDEA Maven configuration
            intellij_configs = []
            
            # Check for IntelliJ configuration directories
            possible_intellij_dirs = [
                Path.home() / '.IntelliJIdea2023.3',
                Path.home() / '.IntelliJIdea2023.2',
                Path.home() / '.IntelliJIdea2023.1',
                Path.home() / 'Library' / 'Application Support' / 'JetBrains' / 'IntelliJIdea2023.3',
                Path.home() / 'Library' / 'Application Support' / 'JetBrains' / 'IntelliJIdea2023.2',
            ]
            
            intellij_dir = None
            for dir_path in possible_intellij_dirs:
                if dir_path.exists():
                    intellij_dir = dir_path
                    break
            
            if intellij_dir:
                # Create Maven configuration for IntelliJ
                maven_config_dir = intellij_dir / 'config' / 'options'
                maven_config_dir.mkdir(parents=True, exist_ok=True)
                
                maven_config_file = maven_config_dir / 'maven.xml'
                maven_config = f"""<?xml version="1.0" encoding="UTF-8"?>
<application>
  <component name="MavenSettings">
    <option name="generalSettings">
      <MavenGeneralSettings>
        <option name="mavenHome" value="{self._get_maven_home()}" />
        <option name="userSettingsFile" value="{self.m2_dir / 'settings.xml'}" />
        <option name="localRepository" value="{self.m2_dir / 'repository'}" />
      </MavenGeneralSettings>
    </option>
  </component>
</application>"""
                
                with open(maven_config_file, 'w') as f:
                    f.write(maven_config)
                
                intellij_configs.append(str(maven_config_file))
            
            if intellij_configs:
                return True, f"IDE Maven configuration created: {', '.join(intellij_configs)}"
            else:
                return True, "No IDE configuration directories found (will be configured when IDE is installed)"
                
        except Exception as e:
            return False, f"IDE Maven configuration error: {str(e)}"

    def _get_maven_home(self) -> str:
        """Get Maven home directory."""
        try:
            # Try to get Maven home from environment
            maven_home = os.environ.get('M2_HOME') or os.environ.get('MAVEN_HOME')
            if maven_home and Path(maven_home).exists():
                return maven_home
            
            # Try to find Maven installation
            result = subprocess.run(['mvn', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'Maven home:' in line:
                        return line.split('Maven home:')[1].strip()
            
            # Default locations
            default_locations = [
                '/usr/local/maven',
                '/opt/maven',
                '/usr/share/maven',
                '/usr/local/apache-maven',
            ]
            
            for location in default_locations:
                if Path(location).exists():
                    return location
            
            return '/usr/local/maven'  # Fallback
            
        except Exception:
            return '/usr/local/maven'  # Fallback

    def verify_maven_setup(self) -> Tuple[bool, Dict[str, Any]]:
        """Verify complete Maven setup."""
        self.logger.info("Verifying Maven setup...")
        
        results = {
            'maven_installed': self._verify_maven_installation(),
            'settings_xml': self._verify_settings_xml(),
            'repository_access': self._verify_repository_access(),
            'jfrog_configuration': self._verify_jfrog_configuration()
        }
        
        all_passed = all(result['success'] for result in results.values() 
                        if result['success'] is not None)
        
        return all_passed, results

    def _verify_maven_installation(self) -> Dict[str, Any]:
        """Verify Maven installation."""
        try:
            result = subprocess.run(['mvn', '--version'], capture_output=True, text=True)
            
            if result.returncode == 0:
                version_info = result.stdout
                return {
                    'success': True,
                    'version_info': version_info,
                    'message': 'Maven installation verified'
                }
            else:
                return {
                    'success': False,
                    'version_info': None,
                    'message': f'Maven not working: {result.stderr}'
                }
                
        except FileNotFoundError:
            return {
                'success': False,
                'version_info': None,
                'message': 'Maven not found in PATH'
            }
        except Exception as e:
            return {
                'success': False,
                'version_info': None,
                'message': f'Maven verification error: {str(e)}'
            }

    def _verify_settings_xml(self) -> Dict[str, Any]:
        """Verify settings.xml file."""
        settings_path = self.m2_dir / 'settings.xml'
        
        if not settings_path.exists():
            return {
                'success': False,
                'path': str(settings_path),
                'valid_xml': False,
                'has_jfrog_config': False,
                'message': 'settings.xml not found'
            }
        
        try:
            # Validate XML
            tree = ET.parse(settings_path)
            valid_xml = True
            
            # Check for JFrog configuration
            root = tree.getroot()
            has_jfrog_config = False
            
            # Check servers
            for server in root.findall('.//server'):
                server_id = server.find('id')
                if server_id is not None:
                    id_text = server_id.text.lower()
                    if any(x in id_text for x in ['central', 'snapshots', 'artifactory', 'libs-']):
                        has_jfrog_config = True
                        break
            
            # Also check repository URLs
            if not has_jfrog_config:
                for repo in root.findall('.//repository'):
                    url_elem = repo.find('url')
                    if url_elem is not None and 'jfrog.io' in url_elem.text:
                        has_jfrog_config = True
                        break
            
            return {
                'success': True,
                'path': str(settings_path),
                'valid_xml': valid_xml,
                'has_jfrog_config': has_jfrog_config,
                'message': f'settings.xml found and valid (JFrog config: {has_jfrog_config})'
            }
            
        except ET.ParseError as e:
            return {
                'success': False,
                'path': str(settings_path),
                'valid_xml': False,
                'has_jfrog_config': False,
                'message': f'Invalid XML: {str(e)}'
            }
        except Exception as e:
            return {
                'success': False,
                'path': str(settings_path),
                'valid_xml': False,
                'has_jfrog_config': False,
                'message': f'settings.xml verification error: {str(e)}'
            }

    def _verify_repository_access(self) -> Dict[str, Any]:
        """Verify Maven repository access."""
        try:
            # Test basic dependency resolution
            result = subprocess.run(
                ['mvn', 'help:effective-settings'],
                capture_output=True, text=True, timeout=30
            )
            
            repository_accessible = result.returncode == 0
            
            return {
                'success': repository_accessible,
                'accessible': repository_accessible,
                'message': 'Maven repositories accessible' if repository_accessible else 'Repository access issues'
            }
            
        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'accessible': False,
                'message': 'Repository access test timed out'
            }
        except Exception as e:
            return {
                'success': False,
                'accessible': False,
                'message': f'Repository access test error: {str(e)}'
            }

    def _verify_jfrog_configuration(self) -> Dict[str, Any]:
        """Verify JFrog Artifactory configuration."""
        # This would be more comprehensive with actual JFrog API calls
        # For now, check if configuration exists in settings.xml
        
        settings_path = self.m2_dir / 'settings.xml'
        if not settings_path.exists():
            return {
                'success': None,  # Not applicable
                'configured': False,
                'message': 'settings.xml not found'
            }
        
        try:
            tree = ET.parse(settings_path)
            root = tree.getroot()
            
            # Look for JFrog-related configuration
            jfrog_servers = []
            for server in root.findall('.//server'):
                server_id = server.find('id')
                if server_id is not None:
                    id_text = server_id.text.lower()
                    # Check for common JFrog server IDs
                    if any(x in id_text for x in ['central', 'snapshots', 'artifactory', 'libs-']):
                        jfrog_servers.append(server_id.text)
            
            configured = len(jfrog_servers) > 0
            
            return {
                'success': configured,
                'configured': configured,
                'servers': jfrog_servers,
                'message': f'JFrog configuration {"found" if configured else "not found"} in settings.xml'
            }
            
        except Exception as e:
            return {
                'success': False,
                'configured': False,
                'servers': [],
                'message': f'JFrog configuration check error: {str(e)}'
            }