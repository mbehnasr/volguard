# 🐳 Docker Volume Backup & Restore Tool

A simple and powerful Bash-based utility to **backup and restore Docker volumes and bind mounts**, supporting Docker Compose setups.

---

## ✨ Features

- 🔄 **Daily backups** of Docker volumes and bind mounts
- 💥 **Restore** from backups easily using an interactive CLI
- 🕰️ **Retention policy** (configurable)
- 🛠️ **Supports Docker Compose**
- 📦 Supports **named volumes** and **bind mounts**
- ☁️ Optional **remote sync** via SSH
- 📃 Generates a `manifest.json` per backup
- 🧩 Customizable via `config.json` and `.env`

---

## 🧰 Requirements

- Docker 🐳
- Bash (tested on v5+)
- `jq`, `tar`, `gzip`, `base64`, `cut`, `find`, `date`
- Optional: `sshpass` (if using remote sync with password)

---

## 🛠️ Configuration

### 1️⃣ `config.json`

```json
{
  "backup_root": "/var/log/docker-volume-backup/backups",
  "retention_days": 7,
  "remote_sync": false
}
```

- `backup_root`: Directory where all backups will be stored.
- `retention_days`: How many days to keep backups.
- `remote_sync`: Set `true` to enable syncing to remote server.

---

### 2️⃣ `.env` (for remote sync)

```ini
REMOTE_USER=youruser
REMOTE_HOST=backup.example.com
REMOTE_PATH=/home/youruser/backups
REMOTE_PASSWORD=yourpassword  # Optional, safer if using SSH key instead
```

Used when `remote_sync` is enabled in `config.json`.

---

## 📦 Backup Script

Run the backup script manually or set it in a cron job.

```bash
./backup.sh
```

It will:

1. Identify all running containers.
2. Detect all mounted volumes (named or bind).
3. Create compressed `.tar.gz` files.
4. Generate a `manifest.json` for mapping.
5. Enforce retention policy.
6. Optionally sync to remote server.

---

## 🔁 Restore Script

Run to restore from a specific backup timestamp.

```bash
./restore.sh               # Interactive mode
./restore.sh 2025-05-25_23-41-29   # Restore specific timestamp
```

The script will:

- Parse the `manifest.json`
- Recreate volumes if missing
- Restore volume or bind data to correct paths

---

## 📂 Backup Structure

```
backups/
└── 2025-05-25_23-41-29/
    ├── manifest.json
    ├── container-name
        └── VOL___volume-name___container-name___timestamp.tar.gz
```

---

## 🧪 Example Cron Job

Edit crontab with `crontab -e`:

```bash
0 1 * * * /path/to/backup.sh >> /var/log/docker-backup.log 2>&1
```

---

## 📥 Restore from Remote

Ensure SSH keys or `.env` with password is set. Place the selected backup timestamp folder inside your `backup_root`, then run:

```bash
./restore.sh
```

---

## 🛡️ Notes

- For security, SSH keys are preferred over passwords.
- Bind mount paths will be decoded and restored to their original locations.
- Make sure you have permissions to write to those locations.

---

## 🤝 Contribution

PRs and suggestions are welcome. Fork and start hacking! 🔧

---

## 📜 License

MIT © 2025

---

## 📞 Contact

For support or contributions, open an issue or create a PR.