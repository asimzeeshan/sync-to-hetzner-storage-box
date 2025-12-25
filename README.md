# sync-to-hetzner-storage-box

Sync cPanel weekly, monthly, and legacy backups to Hetzner Storage Box with bandwidth limiting, logging, and Slack notifications.

## Features

- **Bandwidth limiting** - 40% of 1Gbps (~50MB/s) to avoid saturating the connection
- **Per-sync logging** - Separate dated log files for each backup type
- **Slack notifications** - Success/failure messages with stats for each sync
- **Auto-cleanup** - Deletes logs older than 7 days

## Requirements

- rsync
- curl (for Slack notifications)
- SSH key configured for Hetzner Storage Box
- bc (for size formatting)

## Configuration

Edit the script to set your values:

```bash
STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"
STORAGE_BOX_PORT="23"
BWLIMIT="51200"  # KB/s (51200 = ~50MB/s = 40% of 1Gbps)
LOG_DIR="/var/log/backup-sync"
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/HERE"
```

## Backup Paths

| Type | Source | Destination |
|------|--------|-------------|
| Weekly | `/backups/weekly/` | `/home/weekly/` |
| Monthly | `/backups/monthly/` | `/home/monthly/` |
| Legacy | `/backups/legacy/` | `/home/legacy/` |

## Installation

```bash
# Copy script to server
scp sync2sb1.sh root@server:/root/

# Make executable
ssh root@server "chmod +x /root/sync2sb1.sh"

# Create log directory
ssh root@server "mkdir -p /var/log/backup-sync"
```

## Cron Setup

cPanel backups typically take ~22 hours. Schedule sync for the **next day**:

```bash
# Edit crontab
crontab -e

# Add these lines:
# Sync after Sunday weekly backup (run Monday 2 AM)
0 2 * * 1 /root/sync2sb1.sh

# Sync after 1st of month backup (run 2nd at 2 AM)
0 2 2 * * /root/sync2sb1.sh
```

## Log Files

Logs are stored with timestamps:

```
/var/log/backup-sync/weekly_2025-12-25_020015.log
/var/log/backup-sync/monthly_2025-12-25_022847.log
/var/log/backup-sync/legacy_2025-12-25_031522.log
```

Logs older than 7 days are automatically deleted on each run.

## Slack Notifications

Each sync posts a message:

```
✅ Weekly Backup Sync Completed on Dec 25, 2025
Destination: Hetzner Storage Box (SB-1)
Files: 470 total, 12 transferred
Size: 2.3T (transferred: 15.2G)
Duration: 45m 32s
Disk Available: 4.2T
Log: /var/log/backup-sync/weekly_2025-12-25_020015.log
```

On failure:

```
❌ Weekly Backup Sync FAILED on Dec 25, 2025
Destination: Hetzner Storage Box (SB-1)
Duration: 5m 12s
Exit Code: 12
Log: /var/log/backup-sync/weekly_2025-12-25_020015.log
Check log for error details.
```

## Manual Run

```bash
# Run manually
/root/sync2sb1.sh

# Check logs
tail -f /var/log/backup-sync/weekly_*.log
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
