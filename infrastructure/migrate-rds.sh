#!/bin/bash

# Database migration script for AWS RDS
# Usage: ./migrate-rds.sh <rds-endpoint>

set -e

RDS_ENDPOINT=$1
DB_NAME=${2:-tipjar_db}
DB_USER=${3:-tipjar_user}
DB_PASSWORD=${4:-tipjar_password}

if [ -z "$RDS_ENDPOINT" ]; then
  echo "Usage: $0 <rds-endpoint> [db_name] [db_user] [db_password]"
  exit 1
fi

echo "Migrating database to RDS: $RDS_ENDPOINT"

# Wait for RDS to be ready
echo "Waiting for RDS to be ready..."
until PGPASSWORD=$DB_PASSWORD psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; do
  echo "RDS is unavailable - sleeping"
  sleep 5
done

echo "RDS is ready - running migrations..."

# Run schema and stored procedures in order
PGPASSWORD=$DB_PASSWORD psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f schema.sql
PGPASSWORD=$DB_PASSWORD psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f stored_providers.sql
PGPASSWORD=$DB_PASSWORD psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f stored_tips.sql
PGPASSWORD=$DB_PASSWORD psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f stored_bank_payments.sql
PGPASSWORD=$DB_PASSWORD psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f functions.sql

echo "Migration completed successfully!"
