#!/bin/bash
#
# sync2sb1.sh - Sync cPanel backups to Hetzner Storage Box (SB-1)
# Author: Asim Zeeshan
# Created: 2025-12-25
#

set -uo pipefail

# Configuration - UPDATE THESE VALUES
STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"
STORAGE_BOX_PORT="23"
BWLIMIT="51200"  # 40% of 1Gbps = ~50MB/s
LOG_DIR="/var/log/backup-sync"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-https://hooks.slack.com/services/YOUR/WEBHOOK/HERE}"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# Create log dir and clean up logs older than 7 days
mkdir -p "${LOG_DIR}"
find "${LOG_DIR}" -name "*.log" -mtime +7 -delete

format_duration() {
    local s=$1
    printf "%dm %ds" $((s/60)) $((s%60))
}

format_size() {
    local b=$1
    [ -z "$b" ] || [ "$b" = "0" ] && echo "0B" && return
    [ "$b" -ge 1073741824 ] && printf "%.1fG" $(echo "scale=1;$b/1073741824"|bc) && return
    [ "$b" -ge 1048576 ] && printf "%.1fM" $(echo "scale=1;$b/1048576"|bc) && return
    printf "%.1fK" $(echo "scale=1;$b/1024"|bc)
}

sync_backup() {
    local type=$1 src=$2
    local log="${LOG_DIR}/${type}_${TIMESTAMP}.log"
    local start_time=$(date +%s)

    echo "=== ${type} backup sync started $(date) ===" >> "$log"

    if [ ! -d "$src" ]; then
        echo "ERROR: Source not found: $src" >> "$log"
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\":x: *${type^} Backup Sync Failed* on $(date '+%b %d, %Y')\nSource not found: \`$src\`\"}" \
            "$SLACK_WEBHOOK" >/dev/null 2>&1
        return 1
    fi

    local file_count=$(find "$src" -type f 2>/dev/null | wc -l | tr -d ' ')
    local total_size=$(du -sb "$src" 2>/dev/null | cut -f1)

    rsync -avz --bwlimit="$BWLIMIT" --stats --delete-after \
        -e "ssh -p $STORAGE_BOX_PORT" \
        "$src" "${STORAGE_BOX}:/home/${type}/" >> "$log" 2>&1
    local rc=$?

    local duration=$(($(date +%s) - start_time))
    local transferred=$(grep -oP 'Number of regular files transferred: \K\d+' "$log" 2>/dev/null | tail -1 || echo "0")
    local remote_avail=$(ssh -p "$STORAGE_BOX_PORT" "$STORAGE_BOX" "df -h /home 2>/dev/null | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "N/A")

    if [ $rc -eq 0 ]; then
        curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\":white_check_mark: *${type^} Backup Sync Completed* on $(date '+%b %d, %Y')\n*Destination:* Hetzner Storage Box (SB-1)\n*Files:* ${file_count} total, ${transferred} transferred\n*Size:* $(format_size $total_size)\n*Duration:* $(format_duration $duration)\n*Disk Available:* ${remote_avail}\n*Log:* \`$log\`\"}" "$SLACK_WEBHOOK" >/dev/null 2>&1
    else
        curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\":x: *${type^} Backup Sync FAILED* on $(date '+%b %d, %Y')\n*Destination:* Hetzner Storage Box (SB-1)\n*Duration:* $(format_duration $duration)\n*Log:* \`$log\`\"}" "$SLACK_WEBHOOK" >/dev/null 2>&1
    fi

    return $rc
}

# Run all 3 syncs
sync_backup "weekly"  "/backups/weekly/"
sync_backup "monthly" "/backups/monthly/"
sync_backup "legacy"  "/backups/legacy/"
