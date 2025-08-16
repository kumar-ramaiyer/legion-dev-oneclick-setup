# Legion MySQL with pre-loaded data
FROM mysql:8.0

# Environment variables
ENV MYSQL_ROOT_PASSWORD=mysql123
ENV MYSQL_DATABASE=legiondb

# Copy initialization scripts (run in alphabetical order)
COPY scripts/*.sql /docker-entrypoint-initdb.d/
COPY scripts/*.sh /docker-entrypoint-initdb.d/

# Copy data files
COPY data/*.sql /var/lib/mysql-import/

# Ensure scripts are executable
RUN chmod +x /docker-entrypoint-initdb.d/*.sh || true

# Expose port
EXPOSE 3306

# Add labels
LABEL maintainer="Legion DevOps"
LABEL description="MySQL 8.0 with Legion databases pre-loaded"
LABEL version="${VERSION}"
