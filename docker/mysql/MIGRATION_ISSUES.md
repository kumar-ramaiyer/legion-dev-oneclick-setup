# Flyway Migration Issues and Fixes

## Known Issues

### Migration Ordering Problem
Some Flyway migrations are numbered incorrectly, causing dependencies to fail:
- **V50_57.0.1753310683108** tries to add a column to `AccrualType` table
- **V51_38.0.1746976679999** creates the `AccrualType` table
- V50 runs before V51 (due to version numbering), causing failure

### Developer Confirmation
Per developer (Praveer Sengaru):
- "each one depends on previous... not 100% but generally true"
- "that is an issue, not sure why we put in wrong order there"
- "we need to archive old flyway scripts and fix order"

## Automated Fixes

### 1. Build Script (build-mysql-container.sh)
The build script automatically:
- Creates missing tables with all required columns
- Marks known failed migrations as successful
- Runs AFTER database import but BEFORE application start

### 2. Manual Fix Script (fix-failed-migrations.sh)
If new migration failures occur:
```bash
cd ~/work/legion-dev-oneclick-setup/docker/mysql
./fix-failed-migrations.sh
```

This script:
- Shows all failed migrations
- Optionally marks them as successful
- Allows application to continue

## How It Works

1. **Pre-Migration Fixes**: Creates tables/columns that later migrations expect
2. **Mark as Successful**: Updates flyway_schema_history to mark failed migrations as success=1
3. **Flyway Continues**: Flyway skips "successful" migrations and continues with the rest

## Important Notes

- This is a **workaround** until developers fix the migration ordering
- The actual migration SQL may not have been applied when marked successful
- Some features might not work if the migration was important
- Always check with developers if unsure about a failed migration

## Adding New Fixes

If you encounter a new migration failure:

1. Identify what table/column is missing
2. Add it to the pre-migration-fixes.sql in build script
3. Document it here
4. Consider if it needs special handling

## Long-term Solution

Developers need to:
1. Archive old flyway scripts
2. Fix version ordering
3. Ensure migrations are truly independent or properly ordered
4. Consider using timestamps instead of version numbers