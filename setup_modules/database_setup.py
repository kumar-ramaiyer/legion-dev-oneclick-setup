#!/usr/bin/env python3
"""
Legion Setup - Database Setup Module
Handles MySQL database setup, user creation, and data import
"""

import os
import sys
import subprocess
import mysql.connector
from mysql.connector import Error
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import tempfile
import gzip
import hashlib
import zipfile
import shutil

class DatabaseSetup:
    def __init__(self, config: Dict, logger):
        self.config = config
        self.logger = logger
        self.db_config = config.get('database', {})
        self.temp_dir = Path(tempfile.mkdtemp(prefix='legion_db_setup_'))
        
        # Database connection parameters
        self.root_password = self.db_config.get('mysql_root_password', '')
        self.legion_password = self.db_config.get('legion_db_password', 'legionwork')

    def __del__(self):
        """Cleanup temporary directory."""
        if hasattr(self, 'temp_dir') and self.temp_dir.exists():
            import shutil
            shutil.rmtree(self.temp_dir, ignore_errors=True)

    def setup_mysql_service(self) -> Tuple[bool, str]:
        """Start and configure MySQL service."""
        self.logger.info("Setting up MySQL service...")
        
        try:
            # Start MySQL service
            start_result = self._start_mysql_service()
            if not start_result[0]:
                return start_result
            
            # Secure MySQL installation
            secure_result = self._secure_mysql_installation()
            if not secure_result[0]:
                return secure_result
            
            return True, "MySQL service setup completed"
            
        except Exception as e:
            return False, f"MySQL service setup error: {str(e)}"

    def _start_mysql_service(self) -> Tuple[bool, str]:
        """Start MySQL service based on platform."""
        try:
            # Try different methods to start MySQL
            start_commands = [
                ['brew', 'services', 'start', 'mysql'],  # macOS Homebrew
                ['sudo', 'systemctl', 'start', 'mysql'],  # Linux systemd
                ['mysql.server', 'start'],  # MySQL server script
                ['sudo', '/usr/local/mysql/support-files/mysql.server', 'start']  # Manual MySQL
            ]
            
            for cmd in start_commands:
                try:
                    if not self._command_exists(cmd[0]):
                        continue
                        
                    result = subprocess.run(
                        cmd, capture_output=True, text=True, timeout=30
                    )
                    
                    if result.returncode == 0:
                        self.logger.info(f"MySQL started using: {' '.join(cmd)}")
                        
                        # Wait a moment for MySQL to fully start
                        time.sleep(3)
                        
                        # Verify MySQL is responding
                        if self._test_mysql_connection():
                            return True, "MySQL service started successfully"
                            
                except subprocess.TimeoutExpired:
                    continue
                except Exception:
                    continue
            
            return False, "Could not start MySQL service. Please start MySQL manually."
            
        except Exception as e:
            return False, f"MySQL service start error: {str(e)}"

    def _command_exists(self, command: str) -> bool:
        """Check if a command exists in the system."""
        import shutil
        return shutil.which(command) is not None

    def _test_mysql_connection(self) -> bool:
        """Test if MySQL is accepting connections."""
        try:
            # Try to connect without password first (fresh installation)
            connection = mysql.connector.connect(
                host='localhost',
                user='root',
                password='',
                connection_timeout=5
            )
            connection.close()
            return True
        except Error:
            pass
        
        # Try with configured password
        try:
            if self.root_password:
                connection = mysql.connector.connect(
                    host='localhost',
                    user='root',
                    password=self.root_password,
                    connection_timeout=5
                )
                connection.close()
                return True
        except Error:
            pass
        
        return False

    def _secure_mysql_installation(self) -> Tuple[bool, str]:
        """Perform basic MySQL security setup."""
        try:
            # Get root password if not provided
            if not self.root_password:
                import getpass
                self.root_password = getpass.getpass("Enter MySQL root password (leave blank for new installation): ")
            
            # Connect to MySQL
            connection = self._get_mysql_connection('root', self.root_password or '')
            if not connection:
                return False, "Could not connect to MySQL"
            
            cursor = connection.cursor()
            
            # Set root password if it's empty
            if not self.root_password:
                new_password = getpass.getpass("Set new MySQL root password: ")
                if new_password:
                    cursor.execute(f"ALTER USER 'root'@'localhost' IDENTIFIED BY '{new_password}';")
                    self.root_password = new_password
            
            # Flush privileges
            cursor.execute("FLUSH PRIVILEGES;")
            
            cursor.close()
            connection.close()
            
            return True, "MySQL security setup completed"
            
        except Error as e:
            return False, f"MySQL security setup error: {str(e)}"

    def create_databases_and_users(self) -> Tuple[bool, str]:
        """Create Legion databases and users."""
        self.logger.info("Creating Legion databases and users...")
        
        try:
            connection = self._get_mysql_connection('root', self.root_password)
            if not connection:
                return False, "Could not connect to MySQL as root"
            
            cursor = connection.cursor()
            
            # Set character set and collation
            setup_commands = [
                "SET global character_set_server='utf8mb4';",
                "SET global collation_server='utf8mb4_general_ci';",
                
                # Create databases
                "CREATE DATABASE IF NOT EXISTS legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;",
                "CREATE DATABASE IF NOT EXISTS legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;",
                
                # Drop users if they exist (to avoid conflicts)
                "DROP USER IF EXISTS 'legion'@'%';",
                "DROP USER IF EXISTS 'legionro'@'%';",
                "DROP USER IF EXISTS 'legion'@'localhost';",
                
                # Create users
                f"CREATE USER 'legion'@'%' IDENTIFIED WITH caching_sha2_password BY '{self.legion_password}';",
                f"CREATE USER 'legionro'@'%' IDENTIFIED WITH caching_sha2_password BY '{self.legion_password}';",
                f"CREATE USER 'legion'@'localhost' IDENTIFIED WITH caching_sha2_password BY '{self.legion_password}';",
                
                # Grant privileges
                "GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'%' WITH GRANT OPTION;",
                "GRANT ALL PRIVILEGES ON legiondb.* TO 'legion'@'localhost' WITH GRANT OPTION;",
                "GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'%' WITH GRANT OPTION;",
                "GRANT ALL PRIVILEGES ON legiondb0.* TO 'legion'@'localhost' WITH GRANT OPTION;",
                
                # Flush privileges
                "FLUSH PRIVILEGES;"
            ]
            
            for command in setup_commands:
                self.logger.debug(f"Executing: {command}")
                cursor.execute(command)
            
            # Verify databases were created
            cursor.execute("SHOW DATABASES;")
            databases = [row[0] for row in cursor.fetchall()]
            
            if 'legiondb' not in databases or 'legiondb0' not in databases:
                return False, "Databases were not created successfully"
            
            cursor.close()
            connection.close()
            
            self.logger.info("✅ Databases and users created successfully")
            return True, "Legion databases and users created successfully"
            
        except Error as e:
            return False, f"Database creation error: {str(e)}"

    def import_data(self) -> Tuple[bool, str]:
        """Import data into Legion databases."""
        use_snapshot = self.config.get('setup_options', {}).get('use_snapshot_import', True)
        
        if use_snapshot:
            return self._import_snapshot_data()
        else:
            return self._import_full_dump()

    def _import_snapshot_data(self) -> Tuple[bool, str]:
        """Import data from snapshot files (Option 1 - faster)."""
        self.logger.info("Importing snapshot data...")
        
        try:
            snapshot_dir = Path.home() / 'Legion_DB_Snapshots'
            snapshot_dir.mkdir(exist_ok=True)
            
            # Try to automatically download from Google Drive
            download_success = self._download_snapshot_files(snapshot_dir)
            
            if not download_success:
                # Fall back to manual download
                self.logger.warning("⚠️  Automatic download failed. Manual download required.")
                print(f"""
╔══════════════════════════════════════════════════════════════╗
║                   MANUAL DOWNLOAD REQUIRED                  ║
╚══════════════════════════════════════════════════════════════╝

Please download the following files from Google Drive:
- storedprocedures.sql
- legiondb.sql.zip (extract to legiondb.sql)  
- legiondb0.sql.zip (extract to legiondb0.sql)

Save them to: {snapshot_dir}

Google Drive Link: https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK

Press Enter when files are ready...
                """)
                
                if not self.config.get('advanced', {}).get('auto_confirm', False):
                    input()
            
            # Check for required files
            required_files = ['storedprocedures.sql', 'legiondb.sql', 'legiondb0.sql']
            missing_files = []
            
            for file in required_files:
                file_path = snapshot_dir / file
                if not file_path.exists():
                    missing_files.append(str(file_path))
            
            if missing_files:
                return False, f"Missing snapshot files: {', '.join(missing_files)}"
            
            # Import legiondb
            legiondb_result = self._import_sql_file(
                snapshot_dir / 'legiondb.sql', 'legiondb'
            )
            if not legiondb_result[0]:
                return legiondb_result
            
            # Import stored procedures for legiondb
            sp_result = self._import_sql_file(
                snapshot_dir / 'storedprocedures.sql', 'legiondb'
            )
            if not sp_result[0]:
                return sp_result
            
            # Import legiondb0
            legiondb0_result = self._import_sql_file(
                snapshot_dir / 'legiondb0.sql', 'legiondb0'
            )
            if not legiondb0_result[0]:
                return legiondb0_result
            
            # Import stored procedures for legiondb0
            sp0_result = self._import_sql_file(
                snapshot_dir / 'storedprocedures.sql', 'legiondb0'
            )
            if not sp0_result[0]:
                return sp0_result
            
            # Fix collation mismatches
            collation_result = self._fix_collation_mismatches()
            if not collation_result[0]:
                self.logger.warning(f"Collation fix warning: {collation_result[1]}")
            
            return True, "Snapshot data imported successfully"
            
        except Exception as e:
            return False, f"Snapshot import error: {str(e)}"
    
    def _download_snapshot_files(self, snapshot_dir: Path) -> bool:
        """Download snapshot files from Google Drive automatically."""
        try:
            # Try to import gdown
            try:
                import gdown
            except ImportError:
                self.logger.info("Installing gdown for Google Drive downloads...")
                # Use the same Python interpreter that's running this script (should be venv)
                # This ensures we install to the correct environment
                result = subprocess.run([sys.executable, '-m', 'pip', 'install', 'gdown'], 
                                      capture_output=True, text=True)
                if result.returncode != 0:
                    self.logger.error(f"Failed to install gdown: {result.stderr}")
                    return False
                import gdown
            
            # Get Google Drive folder URL from config
            db_config = self.config.get('database_snapshots', {})
            gdrive_folder_url = db_config.get('gdrive_folder_url', 
                'https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK')
            
            print(f"""
╔══════════════════════════════════════════════════════════════╗
║              DOWNLOADING DATABASE SNAPSHOTS                 ║
╚══════════════════════════════════════════════════════════════╝

📁 Source: {gdrive_folder_url}
""")
            
            # Try to download all files from the Google Drive folder
            success = self._download_from_gdrive_folder(gdrive_folder_url, snapshot_dir)
            
            if not success:
                # Fallback to manual IDs if configured
                file_ids = db_config.get('file_ids', {})
                if any(file_ids.values()):
                    self.logger.info("Trying configured file IDs...")
                    files_to_download = {
                        'storedprocedures.sql': (file_ids.get('storedprocedures', ''), False),
                        'legiondb.sql.zip': (file_ids.get('legiondb', ''), True),
                        'legiondb0.sql.zip': (file_ids.get('legiondb0', ''), True),
                    }
                else:
                    # Use hardcoded fallback IDs
                    files_to_download = {
                        'storedprocedures.sql': ('', False),  # No fallback ID
                        'legiondb.sql.zip': ('', True),
                        'legiondb0.sql.zip': ('', True),
                    }
            
                all_success = True
                
                for filename, (file_id, is_zip) in files_to_download.items():
                    output_path = snapshot_dir / filename
                
                    # Skip if already exists (unless it's a zip that needs extraction)
                    if not is_zip:
                        sql_file = snapshot_dir / filename
                        if sql_file.exists():
                            self.logger.info(f"✅ {filename} already exists, skipping download")
                            continue
                    else:
                        # Check if the extracted SQL file exists
                        sql_filename = filename.replace('.zip', '')
                        sql_file = snapshot_dir / sql_filename
                        if sql_file.exists():
                            self.logger.info(f"✅ {sql_filename} already exists, skipping download")
                            continue
                    
                    print(f"📥 Downloading {filename}...")
                    
                    # Check if the file ID looks valid
                    if 'REPLACE_WITH_ACTUAL_ID' in file_id or len(file_id) < 10:
                        self.logger.warning(f"Invalid Google Drive ID for {filename}")
                        print(f"   ⚠️  Skipping {filename} - Google Drive ID not configured")
                        all_success = False
                        continue
                    
                    try:
                        # Download from Google Drive
                        url = f'https://drive.google.com/uc?id={file_id}'
                        gdown.download(url, str(output_path), quiet=False)
                        
                        if not output_path.exists():
                            self.logger.error(f"Failed to download {filename}")
                            all_success = False
                            continue
                        
                        # Extract if it's a zip file
                        if is_zip and output_path.exists():
                            print(f"📦 Extracting {filename}...")
                            with zipfile.ZipFile(output_path, 'r') as zip_ref:
                                zip_ref.extractall(snapshot_dir)
                            # Remove the zip file after extraction
                            output_path.unlink()
                            self.logger.info(f"✅ Extracted {filename}")
                        else:
                            self.logger.info(f"✅ Downloaded {filename}")
                            
                    except Exception as e:
                        self.logger.error(f"Failed to download {filename}: {str(e)}")
                        all_success = False
                    
                    # Try alternate download method using requests
                    if 'drive.google.com' in str(e).lower():
                        print(f"   Trying alternate download method...")
                        alt_success = self._download_with_requests(file_id, output_path, is_zip, snapshot_dir)
                        if alt_success:
                            all_success = True
            
            if all_success:
                print("\n✅ All database snapshots downloaded successfully!")
            else:
                print("\n⚠️  Some files could not be downloaded automatically.")
                
            return all_success
            
        except Exception as e:
            self.logger.error(f"Download error: {str(e)}")
            return False
    
    def _download_with_requests(self, file_id: str, output_path: Path, is_zip: bool, snapshot_dir: Path) -> bool:
        """Alternative download method using requests."""
        try:
            import requests
            
            # Try direct download URL
            download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
            
            session = requests.Session()
            response = session.get(download_url, stream=True)
            
            # Check for virus scan warning
            for key, value in response.cookies.items():
                if key.startswith('download_warning'):
                    download_url = f"https://drive.google.com/uc?export=download&confirm={value}&id={file_id}"
                    response = session.get(download_url, stream=True)
                    break
            
            # Save the file
            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            # Extract if needed
            if is_zip and output_path.exists():
                with zipfile.ZipFile(output_path, 'r') as zip_ref:
                    zip_ref.extractall(snapshot_dir)
                output_path.unlink()
                
            return output_path.exists() or (is_zip and (snapshot_dir / output_path.stem).exists())
            
        except Exception as e:
            self.logger.error(f"Alternative download failed: {str(e)}")
            return False
    
    def _download_from_gdrive_folder(self, folder_url: str, snapshot_dir: Path) -> bool:
        """Download all database files from Google Drive folder."""
        try:
            import gdown
            
            # Extract folder ID from URL
            import re
            folder_match = re.search(r'/folders/([a-zA-Z0-9_-]+)', folder_url)
            if not folder_match:
                self.logger.error(f"Invalid Google Drive folder URL: {folder_url}")
                return False
            
            folder_id = folder_match.group(1)
            
            # Download all files from the folder
            # gdown can download entire folders
            try:
                # Create a temporary directory for downloads
                temp_download = snapshot_dir / 'temp_download'
                temp_download.mkdir(exist_ok=True)
                
                # Try to download the entire folder
                gdown_url = f"https://drive.google.com/drive/folders/{folder_id}"
                
                # Use gdown to download folder contents
                # Note: This requires the folder to be publicly accessible
                result = gdown.download_folder(gdown_url, output=str(temp_download), quiet=False)
                
                if result:
                    # Move files to the correct location
                    import shutil
                    for file in temp_download.glob('*'):
                        if file.name.endswith('.zip'):
                            # Extract zip files
                            print(f"📦 Extracting {file.name}...")
                            with zipfile.ZipFile(file, 'r') as zip_ref:
                                zip_ref.extractall(snapshot_dir)
                            file.unlink()
                        else:
                            # Move SQL files
                            target = snapshot_dir / file.name
                            shutil.move(str(file), str(target))
                            print(f"✅ Downloaded {file.name}")
                    
                    # Clean up temp directory
                    shutil.rmtree(temp_download, ignore_errors=True)
                    return True
                    
            except Exception as folder_error:
                self.logger.warning(f"Could not download entire folder: {str(folder_error)}")
                
                # Fallback: Try to download individual files we know about
                known_files = [
                    ('storedprocedures.sql', False),
                    ('legiondb.sql.zip', True),
                    ('legiondb0.sql.zip', True)
                ]
                
                # This would require knowing the individual file IDs
                # or using the Google Drive API to list folder contents
                self.logger.info("Attempting to download individual files...")
                
                # For now, return False to trigger fallback
                return False
                
        except ImportError:
            self.logger.error("gdown not available for folder download")
            return False
        except Exception as e:
            self.logger.error(f"Folder download error: {str(e)}")
            return False

    def _import_full_dump(self) -> Tuple[bool, str]:
        """Import data from full AWS S3 dump (Option 2 - slower but complete)."""
        self.logger.info("Importing full database dump...")
        
        try:
            # This would require AWS credentials and S3 access
            # For now, provide instructions for manual setup
            
            print(f"""
╔══════════════════════════════════════════════════════════════╗
║                   FULL DUMP IMPORT                          ║
╚══════════════════════════════════════════════════════════════╝

Full database dump import requires:
1. AWS S3 access via Okta
2. Download of mysqldumpddl.sql and mysqldumpdata.gz
3. Large disk space (~50GB during import)

This process can take several hours. Please refer to the README.md
for detailed instructions on Option 2 import.

Continuing with empty system schema creation...
            """)
            
            # Create system schema (legiondb0)
            return self._create_system_schema()
            
        except Exception as e:
            return False, f"Full dump import error: {str(e)}"

    def _import_sql_file(self, sql_file: Path, database: str) -> Tuple[bool, str]:
        """Import a SQL file into specified database."""
        self.logger.info(f"Importing {sql_file.name} into {database}...")
        
        try:
            # Use MySQL command line client for import
            cmd = [
                'mysql',
                '-u', 'legion',
                f'-p{self.legion_password}',
                database
            ]
            
            with open(sql_file, 'r') as f:
                result = subprocess.run(
                    cmd,
                    stdin=f,
                    capture_output=True,
                    text=True,
                    timeout=1800  # 30 minutes timeout
                )
            
            if result.returncode != 0:
                return False, f"SQL import failed: {result.stderr}"
            
            return True, f"{sql_file.name} imported into {database}"
            
        except subprocess.TimeoutExpired:
            return False, f"SQL import timed out for {sql_file.name}"
        except Exception as e:
            return False, f"SQL import error for {sql_file.name}: {str(e)}"

    def _create_system_schema(self) -> Tuple[bool, str]:
        """Create system schema (legiondb0) from enterprise schema."""
        self.logger.info("Creating system schema...")
        
        try:
            # This would involve running the system schema creation scripts
            # from enterprise/migration/src/main/scripts
            
            scripts_dir = Path.home() / 'work' / 'enterprise' / 'migration' / 'src' / 'main' / 'scripts'
            
            if not scripts_dir.exists():
                return False, f"Enterprise scripts directory not found: {scripts_dir}"
            
            # Set environment variable for script
            env = os.environ.copy()
            env['SS_DB_ADMIN'] = 'legion'
            
            # Temporarily reset legion password to blank for script
            temp_password_result = self._temporarily_reset_legion_password('')
            if not temp_password_result[0]:
                return temp_password_result
            
            try:
                # Run system schema creation script
                creation_script = scripts_dir / 'system_schema_creation.sh'
                if creation_script.exists():
                    result = subprocess.run(
                        [str(creation_script)],
                        cwd=str(scripts_dir),
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=300
                    )
                    
                    if result.returncode != 0:
                        return False, f"System schema creation failed: {result.stderr}"
                
                # Run table copy script
                copy_script = scripts_dir / 'system_schema_table_copy.sh'
                if copy_script.exists():
                    result = subprocess.run(
                        [str(copy_script)],
                        cwd=str(scripts_dir),
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=600
                    )
                    
                    if result.returncode != 0:
                        return False, f"System schema table copy failed: {result.stderr}"
                
            finally:
                # Reset legion password back
                self._temporarily_reset_legion_password(self.legion_password)
            
            # Insert enterprise schema data
            insert_result = self._insert_enterprise_schema()
            if not insert_result[0]:
                return insert_result
            
            return True, "System schema created successfully"
            
        except Exception as e:
            return False, f"System schema creation error: {str(e)}"

    def _temporarily_reset_legion_password(self, new_password: str) -> Tuple[bool, str]:
        """Temporarily reset legion user password."""
        try:
            connection = self._get_mysql_connection('root', self.root_password)
            if not connection:
                return False, "Could not connect to MySQL as root"
            
            cursor = connection.cursor()
            
            if new_password:
                cursor.execute(f"ALTER USER 'legion'@'localhost' IDENTIFIED BY '{new_password}';")
            else:
                cursor.execute("ALTER USER 'legion'@'localhost' IDENTIFIED BY '';")
            
            cursor.execute("FLUSH PRIVILEGES;")
            
            cursor.close()
            connection.close()
            
            return True, "Password reset successfully"
            
        except Error as e:
            return False, f"Password reset error: {str(e)}"

    def _insert_enterprise_schema(self) -> Tuple[bool, str]:
        """Insert enterprise schema data."""
        try:
            connection = self._get_mysql_connection('legion', self.legion_password)
            if not connection:
                return False, "Could not connect to MySQL as legion user"
            
            cursor = connection.cursor()
            
            # Insert enterprise schema data
            cursor.execute("""
                INSERT INTO legiondb0.EnterpriseSchema 
                (SELECT * FROM legiondb.EnterpriseSchema)
            """)
            
            cursor.close()
            connection.close()
            
            return True, "Enterprise schema data inserted"
            
        except Error as e:
            # It's okay if this fails (source table might be empty)
            self.logger.warning(f"Enterprise schema insert warning: {str(e)}")
            return True, "Enterprise schema insert completed (source may be empty)"

    def _fix_collation_mismatches(self) -> Tuple[bool, str]:
        """Fix collation mismatches in the databases."""
        self.logger.info("Fixing collation mismatches...")
        
        try:
            # Python script to fix collations
            collation_script = """
import mysql.connector

def fix_collation(database):
    connection = mysql.connector.connect(
        host='localhost',
        user='legion',
        password='{password}',
        database=database
    )
    
    cursor = connection.cursor()
    
    # Get all tables
    cursor.execute("SHOW TABLES")
    tables = [row[0] for row in cursor.fetchall()]
    
    for table in tables:
        # Fix table collation
        cursor.execute(f"ALTER TABLE `{table}` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci")
    
    connection.commit()
    cursor.close()
    connection.close()

fix_collation('legiondb')
fix_collation('legiondb0')
            """.format(password=self.legion_password)
            
            # Write and execute the script
            script_file = self.temp_dir / 'fix_collation.py'
            with open(script_file, 'w') as f:
                f.write(collation_script)
            
            result = subprocess.run([
                sys.executable, str(script_file)
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode != 0:
                return False, f"Collation fix failed: {result.stderr}"
            
            return True, "Collation mismatches fixed"
            
        except Exception as e:
            return False, f"Collation fix error: {str(e)}"

    def _get_mysql_connection(self, user: str, password: str, database: str = None):
        """Get MySQL connection."""
        try:
            connection_params = {
                'host': 'localhost',
                'user': user,
                'password': password
            }
            
            if database:
                connection_params['database'] = database
            
            return mysql.connector.connect(**connection_params)
            
        except Error as e:
            self.logger.error(f"MySQL connection error: {str(e)}")
            return None

    def verify_database_setup(self) -> Tuple[bool, str]:
        """Verify that database setup is working correctly."""
        self.logger.info("Verifying database setup...")
        
        try:
            # Test connection as legion user
            connection = self._get_mysql_connection('legion', self.legion_password)
            if not connection:
                return False, "Cannot connect as legion user"
            
            cursor = connection.cursor()
            
            # Check databases exist
            cursor.execute("SHOW DATABASES")
            databases = [row[0] for row in cursor.fetchall()]
            
            required_databases = ['legiondb', 'legiondb0']
            missing_databases = [db for db in required_databases if db not in databases]
            
            if missing_databases:
                return False, f"Missing databases: {', '.join(missing_databases)}"
            
            # Check table counts
            verification_results = []
            
            for database in required_databases:
                cursor.execute(f"USE {database}")
                cursor.execute("SHOW TABLES")
                table_count = len(cursor.fetchall())
                verification_results.append(f"{database}: {table_count} tables")
            
            cursor.close()
            connection.close()
            
            result_message = f"Database verification passed: {', '.join(verification_results)}"
            return True, result_message
            
        except Error as e:
            return False, f"Database verification error: {str(e)}"