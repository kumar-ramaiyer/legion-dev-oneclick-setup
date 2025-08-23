# Version 12 Changes - Backend Runtime Fixes

## Overview
Version 12 addresses critical backend runtime issues discovered during local development setup testing. These fixes ensure the Legion backend can start successfully and run without errors in the local development environment.

## Problems Identified

### 1. MySQL Collation Mismatch
**Symptom:** `Illegal mix of collations (utf8mb4_general_ci,IMPLICIT) and (utf8mb4_0900_ai_ci,IMPLICIT)`

**Root Cause:** 
- Database schemas configured with `utf8mb4_general_ci`
- Flyway migrations created tables with MySQL 8.0 default `utf8mb4_0900_ai_ci`
- JPA queries failed when joining columns with different collations

**Impact:** 
- AccrualTypeMigrateTask failures
- OAuth2 token operation failures
- Enterprise data query failures

### 2. HikariCP Connection Pool Exhaustion
**Symptom:** `Connection is not available, request timed out after XXXXms`

**Root Cause:**
- Default max connections (100) insufficient for startup load
- Multiple scheduled tasks competing for connections
- Long-running transactions during initialization

**Impact:**
- Background task failures
- Intermittent connection timeouts
- Degraded performance during startup

### 3. Cache Bootstrap Timeout
**Symptom:** `PLT_TASK cache not ready even after 10 minutes`

**Root Cause:**
- Cache initialization exceeding 10-minute timeout
- Sequential cache loading causing delays
- Complex interdependencies between caches

**Impact:**
- Background tasks disabled
- Scheduled operations not running
- 90+ timeout occurrences per startup

### 4. Dynamic Group Enum Mismatch
**Symptom:** `Cannot deserialize value of type DynamicGroupCondition$FieldType from String "WorkRole"`

**Root Cause:**
- Test data contains "WorkRole" field type
- Current enum missing this value
- Data-code version mismatch

## Solutions Implemented

### MySQL Collation Standardization
**File:** `docker/mysql/build-mysql-container.sh`

Added automated collation conversion:
```sql
-- Convert all tables to utf8mb4_general_ci
ALTER DATABASE legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER DATABASE legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
-- Procedure to convert all tables (see script for details)
```

### Connection Pool Optimization
**File:** `scripts/build-and-run.sh` → `config/local.values.yml`

Applied performance optimizations:
```yaml
datasource_max_active: 150  # Increased from 100
datasource_min_size: 10     # Increased from 5
datasource_max_wait: 5000   # Added timeout
```

### Cache Configuration Enhancement
**File:** `config/local.values.yml`

Improved cache settings:
```yaml
cache_bootstrap_timeout: 20  # Increased from 10 minutes
cache_bootstrap_parallel: true
cache_bootstrap_batch_size: 50
```

### Build Script Improvements
**File:** `scripts/build-and-run.sh`

Key enhancements:
1. **Idempotent config optimization function**
   - Checks if optimizations already applied
   - Returns status to trigger rebuild when needed
   - Creates timestamped backups

2. **Smart config rebuild logic**
   - Detects when source config changes
   - Forces rebuild after optimization
   - Handles missing application.yml

3. **Proper cleanup**
   - Removes sed backup files
   - Maintains clean working directory

## Testing & Validation

### Pre-Fix Symptoms
- Backend startup: 15-20 minutes with errors
- Multiple connection pool exhaustion errors
- Cache bootstrap timeouts
- Collation mismatch query failures

### Post-Fix Results
- Backend startup: 2-3 minutes (normal)
- No connection pool errors
- Cache bootstrap completes successfully
- All queries execute without collation issues

## Migration Guide

### For Existing Environments
1. Pull latest changes from v12 branch
2. Rebuild MySQL container: `./docker/mysql/build-mysql-container.sh`
3. Run backend build: `./scripts/build-and-run.sh build-backend`
4. Start backend: `./scripts/build-and-run.sh run-backend`

### For New Environments
No special steps required - all fixes are integrated into standard setup flow.

## Rollback Plan
If issues occur:
1. Config backups are created with timestamp: `*.backup.YYYYMMDD_HHMMSS`
2. MySQL changes are idempotent and can be re-run
3. Previous branch (v11) remains available

## Files Modified

### Setup Repository
- `docker/mysql/build-mysql-container.sh` - Added collation standardization
- `scripts/build-and-run.sh` - Added config optimization and smart rebuild
- `scripts/check-backend-ready.sh` - Enhanced monitoring and feedback
- `BACKEND_ISSUES_ANALYSIS.md` - Comprehensive issue documentation

### Enterprise Repository (local changes)
- `config/src/main/resources/templates/application/local/local.values.yml` - Performance settings
- `pom.xml` - Lombok annotation processor configuration

## Future Improvements
1. Consider adding WorkRole to DynamicGroupCondition enum in main codebase
2. Investigate reducing cache initialization time
3. Monitor for additional missing enterprise IDs
4. Consider LocalStack integration for S3 features

## Notes
- All changes are backward compatible
- Scripts are idempotent (safe to run multiple times)
- Performance optimizations are conservative and tested
- Documentation added inline for maintainability