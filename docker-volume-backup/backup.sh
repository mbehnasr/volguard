#!/bin/bash

# === Configuration ===
BASE_DIR="$HOME/docker-volume-backup"
BACKUP_ROOT="$BASE_DIR/backups"
LOGFILE="$BASE_DIR/backup.log"
DATE=$(date +"%Y-%m-%d_%H-%M")
RETENTION_DAYS=7

mkdir -p "$BACKUP_ROOT"
echo "[$(date)] Starting container-based Docker volume backups..."

containers=$(docker ps -a -q)

for container_id in $containers; do
    cname=$(docker inspect --format='{{.Name}}' "$container_id" | cut -c2-)
    image=$(docker inspect --format='{{.Config.Image}}' "$container_id")
    safe_image="${image//\//-}"  # filesystem safe
    dir_name="${cname}_${safe_image}"
    container_dir="$BACKUP_ROOT/$dir_name/$DATE"

    mkdir -p "$container_dir"

    echo "[*] Backing up container: $cname (image: $image)"
    echo "    └ Saving to: $container_dir"

    mounts=$(docker inspect --format='{{json .Mounts}}' "$container_id")
    manifest_file="$container_dir/${cname}_${DATE}_manifest.json"
    echo "$mounts" | jq '.' > "$manifest_file"

    volume_names=$(echo "$mounts" | jq -r '.[] | select(.Type=="volume") | .Name')

    for vol in $volume_names; do
        filename="${vol}_${cname}_${safe_image}_${DATE}.tar.gz"
        echo "    • Backing up volume: $vol → $filename"

        docker run --rm \
            -v "$vol":/volume \
            -v "$container_dir":/backup \
            alpine \
            sh -c "tar czf /backup/$filename -C /volume ." \
            >> "$LOGFILE" 2>&1

        echo "      ✔ Done"
    done

    # Retention cleanup
    echo "    • Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_ROOT/$dir_name" -mindepth 1 -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
done


# === Remote sync ===
echo ""
read -p "Do you want to sync backups to a remote server now? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    read -p "Enter remote username: " remote_user
    read -p "Enter remote host (IP or hostname): " remote_host
    read -p "Enter remote backup directory path (e.g., /home/user/backups): " remote_dir

    full_path="${remote_user}@${remote_host}:${remote_dir}"

    echo "[*] Checking for SSH key authentication to $remote_user@$remote_host..."
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "${remote_user}@${remote_host}" "exit" 2>/dev/null; then
        echo "    ✔ SSH key authentication is available."
    else
        echo "    ⚠ No SSH key found. You will be prompted for a password during sync."
    fi

    echo "[*] Syncing local backup ($BACKUP_ROOT) to $full_path ..."
    rsync -av --delete "$BACKUP_ROOT/" "$full_path"
    echo "    ✔ Remote sync complete."
fi

echo "[$(date)] Backup completed."

