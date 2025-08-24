# Skipping Flyway Migrations for Docker Setup

Since the Docker MySQL container should have pre-loaded databases with complete schema and data, 
you can skip Flyway migrations during the Maven build by:

## Option 1: Skip Flyway in Maven Command
Add `-Dflyway.skip=true` to your Maven command:

```bash
mvn clean compile -P dev -Djavax.net.ssl.trustStorePassword=changeit -Dflyway.skip=true
```

## Option 2: Configure in local.values.yml
Set Flyway to baseline mode in your local configuration to skip migrations.

## Note
The proper long-term solution is to rebuild the MySQL container with database dumps that 
already contain the complete migrated schema (all Flyway migrations applied).