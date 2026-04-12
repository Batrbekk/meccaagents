#!/bin/bash
# PostgreSQL restore script
# Usage: ./scripts/restore-db.sh backups/postgres/agentteam_20260413_030000.sql.gz

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <backup-file.sql.gz>"
  echo "Available backups:"
  ls -la backups/postgres/*.sql.gz 2>/dev/null || echo "  No backups found"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "WARNING: This will DROP and recreate the database!"
read -p "Are you sure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo "[$(date)] Restoring from $BACKUP_FILE..."

gunzip -c "$BACKUP_FILE" | docker compose exec -T postgres psql \
  -U "${POSTGRES_USER:-agentteam}" \
  -d "${POSTGRES_DB:-agentteam}"

echo "[$(date)] Restore complete."
