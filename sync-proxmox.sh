#!/bin/bash
#
# sync-proxmox.sh - Sync Proxmox vzdump backups to Hetzner Storage Box
# Author: Asim Zeeshan
# Created: 2025-12-26
#

set -uo pipefail

# =============================================================================
# CONFIGURATION - Edit these values for your environment
# =============================================================================
STORAGE_BOX="uXXXXXX-subX@uXXXXXX-subX.your-storagebox.de"
STORAGE_BOX_PORT="23"
SOURCE_DIR="/var/lib/vz/dump/"
DEST_DIR="/home/dump/"
BWLIMIT="51200"  # KB/s (51200 = ~50MB/s = 40% of 1Gbps)
LOG_DIR="/var/log/backup-sync"
SLACK_WEBHOOK=""  # Leave empty to disable Slack notifications
# =============================================================================

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
HOSTNAME=$(hostname)

# Create log dir and clean up logs older than 7 days
mkdir -p "${LOG_DIR}"
find "${LOG_DIR}" -name "*.log" -mtime +7 -delete 2>/dev/null || true

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

send_slack() {
    local message="$1"
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK" >/dev/null 2>&1
    fi
}

sync_backup() {
    local log="${LOG_DIR}/vzdump_${TIMESTAMP}.log"
    local start_time=$(date +%s)

    echo "=== Proxmox vzdump sync started $(date) ===" >> "$log"
    echo "Host: ${HOSTNAME}" >> "$log"
    echo "Source: ${SOURCE_DIR}" >> "$log"
    echo "Destination: ${STORAGE_BOX}:${DEST_DIR}" >> "$log"

    if [ ! -d "$SOURCE_DIR" ]; then
        echo "ERROR: Source not found: $SOURCE_DIR" >> "$log"
        send_slack ":x: *Proxmox Backup Sync Failed* on ${HOSTNAME} ($(date '+%b %d, %Y'))\nSource not found: \`$SOURCE_DIR\`"
        return 1
    fi

    local file_count=$(find "$SOURCE_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    local total_size=$(du -sb "$SOURCE_DIR" 2>/dev/null | cut -f1)

    rsync -avz --bwlimit="$BWLIMIT" --stats --delete-after \
        -e "ssh -p $STORAGE_BOX_PORT" \
        "$SOURCE_DIR" "${STORAGE_BOX}:${DEST_DIR}" >> "$log" 2>&1
    local rc=$?

    local duration=$(($(date +%s) - start_time))
    local transferred=$(grep -oP 'Number of regular files transferred: \K\d+' "$log" 2>/dev/null | tail -1 || echo "0")
    local remote_avail=$(ssh -p "$STORAGE_BOX_PORT" "$STORAGE_BOX" "df -h /home 2>/dev/null | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "N/A")

    if [ $rc -eq 0 ]; then
        send_slack ":white_check_mark: *Proxmox Backup Sync Completed* on ${HOSTNAME} ($(date '+%b %d, %Y'))\n*Source:* ${SOURCE_DIR}\n*Destination:* Hetzner Storage Box\n*Files:* ${file_count} total, ${transferred} transferred\n*Size:* $(format_size $total_size)\n*Duration:* $(format_duration $duration)\n*Disk Available:* ${remote_avail}\n*Log:* \`$log\`"
    else
        send_slack ":x: *Proxmox Backup Sync FAILED* on ${HOSTNAME} ($(date '+%b %d, %Y'))\n*Source:* ${SOURCE_DIR}\n*Destination:* Hetzner Storage Box\n*Duration:* $(format_duration $duration)\n*Exit Code:* ${rc}\n*Log:* \`$log\`"
    fi

    return $rc
}

# Run sync
sync_backup
