#!/bin/sh
# Prometheus backup script for sidecar

BACKUP_DIR="/backup"
RETENTION_DAYS=30
PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus:9090}"

echo "$(date) - Starting Prometheus backup..."

# Create snapshot via API
SNAPSHOT=$(curl -s -XPOST ${PROMETHEUS_URL}/api/v1/admin/tsdb/snapshot | jq -r .data.name)

if [ -z "$SNAPSHOT" ] || [ "$SNAPSHOT" = "null" ]; then
    echo "$(date) - ERROR: Failed to create snapshot"
    exit 1
fi

echo "$(date) - Created snapshot: $SNAPSHOT"

# Copy snapshot to backup location
BACKUP_NAME="prometheus-$(date +%Y%m%d-%H%M%S)"
cp -r /prometheus/snapshots/$SNAPSHOT $BACKUP_DIR/$BACKUP_NAME

if [ $? -eq 0 ]; then
    echo "$(date) - Backup completed: $BACKUP_NAME"
    
    # Delete old backups
    find $BACKUP_DIR -name "prometheus-*" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null
    echo "$(date) - Cleaned up backups older than $RETENTION_DAYS days"
else
    echo "$(date) - ERROR: Backup failed"
    exit 1
fi

# Clean up snapshot in Prometheus (optional - they auto-clean anyway)
# Note: We can't delete from read-only mount, but snapshots are cleaned by Prometheus

echo "$(date) - Backup process completed"