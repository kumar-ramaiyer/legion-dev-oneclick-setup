#!/bin/bash
# Setup development SSL certificates for Legion
# Uses mkcert for locally-trusted development certificates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Development SSL Certificate Setup                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if running on Mac or Linux
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Step 1: Install mkcert if not present
echo -e "${YELLOW}Step 1: Checking for mkcert...${NC}"
if ! command -v mkcert &> /dev/null; then
    echo "Installing mkcert..."
    if [[ "$OS" == "macos" ]]; then
        if command -v brew &> /dev/null; then
            brew install mkcert
            brew install nss # For Firefox support
        else
            echo -e "${RED}Homebrew not found. Please install mkcert manually:${NC}"
            echo "  brew install mkcert"
            exit 1
        fi
    elif [[ "$OS" == "linux" ]]; then
        # Download mkcert binary for Linux
        curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
        chmod +x mkcert-*-linux-amd64
        sudo mv mkcert-*-linux-amd64 /usr/local/bin/mkcert
    fi
else
    echo -e "${GREEN}✓ mkcert is already installed${NC}"
fi

# Step 2: Install local CA
echo -e "${YELLOW}Step 2: Installing local Certificate Authority...${NC}"
mkcert -install
echo -e "${GREEN}✓ Local CA installed and trusted${NC}"

# Step 3: Create certificate directory
CERT_DIR="$HOME/.legion_setup/certificates"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo -e "${YELLOW}Step 3: Generating certificates...${NC}"

# Step 4: Generate certificates for Legion domains
mkcert -cert-file legion-cert.pem -key-file legion-key.pem \
    localhost \
    127.0.0.1 \
    ::1 \
    legion.local \
    "*.legion.local" \
    legion.test \
    "*.legion.test"

echo -e "${GREEN}✓ Certificates generated${NC}"

# Step 5: Generate convenience scripts
echo -e "${YELLOW}Step 4: Creating helper scripts...${NC}"

# Create nginx config example
cat > nginx-ssl.conf << 'EOF'
# Example Nginx SSL configuration for Legion
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name legion.local *.legion.local;

    ssl_certificate /path/to/.legion_setup/certificates/legion-cert.pem;
    ssl_certificate_key /path/to/.legion_setup/certificates/legion-key.pem;

    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Proxy to backend
    location /api {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Proxy to frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create simple Python HTTPS server for testing
cat > serve-https.py << 'EOF'
#!/usr/bin/env python3
"""Simple HTTPS server for testing Legion with SSL"""
import ssl
import http.server
import socketserver
import os

PORT = 8443
CERT_FILE = "legion-cert.pem"
KEY_FILE = "legion-key.pem"

Handler = http.server.SimpleHTTPRequestHandler

context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT_FILE, KEY_FILE)

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    print(f"Serving HTTPS on https://localhost:{PORT}")
    print(f"Also available at https://legion.local:{PORT}")
    print("Press Ctrl+C to stop")
    httpd.serve_forever()
EOF
chmod +x serve-https.py

# Create Node.js HTTPS configuration
cat > node-https-config.js << 'EOF'
// HTTPS configuration for Node.js/Express
const fs = require('fs');
const path = require('path');

module.exports = {
  key: fs.readFileSync(path.join(process.env.HOME, '.legion_setup/certificates/legion-key.pem')),
  cert: fs.readFileSync(path.join(process.env.HOME, '.legion_setup/certificates/legion-cert.pem'))
};

// Usage in Express:
// const https = require('https');
// const sslConfig = require('./node-https-config');
// https.createServer(sslConfig, app).listen(3443);
EOF

# Create Spring Boot configuration
cat > application-ssl.yml << 'EOF'
# Spring Boot SSL configuration for Legion
server:
  port: 8443
  ssl:
    enabled: true
    key-store: ${user.home}/.legion_setup/certificates/legion.p12
    key-store-password: changeit
    key-store-type: PKCS12
    key-alias: legion
EOF

# Convert to PKCS12 for Java/Spring Boot
echo -e "${YELLOW}Step 5: Creating Java keystore...${NC}"
openssl pkcs12 -export \
    -in legion-cert.pem \
    -inkey legion-key.pem \
    -out legion.p12 \
    -name legion \
    -password pass:changeit

echo -e "${GREEN}✓ Java keystore created${NC}"

# Step 6: Update /etc/hosts if needed
echo -e "${YELLOW}Step 6: Checking /etc/hosts...${NC}"
if ! grep -q "legion.local" /etc/hosts; then
    echo "Adding legion.local to /etc/hosts (requires sudo)..."
    echo "127.0.0.1 legion.local" | sudo tee -a /etc/hosts > /dev/null
    echo "127.0.0.1 api.legion.local" | sudo tee -a /etc/hosts > /dev/null
    echo "127.0.0.1 app.legion.local" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}✓ Added legion.local domains to /etc/hosts${NC}"
else
    echo -e "${GREEN}✓ legion.local already in /etc/hosts${NC}"
fi

# Display summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            SSL Certificate Setup Complete!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Certificate Information:${NC}"
echo "  Location:     $CERT_DIR"
echo "  Certificate:  legion-cert.pem"
echo "  Private Key:  legion-key.pem"
echo "  Java Store:   legion.p12 (password: changeit)"
echo ""
echo -e "${BLUE}Valid for domains:${NC}"
echo "  - localhost"
echo "  - legion.local"
echo "  - *.legion.local"
echo "  - legion.test"
echo "  - *.legion.test"
echo ""
echo -e "${BLUE}Example configurations created:${NC}"
echo "  - nginx-ssl.conf      (Nginx configuration)"
echo "  - serve-https.py      (Python test server)"
echo "  - node-https-config.js (Node.js configuration)"
echo "  - application-ssl.yml  (Spring Boot configuration)"
echo ""
echo -e "${YELLOW}To test HTTPS:${NC}"
echo "  cd $CERT_DIR"
echo "  python3 serve-https.py"
echo "  # Then visit https://legion.local:8443"
echo ""
echo -e "${GREEN}✨ Your browser will now trust legion.local with a green padlock!${NC}"