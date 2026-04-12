#!/bin/bash
# PostgreSQL backup script — run via cron daily
# Usage: ./scripts/backup-db.sh
# Cron: 0 3 * * * /path/to/meccaagents/scripts/backup-db.sh

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/agentteam_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting PostgreSQL backup..."

docker compose exec -T postgres pg_dump \
  -U "${POSTGRES_USER:-agentteam}" \
  -d "${POSTGRES_DB:-agentteam}" \
  --no-owner \
  --no-privileges \
  | gzip > "$BACKUP_FILE"

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup complete: $BACKUP_FILE ($SIZE)"

# Cleanup old backups
echo "[$(date)] Removing backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "agentteam_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "[$(date)] Backup job done."
