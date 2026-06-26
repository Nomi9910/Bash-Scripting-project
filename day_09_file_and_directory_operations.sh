#!/bin/bash
# =============================================================
#  Day 9 - File & Directory Operations in Scripts
# =============================================================
#  Scripts constantly work with files — reading configs,
#  writing logs, creating backups, checking disk space,
#  and managing temporary files safely.
#
#  Key practices:
#   - Always quote file paths: "$FILE" not $FILE
#   - Use mktemp for temp files — never hardcode /tmp/filename
#   - Check file exists before reading
#   - Trap cleanup to remove temp files on exit
# =============================================================

# ── Safe Temp Files & Directories ────────────────────────────
TMPFILE=$(mktemp)                          # /tmp/tmp.XXXXXX
TMPDIR_WORK=$(mktemp -d)                   # /tmp/tmp.XXXXXX (directory)
TMPFILE_NAMED=$(mktemp /tmp/myapp-XXXXXX.log)  # Named temp file

# Always clean up temp files on exit
trap 'rm -rf "$TMPFILE" "$TMPDIR_WORK" "$TMPFILE_NAMED"' EXIT

echo "Temp file: $TMPFILE"
echo "Temp dir : $TMPDIR_WORK"

# ── Reading Files ─────────────────────────────────────────────
# Read entire file into variable
CONFIG_CONTENT=$(cat /etc/hostname)
echo "Hostname: $CONFIG_CONTENT"

# Read file line by line (safe — handles spaces in lines)
while IFS= read -r line; do
    [[ -z "$line" ]] && continue          # Skip blank lines
    [[ "$line" =~ ^# ]] && continue       # Skip comment lines
    echo "Config: $line"
done < /etc/ssh/sshd_config

# Read into array
mapfile -t LINES < /etc/hosts             # Bash 4+
for line in "${LINES[@]}"; do
    echo "$line"
done

# ── Writing Files ─────────────────────────────────────────────
# Overwrite
echo "New content" > "$TMPFILE"

# Append
echo "More content" >> "$TMPFILE"

# Multi-line heredoc
cat > "$TMPFILE" << 'CONTENT'
Line 1
Line 2
Line 3
CONTENT

# Write with variable expansion
SERVER="web01"
cat > /tmp/server-report.txt << REPORT
Server Report
=============
Server  : $SERVER
Date    : $(date)
Uptime  : $(uptime -p)
Memory  : $(free -h | awk '/^Mem:/{print $3 "/" $2}')
Disk    : $(df -h / | awk 'NR==2{print $3 "/" $2}')
REPORT

# ── File Tests & Checks ───────────────────────────────────────
check_file() {
    local file="$1"
    echo "=== Checking: $file ==="
    [[ -e "$file" ]] && echo "  Exists"          || echo "  Does NOT exist"
    [[ -f "$file" ]] && echo "  Is a file"       || true
    [[ -d "$file" ]] && echo "  Is a directory"  || true
    [[ -r "$file" ]] && echo "  Readable"        || echo "  NOT readable"
    [[ -w "$file" ]] && echo "  Writable"        || echo "  NOT writable"
    [[ -x "$file" ]] && echo "  Executable"      || true
    [[ -s "$file" ]] && echo "  Has content"     || echo "  Empty"
    [[ -L "$file" ]] && echo "  Is symlink"      || true
}

check_file /etc/passwd
check_file /nonexistent

# ── Backup Function ───────────────────────────────────────────
backup_file() {
    local file="$1"
    local backup_dir="${2:-/tmp/backups}"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename=$(basename "$file")

    mkdir -p "$backup_dir"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi

    local backup_path="${backup_dir}/${filename}.${timestamp}.bak"
    cp -p "$file" "$backup_path" || { echo "Backup failed!" >&2; return 1; }
    echo "Backup created: $backup_path"
}

backup_file /etc/hosts
backup_file /etc/sshd_config /var/backups/ssh

# ── Directory Operations ──────────────────────────────────────
ensure_dir() {
    local dir="$1"
    local owner="${2:-root}"
    local perms="${3:-755}"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chown "$owner" "$dir"
        chmod "$perms" "$dir"
        echo "Created: $dir"
    else
        echo "Exists:  $dir"
    fi
}

ensure_dir "/opt/myapp/logs"  "nginx:nginx"  "750"
ensure_dir "/opt/myapp/data"  "myapp"        "700"
ensure_dir "/opt/myapp/tmp"   "myapp"        "777"

# ── Find & Process Files ──────────────────────────────────────
# Delete log files older than 30 days
find /var/log/myapp -name "*.log" -mtime +30 -type f -delete
echo "Old logs cleaned"

# Compress files older than 7 days
find /var/log -name "*.log" -mtime +7 -type f | while read -r logfile; do
    gzip "$logfile" && echo "Compressed: $logfile"
done

# Find and fix permissions
find /opt/myapp -type f -name "*.sh" ! -perm -u+x -exec chmod u+x {} \;

# ── Disk Space Monitoring ─────────────────────────────────────
check_disk_space() {
    local threshold="${1:-80}"
    local alert=false

    while IFS= read -r line; do
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mount=$(echo "$line" | awk '{print $6}')
        [[ "$usage" =~ ^[0-9]+$ ]] || continue
        if [[ $usage -ge $threshold ]]; then
            echo "CRITICAL: $mount is ${usage}% full!"
            alert=true
        else
            echo "OK:       $mount is ${usage}% full"
        fi
    done < <(df -h | tail -n +2)

    $alert && return 1 || return 0
}

check_disk_space 80
