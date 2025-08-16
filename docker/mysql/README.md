# Legion MySQL Container

Pre-built MySQL 8.0 container with Legion databases, hosted on JFrog Artifactory.

## For Most Developers (Just Pull and Use)

The MySQL container is already built and available on JFrog. You don't need to build it yourself!

### Using with Docker Compose
The docker-compose.yml already references the image:
```yaml
mysql:
  image: legiontech.jfrog.io/docker-local/legion-mysql:latest
```

Just run:
```bash
cd ../
docker-compose up -d mysql
```

### Manual Pull
```bash
# Login to JFrog (if not already logged in)
docker login legiontech.jfrog.io

# Pull the image
docker pull legiontech.jfrog.io/docker-local/legion-mysql:latest

# Run it
docker run -d -p 3306:3306 --name legion-mysql \
  legiontech.jfrog.io/docker-local/legion-mysql:latest
```

## For DevOps/Platform Team (Building and Updating)

Only build a new container when:
- Database schema changes significantly
- New snapshot data is available
- Collation or character set updates needed

### Prerequisites

1. **Database dump files** in `~/work/dbdumps/` (or set `DBDUMPS_FOLDER`):
   - `storedprocedures.sql`
   - `legiondb.sql.zip`
   - `legiondb0.sql.zip`
   
   Download from: https://drive.google.com/drive/folders/1WhTR6fP9KkFO4m7mxLSGu-Ksf4erQ6RK

2. **JFrog access** with Docker push permissions

### Build Process

```bash
# Set dbdumps folder if not using default
export DBDUMPS_FOLDER=~/work/dbdumps

# Run the build script
./build-mysql-container.sh
```

The script will:
1. ✅ Check if image already exists in JFrog (skip if present)
2. ✅ Verify all database dump files are present
3. ✅ Extract `.zip` files automatically
4. ✅ Build Docker image with:
   - MySQL 8.0 base
   - Databases: `legiondb` and `legiondb0`
   - Users: `legion` (password: `legionwork`)
   - Data imported from snapshots
   - Stored procedures loaded
   - Collations fixed to `utf8mb4_general_ci`
5. ✅ Test container locally (port 3307)
6. ✅ Push to JFrog Artifactory
7. ✅ Clean up temporary files

### What's Included

The container includes everything from the README_enterprise setup:

1. **Databases Created**:
   ```sql
   CREATE DATABASE legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
   CREATE DATABASE legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
   ```

2. **Users Created**:
   ```sql
   CREATE USER 'legion'@'%' IDENTIFIED BY 'legionwork';
   CREATE USER 'legion'@'localhost' IDENTIFIED BY 'legionwork';
   CREATE USER 'legionro'@'%' IDENTIFIED BY 'legionwork';  -- read-only
   ```

3. **Data Imported**:
   - `legiondb.sql` → `legiondb`
   - `legiondb0.sql` → `legiondb0`
   - `storedprocedures.sql` → both databases

4. **Collations Fixed**:
   - All tables converted to `utf8mb4_general_ci`
   - Prevents "Illegal mix of collations" errors

5. **Enterprise Schema**:
   - Copied from `legiondb` to `legiondb0`

### Versioning

Images are tagged with:
- `latest` - Always points to newest build
- `YYYYMMDD-HHMMSS` - Specific version timestamp

### Troubleshooting

#### Image already exists
The script checks if an image exists in JFrog and asks if you want to rebuild. Choose:
- `N` to use existing (default)
- `Y` to build and push new version

#### Test fails
If the local test fails, check:
```bash
docker logs legion-mysql-test
```

Common issues:
- Corrupted dump files
- Insufficient disk space
- SQL syntax errors in dumps

#### Manual verification
Test the container manually:
```bash
docker run -d -p 3307:3306 --name test-mysql \
  legiontech.jfrog.io/docker-local/legion-mysql:latest

# Wait 30 seconds for initialization
sleep 30

# Test connection
mysql -h 127.0.0.1 -P 3307 -u legion -plegionwork -e "SHOW DATABASES;"

# Check tables
mysql -h 127.0.0.1 -P 3307 -u legion -plegionwork legiondb -e "SHOW TABLES;" | wc -l

# Cleanup
docker stop test-mysql && docker rm test-mysql
```

### Updating Schema

When schema changes:
1. Get new database dumps
2. Place in dbdumps folder
3. Run build script
4. Test thoroughly
5. Update docker-compose.yml if needed
6. Notify team of new image availability

## Benefits

Using the containerized MySQL:
- ⚡ **Instant setup** - No 45-minute import wait
- 🎯 **Consistent** - Everyone has exact same data
- 🔄 **Versioned** - Can roll back if needed
- 📦 **Portable** - Works on any Docker host
- 🛡️ **Isolated** - No system MySQL conflicts
- ✅ **Pre-fixed** - Collations already corrected

## Connection Details

- **Host**: `localhost` (or container name)
- **Port**: `3306`
- **Database**: `legiondb` or `legiondb0`
- **Username**: `legion`
- **Password**: `legionwork`
- **Root Password**: `mysql123`

## Support

For issues or updates:
- Slack: #devops-it-support
- Check JFrog for available versions
- Build logs in: `~/.legion_setup/logs/`