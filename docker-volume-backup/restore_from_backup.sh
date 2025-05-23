#!/bin/bash

set -e

BACKUP_ROOT=~/docker-volume-backup/backups
TMP_DIR=/tmp/volume_restore

echo "🔍 Searching for latest backup..."

# Find latest backup directory
LATEST_BACKUP_DIR=$(find "$BACKUP_ROOT" -mindepth 2 -maxdepth 2 -type d | sort | tail -n 1)

if [ -z "$LATEST_BACKUP_DIR" ]; then
    echo "❌ No backup directories found."
    exit 1
fi

# Extract metadata from path
BACKUP_NAME=$(basename "$(dirname "$LATEST_BACKUP_DIR")")  # containername_imagename
DATE_NAME=$(basename "$LATEST_BACKUP_DIR")                 # YYYY-MM-DD_HH-MM

CONTAINER_NAME=$(echo "$BACKUP_NAME" | cut -d_ -f1)
IMAGE_NAME=$(echo "$BACKUP_NAME" | cut -d_ -f2)

echo "✅ Found latest backup for container: $CONTAINER_NAME (image: $IMAGE_NAME) at $DATE_NAME"

# Prepare temp restore dir
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Extract and restore each volume
for backup_file in "$LATEST_BACKUP_DIR"/*.tar.gz; do
    VOLUME_NAME=$(basename "$backup_file" | cut -d_ -f1)
    echo "📦 Restoring volume: $VOLUME_NAME"

    # Create volume
    docker volume create "$VOLUME_NAME" >/dev/null

    # Extract contents to temp
    mkdir -p "$TMP_DIR/$VOLUME_NAME"
    tar -xzf "$backup_file" -C "$TMP_DIR/$VOLUME_NAME"

    # Copy into Docker volume
    docker run --rm \
      -v "$VOLUME_NAME":/restore \
      -v "$TMP_DIR/$VOLUME_NAME":/from \
      alpine sh -c "cp -a /from/. /restore"
done

# Recreate the container
echo "🚀 Recreating container: $CONTAINER_NAME"
docker run -d --name "$CONTAINER_NAME" \
$(for vol in "$LATEST_BACKUP_DIR"/*.tar.gz; do
    VOLUME_NAME=$(basename "$vol" | cut -d_ -f1)
    echo "-v $VOLUME_NAME:/restore_$VOLUME_NAME"
done) \
"$IMAGE_NAME"

echo "✅ Container '$CONTAINER_NAME' with image '$IMAGE_NAME' restored from backup."

