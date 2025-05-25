# 🐳 docker-volume-backup

## Requirements

To use this script, ensure the following tools are installed on your host system:

- `docker`: To manage containers and volumes.
- `jq`: To parse JSON configuration files.
- `rsync`: For syncing backups to a remote server.
- `sshpass` *(optional)*: If you are not using SSH key authentication, `sshpass` is used to pass the password non-interactively.
- `bash`: The script is written in Bash and must be run in a compatible shell.

Make sure your system has proper permissions to access Docker and SSH.


A flexible, automated backup and restore solution for Docker **volumes** and **bind mounts**. It supports daily backups, retention policies, and optional syncing to a remote server — using either SSH key or password-based login.

## 📦 Features

- Backup all Docker volumes, including named volumes and bind mounts
- Organize backups by container name and image
- Automated retention: delete backups older than 7 days
- Optional syncing to a remote backup server using `rsync`
- Uses `.env` and `config.json` for configuration
- SSH key detection or fallback to password using `sshpass`

## 📁 Directory Structure

```
docker-volume-backup/
├── backup.sh
├── restore.sh
├── .env
├── config.json
├── backups/
└── README.md
```

## ⚙️ Configuration

### `.env`

Stores credentials and remote host information:

```env
REMOTE_USER=username
REMOTE_HOST=remote.server.com
REMOTE_PASSWORD=your_password_here
REMOTE_BACKUP_DIR=/home/username/remote_backups
```

> 💡 If using SSH keys, `REMOTE_PASSWORD` is not needed.

### `config.json`

```json
{
  "backup_time": "01:00",
  "backup_root": "/home/youruser/docker-volume-backup/backups",
  "retention_days": 7,
  "sync_enabled": true
}
```

## 🛠️ Scripts

### `backup.sh`

- Reads `.env` and `config.json`
- Detects and backs up all containers' volumes/bind mounts
- Names backups using: `volumeName_containerName_imageName_date.tar.gz`
- Syncs to remote server using SSH or `sshpass` if password provided

### `restore.sh`

- Restores backup into Docker volume
- Run with:
  ```bash
  ./restore.sh <backup_file.tar.gz> <volume_name>
  ```

## 🔐 SSH Key or Password

- If `~/.ssh/id_rsa` exists, will use it for remote sync
- Else uses `sshpass` with `REMOTE_PASSWORD` from `.env`
- If `sshpass` not installed, you will be prompted

## 📅 Cron Job (Optional)

To schedule daily backups:

```bash
0 1 * * * /bin/bash /home/youruser/docker-volume-backup/backup.sh >> /var/log/docker_backup.log 2>&1
```

## 🔄 Restore Instructions

1. Recreate Docker volumes (if not existing)
2. Run `restore.sh` with backup archive and volume name
3. Start container with restored volumes

## 🙌 Credits

Built with ❤️ by [Your Name](https://github.com/yourusername)