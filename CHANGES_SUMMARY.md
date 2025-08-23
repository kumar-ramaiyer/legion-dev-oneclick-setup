# Legion Dev Setup - Session Changes Summary
**Date**: August 22, 2025
**Branch**: feature/v9-improvements → master (PR #10)

## 🎯 Problems Addressed

### 1. Multi-Schema Routing Failure
**Error**: `MULTISCHEMA Cannot determine DataSource for [enterprise-id]`
- Application couldn't route database connections to correct schema
- Affected enterprises: 
  - `4f52834d-43bf-41ad-a3b5-a0c019b752af` (initial error)
  - `ebacf6df-ce56-497f-b6e7-eaee94ce3ef8` (legion enterprise)

### 2. MySQL Connection Issues
- Connection failures when using 'localhost' due to socket vs TCP issues
- Fixed by switching to '127.0.0.1' for TCP connections

### 3. Missing Enterprise Data
- Enterprise table was empty
- Data existed in Enterprise_migrated_20240712100546 table but wasn't being used

## ✅ Solutions Implemented

### MySQL Configuration Changes (`docker/config.sh`)
```bash
# Changed from:
export MYSQL_HOST="localhost"
# To:
export MYSQL_HOST="127.0.0.1"
```

### Enhanced MySQL Container Build (`docker/mysql/build-mysql-container.sh`)

#### 1. Enterprise Data Migration
- Added automatic migration from Enterprise_migrated table
- Preserves all enterprise IDs and relationships
- Ensures Enterprise table is populated before schema mappings

#### 2. Dynamic Schema Mapping Generation
```sql
-- Creates mappings for all enterprises dynamically
INSERT INTO EnterpriseSchema (...)
SELECT UUID(), 1, 'system', NOW(), 'system', NOW(), 0, 0, Enterprise.objectId, 'legiondb0'
FROM legiondb.Enterprise;
```

#### 3. Critical Fix for legiondb0.EnterpriseSchema
- **Key Discovery**: Application uses `legiondb0.EnterpriseSchema` for routing decisions
- **Fix**: All enterprises in this table must map to 'legiondb0'
- Previously some were incorrectly mapped to 'legiondb'

### Build Script Improvements (`scripts/build-and-run.sh`)

#### 1. Maven Build Configuration
- Changed from dev profile to default profile for enterprise JAR generation
- Added proper compiler flags for Java compatibility
- Fixed JAR path detection for Spring Boot builds

#### 2. Frontend Build Enhancements
- Added Node.js 18 support with nvm
- Switched to yarn for dependency management
- Simplified build process with yarn lerna bootstrap

#### 3. Runtime Configuration
- Updated JVM parameters for better memory management
- Fixed library paths for native dependencies
- Enhanced logging configuration

## 📊 Database Schema Mappings

### Final State in legiondb.EnterpriseSchema:
| Enterprise ID | Schema Key | Purpose |
|--------------|------------|---------|
| 1 | default, legiondb | System default |
| ebacf6df-... (legion) | legiondb | Main enterprise |
| 4f31d62f-... (LegionCoffee) | legiondb | Test enterprise |
| 85887433-... (dgrc) | legiondb | Test enterprise |
| 08a5cc1e-... (akumar) | legiondb | Test enterprise |
| 4f52834d-... | legiondb0 | Problematic UUID |

### Final State in legiondb0.EnterpriseSchema:
| Enterprise ID | Schema Key | Purpose |
|--------------|------------|---------|
| All enterprises | legiondb0 | Multi-tenant routing |

## 🔧 Technical Implementation Details

### Order of Operations (Critical)
1. Import database dumps (legiondb.sql, legiondb0.sql)
2. Import stored procedures
3. **Migrate Enterprise data** (from Enterprise_migrated table)
4. **Create EnterpriseSchema mappings** (based on Enterprise table)

### Key Insights
1. EnterpriseSchema table must exist in both databases
2. Application primarily uses legiondb0.EnterpriseSchema for routing
3. All enterprises in legiondb0.EnterpriseSchema must map to 'legiondb0'
4. Dynamic mapping generation is better than hardcoding enterprise IDs

## 📝 Files Modified

1. **docker/config.sh**
   - MySQL host configuration change

2. **docker/mysql/build-mysql-container.sh**
   - Added Enterprise data migration logic
   - Implemented dynamic schema mapping generation
   - Fixed EnterpriseSchema creation order
   - Enhanced verification output

3. **scripts/build-and-run.sh**
   - Updated Maven build configuration
   - Fixed JAR path detection
   - Enhanced frontend build process
   - Improved runtime parameters

## 🧪 Verification Steps

### Check Enterprise Data:
```sql
SELECT objectId, name FROM legiondb.Enterprise;
```

### Verify Schema Mappings:
```sql
SELECT enterpriseId, schemaKey FROM legiondb0.EnterpriseSchema;
```

### Test Multi-Schema Routing:
```bash
./scripts/build-and-run.sh run-backend
# Should start without "MULTISCHEMA Cannot determine DataSource" errors
```

## 🚀 Impact

This fix enables:
- Proper multi-tenant database routing
- Successful backend application startup
- Dynamic enterprise onboarding
- Consistent development environment setup

## 📌 Important Notes

1. **Always run operations in correct order**: Import → Migrate → Map
2. **legiondb0.EnterpriseSchema is critical** for routing decisions
3. **Enterprise table must be populated** before creating mappings
4. **Use 127.0.0.1 instead of localhost** for MySQL connections

## 🔄 Future Improvements

1. Consider automating Enterprise migration as part of standard setup
2. Add validation to ensure all enterprises have proper mappings
3. Document the multi-schema routing architecture
4. Create health checks for schema mapping consistency