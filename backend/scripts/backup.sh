#!/usr/bin/env bash
# Dumps the production database to a compressed file and deletes dumps older than 14 days.
#
#   backend/scripts/backup.sh
#
# Cron line (daily at 02:30, as the deploy user; see DEPLOY.md):
#   30 2 * * * /home/forreal/ForReal/backend/scripts/backup.sh >> /home/forreal/backups/backup.log 2>&1
#
# Settings, all optional:
#   BACKUP_DIR   where dumps go          (default: ~/backups)
#   KEEP_DAYS    days to keep a dump     (default: 14)
#   COMPOSE_FILE compose file to use     (default: docker-compose.prod.yml next to this script's parent)
set -euo pipefail
umask 077
# cron starts with a minimal PATH.
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

cd "$(dirname "$0")/.."
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"
export COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"

mkdir -p "$BACKUP_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
target="$BACKUP_DIR/forreal-$stamp.dump"
partial="$target.partial"
trap 'rm -f "$partial"' EXIT

# Custom format: compressed, and restorable with pg_restore.
docker compose exec -T db pg_dump -U forreal -d forreal --format=custom --compress=9 > "$partial"

if [ ! -s "$partial" ]; then
    echo "$(date -u +%FT%TZ) backup FAILED: empty dump" >&2
    exit 1
fi
# A dump that pg_restore cannot list is not a backup.
docker compose exec -T db pg_restore --list < "$partial" > /dev/null

mv "$partial" "$target"
find "$BACKUP_DIR" -maxdepth 1 -name 'forreal-*.dump' -type f -mtime +"$KEEP_DAYS" -delete
echo "$(date -u +%FT%TZ) backup ok: $target ($(du -h "$target" | cut -f1))"
