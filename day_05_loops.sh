#!/bin/bash
# =============================================================
#  Day 5 - Loops (for, while, until, loop control)
# =============================================================
#  Loops execute a block of code repeatedly.
#   for   — iterate over a list or range
#   while — repeat while condition is true
#   until — repeat until condition is true (opposite of while)
#
#  Loop control:
#   break    — exit the loop immediately
#   continue — skip to the next iteration
#   exit     — exit the entire script
# =============================================================

# ── for Loop — List ───────────────────────────────────────────
for NAME in Alice Bob Charlie Dave; do
    echo "Hello, $NAME!"
done

# for loop over array
SERVERS=("web01" "web02" "db01" "cache01")
for SERVER in "${SERVERS[@]}"; do
    echo "Checking $SERVER..."
    ping -c 1 -W 1 "$SERVER" &>/dev/null && echo "  UP" || echo "  DOWN"
done

# for loop over files
for FILE in /etc/*.conf; do
    echo "Config file: $FILE"
done

for LOG in /var/log/*.log; do
    SIZE=$(du -sh "$LOG" | cut -f1)
    echo "$SIZE  $LOG"
done

# ── for Loop — Range with seq ─────────────────────────────────
for i in $(seq 1 5); do
    echo "Number: $i"
done

for i in $(seq 0 2 10); do     # 0, 2, 4, 6, 8, 10 (step 2)
    echo "Even: $i"
done

# ── C-style for Loop ──────────────────────────────────────────
for ((i=1; i<=5; i++)); do
    echo "Count: $i"
done

for ((i=10; i>=0; i-=2)); do   # Countdown by 2
    echo "Countdown: $i"
done

# ── for Loop — Command Output ─────────────────────────────────
for USER in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    echo "Regular user: $USER"
done

for PID in $(pgrep nginx); do
    echo "Nginx PID: $PID"
done

# ── while Loop ────────────────────────────────────────────────
COUNT=1
while [[ $COUNT -le 5 ]]; do
    echo "While count: $COUNT"
    ((COUNT++))
done

# while reading a file line by line
while IFS= read -r LINE; do
    echo "  >> $LINE"
done < /etc/hostname

# while loop with command
while systemctl is-active nginx &>/dev/null; do
    echo "Nginx is running... checking again in 5s"
    sleep 5
done
echo "Nginx stopped!"

# ── until Loop ────────────────────────────────────────────────
# Opposite of while — runs UNTIL condition is TRUE
COUNT=1
until [[ $COUNT -gt 5 ]]; do
    echo "Until count: $COUNT"
    ((COUNT++))
done

# Wait for a service to become available
until curl -s http://localhost &>/dev/null; do
    echo "Waiting for web server to start..."
    sleep 2
done
echo "Web server is up!"

# ── break & continue ──────────────────────────────────────────
echo "--- break example ---"
for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ $i -eq 6 ]] && break       # Stop loop at 6
    echo $i
done

echo "--- continue example ---"
for i in $(seq 1 10); do
    [[ $((i % 2)) -eq 0 ]] && continue   # Skip even numbers
    echo "Odd: $i"
done

# break out of nested loops
for i in 1 2 3; do
    for j in a b c; do
        [[ "$i" == 2 && "$j" == "b" ]] && break 2   # break 2 levels
        echo "$i-$j"
    done
done

# ── Infinite Loop with break ──────────────────────────────────
ATTEMPTS=0
while true; do
    ((ATTEMPTS++))
    echo "Attempt $ATTEMPTS..."
    [[ $ATTEMPTS -ge 3 ]] && { echo "Max attempts reached."; break; }
    sleep 1
done

# ── Practical Examples ────────────────────────────────────────
# Retry logic
MAX_RETRIES=5
RETRY_DELAY=3

for ((attempt=1; attempt<=MAX_RETRIES; attempt++)); do
    echo "Attempt $attempt of $MAX_RETRIES..."
    curl -sf http://api.example.com/health && { echo "Success!"; break; }
    [[ $attempt -lt $MAX_RETRIES ]] && sleep $RETRY_DELAY
done

# Process multiple servers
FAILED_SERVERS=()
for SERVER in web01 web02 web03; do
    if ! ssh -o ConnectTimeout=5 "$SERVER" "systemctl is-active nginx" &>/dev/null; then
        FAILED_SERVERS+=("$SERVER")
        echo "WARN: nginx not running on $SERVER"
    else
        echo "OK: $SERVER"
    fi
done

if [[ ${#FAILED_SERVERS[@]} -gt 0 ]]; then
    echo "Failed servers: ${FAILED_SERVERS[*]}"
    exit 1
fi
