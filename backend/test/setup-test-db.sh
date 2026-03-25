#!/usr/bin/env bash
# Creates the test database if it does not already exist.
# Requires PostgreSQL to be running (via docker-compose up postgres).

set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-inventario}"
DB_PASS="${DB_PASS:-inventario_dev}"
DB_NAME="inventario_test"

export PGPASSWORD="$DB_PASS"

echo "Checking if database '$DB_NAME' exists..."
EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" 2>/dev/null || true)

if [ "$EXISTS" = "1" ]; then
  echo "Database '$DB_NAME' already exists."
else
  echo "Creating database '$DB_NAME'..."
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"
  echo "Database '$DB_NAME' created successfully."
fi
