#!/bin/bash
# =============================================================
#  Day 12 - Logging & Monitoring in Bash Scripts
# =============================================================
#  Good scripts log everything — what they did, when, and
#  whether it succeeded. Logs are your audit trail and your
#  first tool when troubleshooting failures.
#
#  Levels: DEBUG < INFO < WARN < ERROR < CRITICAL
#  Output: stdout (info), stderr (errors), file (persistent)
# =============================================================

# ── Complete Logging Library ──────────────────────────────────
LOG_FILE="${LOG_FILE:-/var/log/myapp/script.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"   # DEBUG, INFO, WARN, ERROR, CRITICAL
VERBOSE="${VERBOSE:-false}"

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [CRITICAL]=4)
CURRENT_LEVEL=${LOG_LEVELS[$LOG_LEVEL]:-1}

# Colors
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

_log() {
    local level="$1"; shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg_level=${LOG_LEVELS[$level]:-1}

    [[ $msg_level -lt $CURRENT_LEVEL ]] && return

    local color=""
    case "$level" in
        DEBUG)    color="$CYAN" ;;
        INFO)     color="$GREEN" ;;
        WARN)     color="$YELLOW" ;;
        ERROR)    color="$RED" ;;
        CRITICAL) color="$RED" ;;
    esac

    local formatted="[$timestamp] [$level] $message"

    # Write to file
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$formatted" >> "$LOG_FILE"

    # Write to stdout/stderr with color
    if [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
        echo -e "${color}${formatted}${NC}" >&2
    else
        echo -e "${color}${formatted}${NC}"
    fi
}

log_debug()    { _log "DEBUG"    "$@"; }
log_info()     { _log "INFO"     "$@"; }
log_warn()     { _log "WARN"     "$@"; }
log_error()    { _log "ERROR"    "$@"; }
log_critical() { _log "CRITICAL" "$@"; exit 1; }

# Usage
log_info    "Script started: $0"
log_debug   "Debug mode: $VERBOSE"
log_warn    "Low memory detected"
log_error   "Failed to connect to database"

# ── Log Rotation in Script ────────────────────────────────────
rotate_log() {
    local logfile="$1"
    local max_size_mb="${2:-10}"
    local max_backups="${3:-5}"

    [[ ! -f "$logfile" ]] && return

    local size_bytes=$(stat -c%s "$logfile")
    local size_mb=$((size_bytes / 1024 / 1024))

    if [[ $size_mb -ge $max_size_mb ]]; then
        log_info "Rotating log: $logfile (${size_mb}MB)"
        for i in $(seq $((max_backups-1)) -1 1); do
            [[ -f "${logfile}.${i}" ]] && mv "${logfile}.${i}" "${logfile}.$((i+1))"
        done
        mv "$logfile" "${logfile}.1"
        gzip "${logfile}.1"
        touch "$logfile"
        log_info "Log rotated successfully"
    fi
}

# ── System Monitoring Script ──────────────────────────────────
monitor_system() {
    local report_file="/tmp/system-report-$(date +%Y%m%d-%H%M%S).txt"

    {
        echo "============================================"
        echo " System Health Report"
        echo " Generated: $(date)"
        echo " Host: $(hostname) ($(hostname -I | awk '{print $1}'))"
        echo "============================================"

        echo ""
        echo "── Uptime ──────────────────────────────────"
        uptime

        echo ""
        echo "── CPU ─────────────────────────────────────"
        top -bn1 | grep -E "^(%Cpu|Cpu)"
        echo "Load average: $(cat /proc/loadavg)"

        echo ""
        echo "── Memory ──────────────────────────────────"
        free -h

        echo ""
        echo "── Disk ────────────────────────────────────"
        df -hT | grep -v tmpfs

        echo ""
        echo "── Top Processes (CPU) ─────────────────────"
        ps aux --sort=-%cpu | head -6

        echo ""
        echo "── Top Processes (Memory) ──────────────────"
        ps aux --sort=-%mem | head -6

        echo ""
        echo "── Network ─────────────────────────────────"
        ip -br addr

        echo ""
        echo "── Listening Ports ─────────────────────────"
        ss -tuln

        echo ""
        echo "── Failed Services ─────────────────────────"
        systemctl list-units --failed --no-legend

        echo ""
        echo "── Last 20 Errors in /var/log/messages ─────"
        grep -i "error\|critical\|fail" /var/log/messages 2>/dev/null | tail -20

    } | tee "$report_file"

    log_info "Report saved: $report_file"
    echo "$report_file"
}

# ── Alerting Thresholds ───────────────────────────────────────
check_thresholds() {
    local cpu_warn=80  cpu_crit=95
    local mem_warn=85  mem_crit=95
    local disk_warn=80 disk_crit=90

    local cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    local mem=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
    local disk=$(df / | awk 'NR==2{print $5}' | tr -d '%')

    [[ $cpu  -ge $cpu_crit  ]] && log_critical "CPU critical: ${cpu}%"
    [[ $cpu  -ge $cpu_warn  ]] && log_warn     "CPU high: ${cpu}%"
    [[ $mem  -ge $mem_crit  ]] && log_critical "Memory critical: ${mem}%"
    [[ $mem  -ge $mem_warn  ]] && log_warn     "Memory high: ${mem}%"
    [[ $disk -ge $disk_crit ]] && log_critical "Disk critical: ${disk}%"
    [[ $disk -ge $disk_warn ]] && log_warn     "Disk high: ${disk}%"

    log_info "Resources: CPU=${cpu}% MEM=${mem}% DISK=${disk}%"
}

check_thresholds
