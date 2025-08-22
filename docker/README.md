# Legion Docker Development Environment

Complete Docker-based development environment for Legion with all required services.

## 🚀 Quick Start

```bash
cd docker
./setup-docker-env.sh
```

This will:
1. Update `/etc/hosts` with local domains
2. Login to JFrog Docker registry
3. Pull all required images
4. Start all services
5. Trust the development SSL certificate
6. Display access URLs

## 📦 Services Included

### Core Services
- **MySQL 8.0** - Pre-loaded with legiondb and legiondb0 (from JFrog)
- **Elasticsearch 8.0** - Search and analytics
- **Redis Master/Slave** - Distributed locking and caching
- **Caddy** - Reverse proxy with automatic HTTPS

### Development Tools
- **LocalStack** - AWS services emulation (S3, SQS, DynamoDB, etc.)
- **MailHog** - Email testing (catches all SMTP)
- **Jaeger** - Distributed tracing

## 🌐 Access URLs

All services are available via HTTPS with valid development certificates:

- **Application**: https://legion.local
- **Mail UI**: https://mail.legion.local
- **Tracing**: https://tracing.legion.local
- **Health Check**: https://health.legion.local/services

## 🔧 Configuration

### Backend Configuration
Update your `application.yml`:

```yaml
# MySQL
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/legiondb
    username: legion
    password: legionwork

# Elasticsearch
elasticsearch:
  host: localhost
  port: 9200

# Redis
redis:
  master:
    host: localhost
    port: 6379
  slave:
    host: localhost
    port: 6380

# Email (MailHog)
mail:
  host: localhost
  port: 1025

# AWS (LocalStack)
aws:
  endpoint: http://localhost:4566
  region: us-east-1
```

### Frontend Configuration
Access backend via: `https://legion.local/api`

## 🏗️ Building MySQL Container

To build and push the MySQL container with updated data:

```bash
cd mysql

# Place database dumps in data/ directory
cp ~/work/dbdumps/*.sql data/

# Unzip if needed
unzip data/legiondb.sql.zip -d data/
unzip data/legiondb0.sql.zip -d data/

# Build container with data
./build-mysql-container.sh
```

## 📝 Docker Commands

### Start all services
```bash
docker-compose up -d
```

### Stop all services
```bash
docker-compose down
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f mysql
```

### Restart a service
```bash
docker-compose restart mysql
```

### Clean everything (including data)
```bash
docker-compose down -v
```

### Update images
```bash
docker-compose pull
docker-compose up -d
```

## 🔒 HTTPS/SSL

Caddy automatically generates local development certificates. The setup script trusts these certificates on your system.

### Manual certificate trust (if needed)

**macOS:**
```bash
docker exec legion-caddy cat /data/caddy/pki/authorities/local/root.crt > caddy.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain caddy.crt
rm caddy.crt
```

**Linux:**
```bash
docker exec legion-caddy cat /data/caddy/pki/authorities/local/root.crt > caddy.crt
sudo cp caddy.crt /usr/local/share/ca-certificates/caddy-local.crt
sudo update-ca-certificates
rm caddy.crt
```

## 🐛 Troubleshooting

### Port conflicts
If you get port binding errors, check what's using the ports:
```bash
lsof -i :3306  # MySQL
lsof -i :9200  # Elasticsearch
lsof -i :6379  # Redis
```

### MySQL connection issues
```bash
# Test connection
docker exec -it legion-mysql mysql -ulegion -plegionwork -e "SELECT 1"

# Check logs
docker logs legion-mysql
```

### Caddy certificate issues
```bash
# Regenerate certificates
docker exec legion-caddy caddy trust
```

### Reset everything
```bash
docker-compose down -v
rm -rf volumes/
./setup-docker-env.sh
```

## 📊 Resource Usage

Recommended Docker settings:
- **Memory**: 8GB minimum
- **CPUs**: 4 cores
- **Disk**: 20GB free space

## 🔄 Updating Services

### Pull latest images
```bash
docker-compose pull
docker-compose up -d
```

### Update MySQL data
1. Build new container with updated dumps
2. Push to JFrog
3. Pull and restart:
   ```bash
   docker-compose pull mysql
   docker-compose up -d mysql
   ```

## 🏢 Production vs Development

This setup is for **development only**. Key differences from production:

- Self-signed SSL certificates
- No authentication on some services
- All services on single host
- Debug logging enabled
- Smaller resource allocations

## 🆘 Support

For issues or questions:
- Check logs: `docker-compose logs [service]`
- Slack: #devops-it-support
- Wiki: Legion Development Environment