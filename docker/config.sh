#!/bin/bash

# Legion Docker Configuration - Central configuration for all Docker scripts
# Source this file in other scripts: source "$(dirname "$0")/config.sh"

# Container Names
export MYSQL_CONTAINER="legion-mysql"
export MYSQL_IMPORT_CONTAINER="mysql-import"
export CADDY_CONTAINER="legion-caddy"
export ELASTICSEARCH_CONTAINER="legion-elasticsearch"
export REDIS_MASTER_CONTAINER="legion-redis-master"
export REDIS_SLAVE_CONTAINER="legion-redis-slave"
export LOCALSTACK_CONTAINER="legion-localstack"
export MAILHOG_CONTAINER="legion-mailhog"
export JAEGER_CONTAINER="legion-jaeger"

# Volume Names
export MYSQL_VOLUME="legion-mysql-data"
export CADDY_DATA_VOLUME="caddy-data"
export CADDY_CONFIG_VOLUME="caddy-config"
export ES_DATA_VOLUME="es-data"
export REDIS_MASTER_VOLUME="redis-master-data"
export REDIS_SLAVE_VOLUME="redis-slave-data"
export LOCALSTACK_VOLUME="localstack-data"

# Network Name
export LEGION_NETWORK="legion-network"

# Image Names
export MYSQL_IMAGE="mysql:8.0"  # Using standard MySQL with volume
export CADDY_IMAGE="caddy:latest"
export ELASTICSEARCH_IMAGE="docker.elastic.co/elasticsearch/elasticsearch:8.0.0"
export REDIS_IMAGE="redis:latest"
export LOCALSTACK_IMAGE="localstack/localstack:latest"
export MAILHOG_IMAGE="mailhog/mailhog:latest"
export JAEGER_IMAGE="jaegertracing/all-in-one:latest"

# MySQL Configuration
export MYSQL_HOST="localhost"
export MYSQL_PORT="3306"
export MYSQL_ROOT_PASSWORD="mysql123"
export MYSQL_DATABASE="legiondb"
export MYSQL_USER="legion"
export MYSQL_PASSWORD="legionwork"

# Other Ports
export ELASTICSEARCH_PORT="9200"
export REDIS_PORT="6379"
export REDIS_SLAVE_PORT="6380"
export LOCALSTACK_PORT="4566"
export MAILHOG_SMTP_PORT="1025"
export MAILHOG_UI_PORT="8025"
export JAEGER_UI_PORT="16686"

# Database targets
export LEGIONDB_TABLE_COUNT="913"
export LEGIONDB0_TABLE_COUNT="840"

# Colors for output (consistent across scripts)
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color