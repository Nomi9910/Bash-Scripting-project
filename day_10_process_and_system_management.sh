#!/bin/bash
# =============================================================
#  Day 10 - Process & System Management in Scripts
# =============================================================
#  Scripts often need to manage processes — start/stop services,
#  check if a process is running, kill hung processes, monitor
#  system resources, and ensure services stay healthy.
# =============================================================

# ── Checking if a Process is Running ─────────────────────────
is_running() {
    local process="$1"
    pgrep -x "$process" &>/dev/null
}

if is_running nginx; then
    echo "nginx is running (PID: $(pgrep nginx | head -1))"
else
    echo "nginx is NOT running"
fi

# Using systemctl (preferred for systemd services)
service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "$service: ACTIVE"
        return 0
    elif systemctl is-failed --quiet "$service"; then
        echo "$service: FAILED"
        return 2
    else
        echo "$service: INACTIVE"
        return 1
    fi
}

service_status nginx
service_status sshd
service_status firewalld

# ── Starting / Stopping Services ─────────────────────────────
manage_service() {
    local action="$1"
    local service="$2"

    case "$action" in
        start)
            if systemctl is-active --quiet "$service"; then
                echo "$service is already running"
                return 0
            fi
            systemctl start "$service" && echo "Started: $service" || {
                echo "Failed to start $service"
                journalctl -u "$service" -n 20 --no-pager
                return 1
            }
            ;;
        stop)
            systemctl stop "$service" && echo "Stopped: $service"
            ;;
        restart)
            systemctl restart "$service" && echo "Restarted: $service"
            ;;
        enable)
            systemctl enable --now "$service" && echo "Enabled: $service"
            ;;
    esac
}

manage_service start nginx
manage_service restart sshd

# ── Running Background Processes ──────────────────────────────
# Run process in background
long_task() {
    sleep 30
    echo "Task done"
}
long_task &
BG_PID=$!
echo "Started background task with PID: $BG_PID"

# Wait for it to finish
wait $BG_PID
echo "Background task completed with exit code: $?"

# Run multiple tasks in parallel
run_parallel() {
    local pids=()
    for server in web01 web02 web03; do
        (
            echo "Deploying to $server..."
            ssh "$server" "cd /opt/app && git pull && systemctl restart myapp"
        ) &
        pids+=($!)
    done

    local failed=0
    for pid in "${pids[@]}"; do
        wait "$pid" || ((failed++))
    done

    [[ $failed -eq 0 ]] && echo "All deployments succeeded" || echo "$failed deployment(s) failed"
}

# ── System Resource Checks ────────────────────────────────────
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1
}

get_mem_usage() {
    free | awk '/^Mem:/{printf "%.0f", $3/$2 * 100}'
}

get_disk_usage() {
    df -h "$1" | awk 'NR==2{print $5}' | tr -d '%'
}

get_load_avg() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ','
}

echo "CPU Usage   : $(get_cpu_usage)%"
echo "Memory Usage: $(get_mem_usage)%"
echo "Disk Usage  : $(get_disk_usage /)%"
echo "Load Average: $(get_load_avg)"

# ── Health Check Script ───────────────────────────────────────
health_check() {
    local issues=0

    echo "=== System Health Check: $(date) ==="

    # CPU
    cpu=$(get_cpu_usage)
    [[ $cpu -gt 90 ]] && { echo "[WARN] High CPU: ${cpu}%"; ((issues++)); } \
                       || echo "[OK]   CPU: ${cpu}%"

    # Memory
    mem=$(get_mem_usage)
    [[ $mem -gt 90 ]] && { echo "[WARN] High Memory: ${mem}%"; ((issues++)); } \
                       || echo "[OK]   Memory: ${mem}%"

    # Disk
    disk=$(get_disk_usage /)
    [[ $disk -gt 85 ]] && { echo "[WARN] High Disk: ${disk}%"; ((issues++)); } \
                        || echo "[OK]   Disk: ${disk}%"

    # Services
    for svc in nginx sshd firewalld; do
        if systemctl is-active --quiet "$svc"; then
            echo "[OK]   $svc: running"
        else
            echo "[FAIL] $svc: NOT running"
            ((issues++))
        fi
    done

    echo "=== Total Issues: $issues ==="
    return $issues
}

health_check
EXIT_CODE=$?
[[ $EXIT_CODE -gt 0 ]] && echo "ACTION REQUIRED: $EXIT_CODE issue(s) detected!"
