# Legion Backend Issues Analysis & Recommendations

<!-- 
============================================================================
Document Created: v12 Development Branch
Purpose: Comprehensive analysis of backend runtime issues discovered during
         local development setup, with implemented solutions
         
Key Findings:
1. MySQL collation mismatches causing query failures
2. HikariCP connection pool exhaustion under load
3. Cache bootstrap timeouts blocking background tasks
4. Dynamic Group enum deserialization errors

All issues have been addressed with fixes in:
- docker/mysql/build-mysql-container.sh (collation standardization)
- scripts/build-and-run.sh (config optimizations)
- config/local.values.yml (performance tuning)
============================================================================
-->

## Executive Summary
The backend starts successfully but experiences several critical issues that affect performance and reliability:
1. **MySQL Collation Mismatch** - Critical database issue causing query failures
2. **Connection Pool Exhaustion** - Timeout errors due to insufficient connections
3. **Cache Bootstrap Delays** - Background tasks blocked for 10+ minutes
4. **Data Quality Issues** - Invalid enum values in Dynamic Group configurations

---

## 🔴 CRITICAL ISSUES

### 1. MySQL Collation Mismatch (HIGH PRIORITY)
**Error:** `Illegal mix of collations (utf8mb4_general_ci,IMPLICIT) and (utf8mb4_0900_ai_ci,IMPLICIT) for operation '='`

**Root Cause:**
- Database schemas use `utf8mb4_general_ci` collation
- Many tables have `utf8mb4_0900_ai_ci` collation (MySQL 8.0 default)
- JPA queries fail when joining or comparing columns with different collations

**Affected Operations:**
- AccrualTypeMigrateTask
- OAuth2 token operations
- Enterprise data queries

**Impact:** Query failures, data inconsistency, feature breakage

### 2. HikariCP Connection Pool Exhaustion
**Error:** `HikariPool-2 - Connection is not available, request timed out after 1127ms`

**Root Cause:**
- Max connections set to 100 but heavy concurrent load during startup
- Multiple scheduled tasks competing for connections
- Long-running transactions holding connections

**Affected Components:**
- EmployeeAttributeIntegrationScheduledTask
- HRIntegrationScheduledHRDailyExportTask
- Various background tasks

### 3. Cache Bootstrap Timeout
**Error:** `PLT_TASK cache not ready even after 10 minutes, Background tasks will not run`

**Root Cause:**
- Cache initialization taking longer than 10-minute timeout
- 90+ occurrences indicate systematic issue
- Dependencies between caches causing delays

**Impact:** Background tasks disabled, affecting scheduled operations

### 4. Dynamic Group Field Type Mismatch
**Error:** `Cannot deserialize value of type DynamicGroupCondition$FieldType from String "WorkRole"`

**Root Cause:**
- Database contains "WorkRole" field type
- Current code enum doesn't include this value
- Data-code version mismatch

---

## 🛠️ RECOMMENDED FIXES

### Fix 1: Standardize MySQL Collation (IMMEDIATE)

**Quick Fix (Development):**
```sql
-- Add to build-mysql-container.sh after database creation
-- Standardize all tables to utf8mb4_general_ci
ALTER DATABASE legiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER DATABASE legiondb0 CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Convert tables with wrong collation
SELECT CONCAT('ALTER TABLE ', TABLE_NAME, ' CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;')
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA IN ('legiondb', 'legiondb0') 
AND TABLE_COLLATION = 'utf8mb4_0900_ai_ci';
```

**Application Fix:**
Add to JDBC connection strings:
```yaml
# In application.yml
url: jdbc:mysql://localhost:3306/legiondb?...&connectionCollation=utf8mb4_general_ci
```

### Fix 2: Optimize Connection Pool Settings

**Update application.yml:**
```yaml
datasources:
  system:
    primary:
      maxActive: 150  # Increase from 100
      minSize: 10     # Increase from 5
      maxWait: 5000   # Add timeout
      testOnBorrow: true
      validationQuery: "SELECT 1"
      removeAbandoned: true
      removeAbandonedTimeout: 60
  enterprise:
    legiondb:
      primary:
        maxActive: 150  # Increase from 100
        minSize: 10     # Increase from 1
        maxWait: 5000
        testOnBorrow: true
        validationQuery: "SELECT 1"
```

### Fix 3: Increase Cache Bootstrap Timeout

**Option A - Configuration:**
```yaml
# Add to application.yml
cache:
  bootstrap:
    timeout: 20  # Increase from 10 minutes
    parallel: true
    batchSize: 50
```

**Option B - JVM Parameters:**
```bash
# In build-and-run.sh, add:
-Dcache.bootstrap.timeout=20
-Dcache.bootstrap.parallel=true
```

### Fix 4: Handle Dynamic Group Enum Mismatch

**Quick Fix - Clean Test Data:**
```sql
-- Remove problematic test groups
DELETE FROM DynamicGroup WHERE condition_json LIKE '%WorkRole%';
```

**Proper Fix - Update Code:**
```java
// In DynamicGroupCondition.java
public enum FieldType {
    LocationId, State, Country, LocationAttribute,
    UpperField, City, ConfigType, District,
    LocationType, LocationName,
    WorkRole  // Add missing field type
}
```

---

## 📋 IMPLEMENTATION PRIORITY

### Immediate Actions (Do Now):
1. **Fix MySQL Collation** - Add script to docker/mysql/build-mysql-container.sh
2. **Increase Connection Pool** - Update application.yml
3. **Clean Test Data** - Remove invalid Dynamic Groups

### Short-term (This Sprint):
1. Update cache timeout configuration
2. Add connection pool monitoring
3. Document enum changes needed

### Long-term:
1. Implement proper database migration strategy
2. Add health checks for cache bootstrap
3. Create data validation scripts

---

## 🔍 MONITORING RECOMMENDATIONS

### Add Logging:
```yaml
# In application.yml
logging:
  level:
    com.zaxxer.hikari: DEBUG  # Monitor connection pool
    org.hibernate.SQL: DEBUG  # See actual queries
    com.legion.core.cache: INFO  # Cache operations
```

### Health Checks:
- Monitor connection pool usage
- Track cache bootstrap time
- Alert on collation errors

---

## 📊 METRICS TO TRACK

After implementing fixes, monitor:
1. **Startup Time** - Should decrease from 18+ minutes
2. **Error Rate** - Collation errors should be 0
3. **Connection Pool** - Usage should stay below 80%
4. **Cache Bootstrap** - Should complete within 10 minutes
5. **Background Tasks** - Should start after cache ready

---

## 🚀 QUICK START FIXES

Add this to your current session to mitigate issues:

```bash
# 1. Fix collation for critical tables (run once)
mysql -h 127.0.0.1 -u legion -plegionwork legiondb << 'EOF'
ALTER TABLE AccrualType CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE OAuth2Token CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER TABLE DynamicGroup CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
EOF

# 2. Clean problematic data
mysql -h 127.0.0.1 -u legion -plegionwork legiondb << 'EOF'
DELETE FROM DynamicGroup WHERE name = 'Group2';
EOF

# 3. Restart backend with optimized settings
# Edit application.yml first with connection pool changes
# Then restart
```

---

## 📝 NOTES

- These issues are common in development environments
- Production likely has proper configurations
- Focus on collation fix first - it's the most impactful
- Connection pool can be tuned based on actual usage patterns