# Legion MySQL Database Container
# Pre-loaded with legiondb and legiondb0 schemas and data
FROM mysql:8.0

# Set environment variables
ENV MYSQL_ROOT_PASSWORD=mysql123
ENV MYSQL_DATABASE=legiondb
ENV MYSQL_USER=legion
ENV MYSQL_PASSWORD=legionwork

# Copy initialization scripts
COPY init-scripts/ /docker-entrypoint-initdb.d/

# Copy pre-imported data files (if using SQL dumps)
COPY data/ /var/lib/mysql-import/

# Expose MySQL port
EXPOSE 3306

# Add healthcheck
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" || exit 1

# Labels for GitHub Container Registry
LABEL org.opencontainers.image.source="https://github.com/legionco/legion-mysql"
LABEL org.opencontainers.image.description="Legion MySQL with pre-loaded databases"
LABEL org.opencontainers.image.licenses="Proprietary"