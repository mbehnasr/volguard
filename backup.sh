#!/bin/bash
set -euo pipefail

CONFIG_FILE="./config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ config.json not found! Please create it with a 'backup_root' field."
  exit 1
fi

BACKUP_ROOT=$(jq -r '.backup_root' "$CONFIG_FILE")

if [[ -z "$BACKUP_ROOT" ]]; then
  echo "❌ 'backup_root' is empty in config.json"
  exit 1
fi

mkdir -p "$BACKUP_ROOT"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

echo "📦 Starting backup at $TIMESTAMP"
manifest_items=()

containers=$(docker ps --format '{{.Names}}')

if [[ -z "$containers" ]]; then
  echo "⚠️ No running containers found, nothing to backup."
  exit 0
fi

for container in $containers; do
  echo "🚀 Backing up container: $container"

  CONTAINER_DIR="$BACKUP_DIR/$container"
  mkdir -p "$CONTAINER_DIR"

  # Backup volumes
  volumes=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}')

  for volume in $volumes; do
    backup_file="VOL___${volume}___${container}___${TIMESTAMP}.tar.gz"
    echo "   📦 Backing up volume '$volume'..."

    docker run --rm -v "${volume}":/data -v "$CONTAINER_DIR":/backup alpine \
      sh -c "cd /data && tar czf /backup/$backup_file ."

    destination=$(docker inspect "$container" --format "{{range .Mounts}}{{if eq .Name \"$volume\"}}{{.Destination}}{{end}}{{end}}")

    manifest_items+=("{
  \"container\": \"$container\",
  \"type\": \"volume\",
  \"volume\": \"$volume\",
  \"destination\": \"$destination\",
  \"file\": \"$backup_file\"
}")
  done

  # Backup bind mounts
  binds=$(docker inspect "$container" --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}} {{end}}{{end}}')

  for bind in $binds; do
    source_b64=$(echo -n "$bind" | base64 | tr -d '\n')
    backup_file="BIND___${source_b64}___${container}___${TIMESTAMP}.tar.gz"
    echo "   🔗 Backing up bind mount '$bind'..."

    # Create parent directory for tar to avoid including full path
    parent_dir=$(dirname "$bind")
    base_name=$(basename "$bind")

    # Ensure the source directory exists
    if [[ ! -d "$bind" && ! -f "$bind" ]]; then
      echo "⚠️ Source path '$bind' does not exist, skipping..."
      continue
    fi

    tar czf "$CONTAINER_DIR/$backup_file" -C "$parent_dir" "$base_name"

    destination=$(docker inspect "$container" --format "{{range .Mounts}}{{if eq .Source \"$bind\"}}{{.Destination}}{{end}}{{end}}")

    manifest_items+=("{
  \"container\": \"$container\",
  \"type\": \"bind\",
  \"source\": \"$source_b64\",
  \"destination\": \"$destination\",
  \"file\": \"$backup_file\"
}")
  done
done

# Write manifest.json with proper JSON array syntax
manifest_json="["
manifest_json+=$(IFS=,; echo "${manifest_items[*]}")
manifest_json+="]"

echo -e "$manifest_json" > "$BACKUP_DIR/manifest.json"

echo "✅ Backup completed successfully!"
echo "📦 Manifest file saved at: $BACKUP_DIR/manifest.json"

