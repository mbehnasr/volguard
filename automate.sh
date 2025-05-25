(crontab -l 2>/dev/null; echo "0 1 * * * $HOME/docker-volume-backup/docker_volume_backup.sh") | crontab -
