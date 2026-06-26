#!/bin/bash
# =============================================================
#  Day 13 - Scheduled Scripts & Automation
# =============================================================
#  The real power of bash scripting is automation — running
#  scripts on a schedule, watching for events, and building
#  self-healing systems.
#
#  Tools:
#   cron      — time-based scheduler (classic)
#   systemd   — timers (modern alternative)
#   inotifywait — filesystem event watcher
#   at        — one-time scheduled jobs
# =============================================================

# ── Cron-Ready Script Template ────────────────────────────────
# Best practices for scripts run by cron:
# 1. Use full paths (cron has minimal $PATH)
# 2. Redirect stdout/stderr to a log file
# 3. Use flock/lockfile to prevent overlapping runs
# 4. Keep cron-friendly — no interactive prompts
# 5. Send alerts on failure

#!/usr/bin/env bash
# cron-safe header
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

SCRIPT_NAME="daily-backup"
LOG_FILE="/var/log/${SCRIPT_NAME}.log"
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"

# Prevent duplicate runs with flock
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "$(date): Already running, exiting." >> "$LOG_FILE"; exit 1; }

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }

log "=== $SCRIPT_NAME started ==="
# ... your logic here ...
log "=== $SCRIPT_NAME completed ==="

# ── Backup Automation Script ──────────────────────────────────
backup_system() {
    local SOURCE_DIRS=("/etc" "/home" "/var/www" "/opt/myapp")
    local BACKUP_ROOT="/backups"
    local DATE=$(date '+%Y-%m-%d')
    local BACKUP_DIR="$BACKUP_ROOT/$DATE"
    local RETENTION_DAYS=30

    mkdir -p "$BACKUP_DIR"
    local FAILED=0

    for dir in "${SOURCE_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_warn "Skipping $dir (not found)"
            continue
        fi

        local archive_name="${BACKUP_DIR}/$(echo "$dir" | tr '/' '_').tar.gz"
        log_info "Backing up $dir → $archive_name"

        if tar -czf "$archive_name" "$dir" 2>/dev/null; then
            local size=$(du -sh "$archive_name" | cut -f1)
            log_info "  OK: $size"
        else
            log_error "  FAILED: $dir"
            ((FAILED++))
        fi
    done

    # Clean up old backups
    find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null
    log_info "Cleanup: removed backups older than ${RETENTION_DAYS} days"

    log_info "Backup complete. Failed: $FAILED"
    return $FAILED
}

# ── Filesystem Watcher with inotifywait ──────────────────────
# Install: dnf install -y inotify-tools
watch_directory() {
    local watch_dir="$1"
    local action="${2:-echo}"

    if ! command -v inotifywait &>/dev/null; then
        echo "inotify-tools not installed. Run: dnf install -y inotify-tools"
        return 1
    fi

    echo "Watching $watch_dir for changes..."
    inotifywait -m -r \
        -e create -e modify -e delete -e moved_to \
        --format '%T %w%f %e' --timefmt '%Y-%m-%d %H:%M:%S' \
        "$watch_dir" | while read -r timestamp filepath event; do
            log_info "Event: $event | File: $filepath"
            case "$event" in
                CREATE|MOVED_TO)
                    # New file — trigger deploy or process it
                    log_info "New file detected: $filepath"
                    ;;
                DELETE)
                    log_warn "File deleted: $filepath"
                    ;;
            esac
        done
}

# ── Auto-Restart Failed Services ─────────────────────────────
watchdog() {
    local services=("nginx" "sshd" "firewalld")
    local check_interval=30

    log_info "Watchdog started. Monitoring: ${services[*]}"

    while true; do
        for service in "${services[@]}"; do
            if ! systemctl is-active --quiet "$service"; then
                log_error "Service $service is DOWN! Attempting restart..."
                systemctl restart "$service"
                if systemctl is-active --quiet "$service"; then
                    log_info "Service $service restarted successfully"
                    # send_slack "$SLACK_WEBHOOK" "⚠️ $service on $(hostname) was restarted"
                else
                    log_critical "Service $service FAILED to restart!"
                fi
            fi
        done
        sleep $check_interval
    done
}

# ── Crontab Setup Function ────────────────────────────────────
setup_cron_job() {
    local schedule="$1"
    local command="$2"
    local comment="${3:-Added by setup script}"
    local cron_entry="$schedule $command  # $comment"

    # Don't add duplicate entries
    if crontab -l 2>/dev/null | grep -qF "$command"; then
        echo "Cron job already exists: $command"
        return 0
    fi

    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    echo "Added cron job: $cron_entry"
}

# Add scheduled jobs
setup_cron_job "0 2 * * *"    "/usr/local/bin/daily-backup.sh >> /var/log/backup.log 2>&1"    "Daily backup"
setup_cron_job "*/5 * * * *"  "/usr/local/bin/health-check.sh >> /var/log/health.log 2>&1"    "Health check"
setup_cron_job "0 0 * * 0"    "/usr/local/bin/weekly-report.sh >> /var/log/report.log 2>&1"   "Weekly report"
setup_cron_job "@reboot"       "/usr/local/bin/startup.sh >> /var/log/startup.log 2>&1"        "Boot script"

crontab -l  # Verify all jobs
