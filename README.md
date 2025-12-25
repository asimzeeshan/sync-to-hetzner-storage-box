# sync-to-hetzner-storage-box

Sync backups to Hetzner Storage Box with bandwidth limiting, logging, and Slack notifications.

## Scripts

| Script | Use Case | Default Source |
|--------|----------|----------------|
| `sync-cpanel.sh` | cPanel backups (weekly, monthly, legacy) | `/backups/weekly/`, `/backups/monthly/`, `/backups/legacy/` |
| `sync-proxmox.sh` | Proxmox VE vzdump backups | `/var/lib/vz/dump/` |

## Features

- **Bandwidth limiting** - 40% of 1Gbps (~50MB/s) to avoid saturating the connection
- **Per-sync logging** - Separate dated log files
- **Slack notifications** - Success/failure messages with stats (optional)
- **Auto-cleanup** - Deletes logs older than 7 days
- **Environment variables** - Configure without editing scripts
- **Hostname detection** - Each server identifies itself automatically in Slack messages

## Requirements

- rsync
- curl (for Slack notifications)
- SSH key configured for Hetzner Storage Box
- bc (for size formatting)

## Configuration

All scripts support environment variables for configuration:

```bash
# Required
export STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"

# Optional - for Slack notifications
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/HERE"

# Optional (with defaults)
export STORAGE_BOX_PORT="23"
export SOURCE_DIR="/var/lib/vz/dump/"  # for sync-proxmox.sh only
export DEST_DIR="/home/dump/"          # for sync-proxmox.sh only
export BWLIMIT="51200"                 # KB/s (51200 = ~50MB/s)
export LOG_DIR="/var/log/backup-sync"
```

---

## Proxmox Installation

```bash
# Clone repo
cd /root
git clone https://github.com/asimzeeshan/sync-to-hetzner-storage-box.git

# Create wrapper script with your config
cat > /root/sync-proxmox.sh << 'EOF'
#!/bin/bash
export STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"
export SOURCE_DIR="/var/lib/vz/dump/"
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/HERE"
exec /root/sync-to-hetzner-storage-box/sync-proxmox.sh
EOF
chmod +x /root/sync-proxmox.sh

# Add to crontab (runs at 1:00 and 13:00)
(crontab -l 2>/dev/null; echo "0 1,13 * * * /root/sync-proxmox.sh") | crontab -
```

### Proxmox Cron Examples

```bash
# Sync twice daily
0 1,13 * * * /root/sync-proxmox.sh

# Sync once daily at 2 AM
0 2 * * * /root/sync-proxmox.sh
```

---

## cPanel Installation

```bash
# Clone repo
cd /root
git clone https://github.com/asimzeeshan/sync-to-hetzner-storage-box.git

# Create wrapper script with your config
cat > /root/sync-cpanel.sh << 'EOF'
#!/bin/bash
export STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/HERE"
exec /root/sync-to-hetzner-storage-box/sync-cpanel.sh
EOF
chmod +x /root/sync-cpanel.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * 1 /root/sync-cpanel.sh") | crontab -
```

### cPanel Backup Paths

| Type | Source | Destination |
|------|--------|-------------|
| Weekly | `/backups/weekly/` | `/home/weekly/` |
| Monthly | `/backups/monthly/` | `/home/monthly/` |
| Legacy | `/backups/legacy/` | `/home/legacy/` |

### cPanel Cron Examples

cPanel backups typically take ~22 hours. Schedule sync for the **next day**:

```bash
# Sync after Sunday weekly backup (run Monday 2 AM)
0 2 * * 1 /root/sync-cpanel.sh

# Sync after 1st of month backup (run 2nd at 2 AM)
0 2 2 * * /root/sync-cpanel.sh
```

---

## Log Files

Logs are stored with timestamps:

```
/var/log/backup-sync/vzdump_2025-12-26_010015.log    # Proxmox
/var/log/backup-sync/weekly_2025-12-25_020015.log    # cPanel weekly
/var/log/backup-sync/monthly_2025-12-25_022847.log   # cPanel monthly
```

Logs older than 7 days are automatically deleted.

## Slack Notifications

Success (Proxmox):
```
✅ Proxmox Backup Sync Completed on pm05 (Dec 26, 2025)
Source: /var/lib/vz/dump/
Destination: Hetzner Storage Box
Files: 423 total, 6 transferred
Size: 457.2G
Duration: 5m 32s
Disk Available: 2.2T
Log: /var/log/backup-sync/vzdump_2025-12-26_010015.log
```

Success (cPanel):
```
✅ Weekly Backup Sync Completed on serene (Dec 25, 2025)
Destination: Hetzner Storage Box
Files: 470 total, 12 transferred
Size: 2.3T
Duration: 45m 32s
Disk Available: 4.2T
Log: /var/log/backup-sync/weekly_2025-12-25_020015.log
```

Failure:
```
❌ Proxmox Backup Sync FAILED on pm05 (Dec 26, 2025)
Source: /var/lib/vz/dump/
Destination: Hetzner Storage Box
Duration: 2m 12s
Exit Code: 12
Log: /var/log/backup-sync/vzdump_2025-12-26_010015.log
```

## Manual Run

```bash
# Proxmox
/root/sync-proxmox.sh

# cPanel
/root/sync-cpanel.sh

# Check logs
tail -f /var/log/backup-sync/*.log
```

## Bandwidth Calculation

| Percentage | Speed | BWLIMIT value |
|------------|-------|---------------|
| 100% | 125 MB/s | 128000 |
| 50% | 62.5 MB/s | 64000 |
| 40% | 50 MB/s | 51200 |
| 25% | 31.25 MB/s | 32000 |

## Author

[Asim Zeeshan](https://www.linkedin.com/in/asimzeeshan/)

## License

[MIT](LICENSE)
