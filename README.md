# volguard - Docker Volume Backup Script

A simple, automated script to back up all Docker volumes on a host server every day at 1 AM, with optional remote syncing and 7-day retention.

## 📦 Features

- Automatically discovers and backs up **all named Docker volumes**
- Stores backups in `~/docker-volume-backup/backups/`
- Creates organized directories: `containername_imagename/`
- Uses cron to run daily at **1 AM**
- Keeps **7 days** of backups (older ones are removed)
- Optionally **syncs** backups to a remote server via `rsync`
- Interactive CLI with logs shown live

## 🛠️ Requirements

- Docker
- rsync
- Bash
- (optional) SSH key for remote syncing

## 🚀 Installation

```bash
git clone https://github.com/yourname/docker-volume-backup.git
cd docker-volume-backup
chmod +x docker_volume_backup.sh

