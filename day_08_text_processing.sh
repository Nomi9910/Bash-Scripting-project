#!/bin/bash
# =============================================================
#  Day 8 - Text Processing in Bash Scripts
# =============================================================
#  Sysadmin scripts live and die by text processing.
#  These tools let you extract, filter, and transform data
#  from log files, config files, command output, and APIs.
#
#   grep — search/filter lines by pattern
#   sed  — find & replace, edit streams
#   awk  — field-based processing, calculations, reports
#   cut  — extract columns from delimited text
#   sort/uniq — sort and deduplicate
# =============================================================

# ── grep in Scripts ───────────────────────────────────────────
LOG="/var/log/messages"

# Count errors in log
error_count=$(grep -c "ERROR" "$LOG" 2>/dev/null || echo 0)
echo "Errors found: $error_count"

# Check if pattern exists
if grep -q "Out of memory" "$LOG"; then
    echo "ALERT: OOM events detected!"
fi

# Extract IPs from log
grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' /var/log/secure | sort | uniq -c | sort -rn

# Find failed SSH logins
failed_logins=$(grep "Failed password" /var/log/secure | wc -l)
echo "Failed SSH logins today: $failed_logins"

# Top offending IPs
echo "Top attacking IPs:"
grep "Failed password" /var/log/secure \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
    | sort | uniq -c | sort -rn | head -5

# ── sed in Scripts ────────────────────────────────────────────
# Replace value in config file
CONFIG="/etc/myapp/config.ini"
# sed -i "s/^db_host=.*/db_host=newserver/" "$CONFIG"
# sed -i "s/^port=.*/port=5432/" "$CONFIG"

# Set a key=value in config
set_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# Remove comment lines and blank lines
strip_comments() {
    sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$1"
}

# Extract value from key=value file
get_config_value() {
    local file="$1"
    local key="$2"
    grep "^${key}=" "$file" | cut -d'=' -f2- | tr -d '"'
}

# ── awk in Scripts ────────────────────────────────────────────
# Parse /etc/passwd to show users with UID >= 1000
echo "Regular users:"
awk -F: '$3 >= 1000 && $3 != 65534 {printf "  %-15s UID:%-6s Home: %s\n", $1, $3, $6}' /etc/passwd

# Disk usage report
echo -e "\nDisk Usage Report:"
df -h | awk 'NR>1 {
    gsub(/%/, "", $5)
    if ($5+0 >= 80)
        printf "  WARN  %s: %s used (%s)\n", $6, $5"%", $2
    else
        printf "  OK    %s: %s used (%s)\n", $6, $5"%", $2
}'

# Parse nginx access log — count requests per status code
echo -e "\nHTTP Status Codes:"
awk '{print $9}' /var/log/nginx/access.log 2>/dev/null \
    | sort | uniq -c | sort -rn \
    | awk '{printf "  HTTP %s: %d requests\n", $2, $1}'

# Sum a column
total_memory() {
    free -m | awk '/^Mem:/{print $2}'
}
echo "Total RAM: $(total_memory) MB"

# CSV parser
parse_csv() {
    local file="$1"
    awk -F',' 'NR>1 {
        name=$1; age=$2; city=$3
        printf "Name: %-15s Age: %-4s City: %s\n", name, age, city
    }' "$file"
}

# ── Combining Tools in Pipelines ──────────────────────────────
# Find top 10 memory consumers
ps aux --sort=-%mem | awk 'NR>1 {printf "%-20s %s%%\n", $11, $4}' | head -10

# Parse systemd journal for last hour errors
journalctl --since "1 hour ago" -p err --no-pager \
    | grep -v "^--" \
    | awk '{$1=$2=$3=""; print NR": "$0}' \
    | head -20

# Count unique SSH users
last | awk 'NF>1 && $1 !~ /^(reboot|wtmp)$/ {print $1}' \
    | sort | uniq -c | sort -rn

# Extract all emails from a file
grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' contacts.txt | sort -u

# Monitor a log file for a pattern
tail -f /var/log/messages | grep --line-buffered "error" | while read -r line; do
    echo "ALERT: $line"
    # Send notification, page oncall, etc.
done
