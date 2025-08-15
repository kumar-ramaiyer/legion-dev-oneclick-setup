#!/usr/bin/env python3
"""
Helper script to extract Google Drive file IDs from URLs.
This helps users configure automatic database snapshot downloads.
"""

import re
import sys

def extract_file_id(url):
    """Extract Google Drive file ID from various URL formats."""
    patterns = [
        r'/file/d/([a-zA-Z0-9_-]+)',  # https://drive.google.com/file/d/FILE_ID/view
        r'id=([a-zA-Z0-9_-]+)',        # https://drive.google.com/uc?id=FILE_ID
        r'/folders/([a-zA-Z0-9_-]+)',  # https://drive.google.com/drive/folders/FOLDER_ID
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    
    # If no pattern matches, assume the input might be just the ID
    if len(url) > 10 and not url.startswith('http'):
        return url
    
    return None

def main():
    print("""
╔══════════════════════════════════════════════════════════════╗
║            GOOGLE DRIVE FILE ID EXTRACTOR                   ║
╚══════════════════════════════════════════════════════════════╝

This tool helps you extract Google Drive file IDs from URLs
for automatic database snapshot downloads.

Please provide the Google Drive URLs for each database file:
""")
    
    files = {
        'storedprocedures.sql': '',
        'legiondb.sql.zip': '',
        'legiondb0.sql.zip': ''
    }
    
    for filename in files:
        while True:
            url = input(f"\nEnter URL for {filename} (or 'skip'): ").strip()
            
            if url.lower() == 'skip':
                print(f"  ⏭️  Skipping {filename}")
                break
            
            file_id = extract_file_id(url)
            if file_id:
                files[filename] = file_id
                print(f"  ✅ Extracted ID: {file_id}")
                break
            else:
                print("  ❌ Could not extract file ID. Please check the URL and try again.")
    
    # Generate config snippet
    print("""
╔══════════════════════════════════════════════════════════════╗
║                    CONFIGURATION SNIPPET                    ║
╚══════════════════════════════════════════════════════════════╝

Add this to your setup_config.yaml under the 'jfrog' section:
""")
    
    print("""
jfrog:
  download_settings_xml: true
  artifactory_url: ""
  db_snapshot_ids:""")
    
    print(f"    storedprocedures: \"{files['storedprocedures.sql']}\"")
    print(f"    legiondb: \"{files['legiondb.sql.zip']}\"")
    print(f"    legiondb0: \"{files['legiondb0.sql.zip']}\"")
    
    print("""
With these IDs configured, the setup will automatically download
the database snapshots from Google Drive during installation.
""")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        sys.exit(1)