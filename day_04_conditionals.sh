#!/bin/bash
# =============================================================
#  Day 4 - Conditionals (if/elif/else, case, test)
# =============================================================
#  Conditionals let scripts make decisions based on conditions.
#  Bash has two ways to test:
#   [ ]   — classic POSIX test (portable)
#   [[ ]] — extended bash test (more powerful, safer)
#
#  Always use [[ ]] in bash scripts — it handles edge cases,
#  supports regex, no word-splitting, and glob expansion.
# =============================================================

# ── Basic if / elif / else ────────────────────────────────────
SCORE=78

if [[ $SCORE -ge 90 ]]; then
    echo "Grade: A"
elif [[ $SCORE -ge 80 ]]; then
    echo "Grade: B"
elif [[ $SCORE -ge 70 ]]; then
    echo "Grade: C"
else
    echo "Grade: F"
fi

# ── Numeric Comparisons ───────────────────────────────────────
A=10
B=20
[[ $A -eq $B ]] && echo "Equal"
[[ $A -ne $B ]] && echo "Not equal"
[[ $A -lt $B ]] && echo "A is less than B"
[[ $A -le $B ]] && echo "A is less than or equal to B"
[[ $A -gt $B ]] && echo "A is greater than B"
[[ $A -ge $B ]] && echo "A is greater than or equal to B"

# ── String Comparisons ────────────────────────────────────────
NAME="Alice"
[[ "$NAME" == "Alice" ]]  && echo "Name matches"
[[ "$NAME" != "Bob" ]]    && echo "Not Bob"
[[ -z "$NAME" ]]          && echo "Empty string"
[[ -n "$NAME" ]]          && echo "Non-empty string"
[[ "$NAME" < "Bob" ]]     && echo "Alice comes before Bob"
[[ "$NAME" =~ ^A.*e$ ]]   && echo "Name starts with A, ends with e (regex)"
[[ "$NAME" == A* ]]       && echo "Name starts with A (glob)"

# ── File/Directory Tests ──────────────────────────────────────
FILE="/etc/passwd"
DIR="/var/log"

[[ -e "$FILE" ]]  && echo "$FILE exists"
[[ -f "$FILE" ]]  && echo "$FILE is a regular file"
[[ -d "$DIR" ]]   && echo "$DIR is a directory"
[[ -r "$FILE" ]]  && echo "$FILE is readable"
[[ -w "$FILE" ]]  && echo "$FILE is writable"
[[ -x "$FILE" ]]  && echo "$FILE is executable"
[[ -s "$FILE" ]]  && echo "$FILE is not empty (has size)"
[[ -L "$FILE" ]]  && echo "$FILE is a symbolic link"
[[ -b "/dev/sda" ]] && echo "/dev/sda is a block device"

# Compare file ages
[[ "/etc/hosts" -nt "/etc/passwd" ]] && echo "hosts is newer than passwd"
[[ "/etc/hosts" -ot "/etc/passwd" ]] && echo "hosts is older than passwd"

# ── Logical Operators ─────────────────────────────────────────
AGE=25
HAS_ID=true

# AND — both must be true
if [[ $AGE -ge 18 && "$HAS_ID" == "true" ]]; then
    echo "Access granted"
fi

# OR — at least one must be true
if [[ $AGE -lt 13 || $AGE -ge 65 ]]; then
    echo "Discount applies"
fi

# NOT
if [[ ! -f "/tmp/lockfile" ]]; then
    echo "No lock file — safe to proceed"
fi

# ── One-liner Shortcuts ───────────────────────────────────────
[[ -d "/opt/myapp" ]] || mkdir -p "/opt/myapp"   # Create if missing
[[ -f "/etc/hosts" ]] && echo "Hosts file found" # Short-circuit AND
command -v git &>/dev/null || { echo "git not installed"; exit 1; }

# ── case Statement ────────────────────────────────────────────
DAY=$(date +%A)

case "$DAY" in
    Monday|Tuesday|Wednesday|Thursday|Friday)
        echo "Weekday — work day"
        ;;
    Saturday|Sunday)
        echo "Weekend — rest day"
        ;;
    *)
        echo "Unknown day: $DAY"
        ;;
esac

# case with actions
ACTION="$1"
case "$ACTION" in
    start)
        echo "Starting service..."
        systemctl start nginx
        ;;
    stop)
        echo "Stopping service..."
        systemctl stop nginx
        ;;
    restart)
        echo "Restarting service..."
        systemctl restart nginx
        ;;
    status)
        systemctl status nginx
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

# ── Root Check (Very Common in Admin Scripts) ─────────────────
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    echo "       Run: sudo $0"
    exit 1
fi
echo "Running as root — proceeding..."

# ── OS Detection ──────────────────────────────────────────────
if [[ -f /etc/redhat-release ]]; then
    OS="RHEL"
    VERSION=$(rpm -q --qf "%{VERSION}" redhat-release 2>/dev/null)
elif [[ -f /etc/debian_version ]]; then
    OS="Debian"
    VERSION=$(cat /etc/debian_version)
else
    OS="Unknown"
    VERSION="N/A"
fi
echo "OS: $OS $VERSION"
