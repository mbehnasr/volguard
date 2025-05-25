#!/bin/bash

set -euo pipefail

CONFIG_FILE="./config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ config.json not found!"
    exit 1
fi

# Read backup root directory from config.json
BACKUP_ROOT=$(jq -r '.backup_root' "$CONFIG_FILE")

if [[ ! -d "$BACKUP_ROOT" ]]; then
    echo "❌ Backup root directory '$BACKUP_ROOT' does not exist!"
    exit 1
fi

# Function to list available backups sorted by date descending
list_backups() {
    mapfile -t backups < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -r)
    if (( ${#backups[@]} == 0 )); then
        echo "❌ No backups found in $BACKUP_ROOT"
        exit 1
    fi

    echo "📦 Available backups:"
    local i=1
    for b in "${backups[@]}"; do
        echo "$i) $b"
        ((i++))
    done
}

# Select backup to restore
if [[ $# -ge 1 ]]; then
    SELECTED_BACKUP="$1"
    # Verify it exists
    if [[ ! -d "$BACKUP_ROOT/$SELECTED_BACKUP" ]]; then
        echo "❌ Backup '$SELECTED_BACKUP' does not exist in $BACKUP_ROOT"
        exit 1
    fi
else
    # No argument passed, select latest backup by default
    mapfile -t backups < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -r)
    if (( ${#backups[@]} == 0 )); then
        echo "❌ No backups found in $BACKUP_ROOT"
        exit 1
    fi
    SELECTED_BACKUP="${backups[0]}"
fi

echo "✅ Selected backup: $SELECTED_BACKUP"

BACKUP_DIR="$BACKUP_ROOT/$SELECTED_BACKUP"
MANIFEST="$BACKUP_DIR/manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
    echo "❌ Manifest file not found: $MANIFEST"
    exit 1
fi

# Read manifest as JSON array and validate
if ! jq empty "$MANIFEST" 2>/dev/null; then
    echo "❌ Manifest file is not a valid JSON array: $MANIFEST"
    exit 1
fi

# List containers in backup (unique container names)
containers=$(jq -r '.[].container' "$MANIFEST" | sort -u)
echo "📦 Containers in backup:"
echo "$containers"

echo "🔄 Starting restore..."

jq -c '.[]' "$MANIFEST" | while read -r item; do
    container=$(jq -r '.container' <<< "$item")
    type=$(jq -r '.type' <<< "$item")

    if [[ "$type" == "volume" ]]; then
        volume=$(jq -r '.volume' <<< "$item")
        file=$(jq -r '.file' <<< "$item")

        echo "🔧 Restoring volume '$volume' from file '$file'..."

        # Check if volume exists, create if not
        if ! docker volume inspect "$volume" &>/dev/null; then
            echo "ℹ️  Volume '$volume' does not exist. Creating it..."
            docker volume create "$volume"
        else
            echo "ℹ️  Volume '$volume' exists, skipping creation."
        fi

        # Extract backup to volume
        if [[ ! -f "$BACKUP_DIR/$container/$file" ]]; then
            echo "❌ Backup file not found: $BACKUP_DIR/$container/$file"
            exit 1
        fi

        docker run --rm -v "$volume":/data -v "$BACKUP_DIR/$container":/backup alpine sh -c "cd /data && tar -xzf /backup/$file"
        echo "✅ Volume '$volume' restored."

    elif [[ "$type" == "bind" ]]; then
        source_encoded=$(jq -r '.source' <<< "$item")
        file=$(jq -r '.file' <<< "$item")

        # Decode base64 encoded source path
        source_path=$(echo -n "$source_encoded" | base64 -d)

        echo "🔧 Restoring bind mount from '$source_path' using file '$file'..."

        if [[ ! -f "$BACKUP_DIR/$container/$file" ]]; then
            echo "❌ Backup file not found: $BACKUP_DIR/$container/$file"
            exit 1
        fi

        # Create directory if doesn't exist
        if [[ ! -d "$source_path" ]]; then
            echo "⚠️  Bind mount directory '$source_path' does not exist. Creating it..."
            mkdir -p "$source_path"
        else
            echo "ℹ️  Bind mount directory '$source_path' exists."
        fi

        # Extract backup to bind mount path
        tar -xzf "$BACKUP_DIR/$container/$file" -C "$source_path"
        echo "✅ Bind mount restored at '$source_path'."

    else
        echo "⚠️  Unknown type '$type' in manifest, skipping..."
    fi

done

echo "🎉 Restore completed successfully!"

