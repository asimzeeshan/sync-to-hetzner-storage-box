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
- **Hostname detection** - Each server identifies itself automatically in notifications

## Requirements

- rsync
- curl (for Slack notifications)
- SSH key configured for Hetzner Storage Box
- bc (for size formatting)

## Configuration

Edit the configuration section at the top of each script:

```bash
# =============================================================================
# CONFIGURATION - Edit these values for your environment
# =============================================================================
STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"
STORAGE_BOX_PORT="23"
SOURCE_DIR="/var/lib/vz/dump/"   # sync-proxmox.sh only
DEST_DIR="/home/dump/"           # sync-proxmox.sh only
BWLIMIT="51200"                  # KB/s (51200 = ~50MB/s)
LOG_DIR="/var/log/backup-sync"
SLACK_WEBHOOK=""                 # Leave empty to disable
# =============================================================================
```

---

## Proxmox Installation

```bash
# Clone repo
cd /root
git clone https://github.com/asimzeeshan/sync-to-hetzner-storage-box.git

# Copy script
cp sync-to-hetzner-storage-box/sync-proxmox.sh /root/

# Edit configuration
vi /root/sync-proxmox.sh

# Make executable
chmod +x /root/sync-proxmox.sh

# Add to crontab (runs at 1:00 and 13:00)
(crontab -l 2>/dev/null; echo "0 1,13 * * * /root/sync-proxmox.sh") | crontab -
```

---

## cPanel Installation

```bash
# Clone repo
cd /root
git clone https://github.com/asimzeeshan/sync-to-hetzner-storage-box.git

# Copy script
cp sync-to-hetzner-storage-box/sync-cpanel.sh /root/

# Edit configuration
vi /root/sync-cpanel.sh

# Make executable
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

---

## Cron Examples

```bash
# Proxmox: Sync twice daily
0 1,13 * * * /root/sync-proxmox.sh

# cPanel: Sync after weekly backup (Monday 2 AM)
0 2 * * 1 /root/sync-cpanel.sh

# cPanel: Sync after 1st of month backup (2nd at 2 AM)
0 2 2 * * /root/sync-cpanel.sh
```

## Log Files

Logs are stored with timestamps:

```
/var/log/backup-sync/vzdump_2025-12-26_010015.log    # Proxmox
/var/log/backup-sync/weekly_2025-12-25_020015.log    # cPanel
```

Logs older than 7 days are automatically deleted.

## Slack Notifications

Success:
```
Proxmox Backup Sync Completed on pm05 (Dec 26, 2025)
Source: /var/lib/vz/dump/
Destination: Hetzner Storage Box
Files: 423 total, 6 transferred
Size: 457.2G
Duration: 5m 32s
Disk Available: 2.2T
Log: /var/log/backup-sync/vzdump_2025-12-26_010015.log
```

Failure:
```
Proxmox Backup Sync FAILED on pm05 (Dec 26, 2025)
Source: /var/lib/vz/dump/
Destination: Hetzner Storage Box
Duration: 2m 12s
Exit Code: 12
Log: /var/log/backup-sync/vzdump_2025-12-26_010015.log
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
