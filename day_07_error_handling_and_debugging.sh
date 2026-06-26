#!/bin/bash
# =============================================================
#  Day 7 - Error Handling & Debugging
# =============================================================
#  Production scripts MUST handle errors gracefully.
#  Without proper error handling, a script that partially runs
#  can leave your system in an inconsistent state.
#
#  Key tools:
#   set -e      — exit immediately on error
#   set -u      — exit on undefined variable
#   set -o pipefail — catch errors in pipelines
#   set -x      — trace every command (debug mode)
#   trap        — run code on exit/error/signal
#   $?          — exit code of last command
# =============================================================

# ── Script Safety Flags ───────────────────────────────────────
set -euo pipefail
# -e  : Exit immediately if a command fails (non-zero exit code)
# -u  : Treat unset variables as errors
# -o pipefail : Pipeline fails if ANY command in it fails
# Combined:  set -euo pipefail  (use this in ALL production scripts)

# ── Exit Codes ────────────────────────────────────────────────
ls /etc/passwd
echo "Exit code: $?"          # 0 = success

ls /nonexistent 2>/dev/null
echo "Exit code: $?"          # 2 = error

# Convention:
# 0   = Success
# 1   = General error
# 2   = Misuse of shell builtins
# 126 = Command found but not executable
# 127 = Command not found
# 128+N = Killed by signal N (e.g., 130 = Ctrl+C)

# Custom exit codes
readonly E_SUCCESS=0
readonly E_INVALID_ARG=1
readonly E_NOT_ROOT=2
readonly E_FILE_NOT_FOUND=3
readonly E_NETWORK_ERROR=4

# ── Checking Exit Codes ───────────────────────────────────────
# Method 1: if statement
if ! mkdir /tmp/testdir 2>/dev/null; then
    echo "Failed to create directory"
    exit 1
fi

# Method 2: || (OR) — run right side only if left fails
mkdir /opt/myapp || { echo "Cannot create /opt/myapp"; exit 1; }

# Method 3: && (AND) — run right side only if left succeeds
mkdir /opt/myapp && echo "Directory created"

# Method 4: check $? explicitly
cp /etc/hosts /tmp/hosts_backup
if [[ $? -ne 0 ]]; then
    echo "Copy failed!"
    exit 1
fi

# ── trap — Cleanup on Exit ────────────────────────────────────
TMPDIR=$(mktemp -d)
LOCKFILE="/tmp/myscript.lock"

cleanup() {
    local exit_code=$?
    echo "Cleaning up..."
    rm -rf "$TMPDIR"
    rm -f "$LOCKFILE"
    [[ $exit_code -ne 0 ]] && echo "Script exited with error code: $exit_code"
}

# Run cleanup() no matter how script exits (success, error, Ctrl+C)
trap cleanup EXIT

# Trap specific signals
trap 'echo "Interrupted! Cleaning up..."; exit 130' INT   # Ctrl+C
trap 'echo "Terminated! Cleaning up..."; exit 143' TERM  # kill command
trap 'echo "Error on line $LINENO! Exit code: $?"' ERR   # Any error

# Prevent multiple instances with lockfile
if [[ -f "$LOCKFILE" ]]; then
    echo "Script is already running (PID: $(cat $LOCKFILE)). Exiting."
    exit 1
fi
echo $$ > "$LOCKFILE"         # Write our PID to lockfile

# ── Debugging Techniques ──────────────────────────────────────
# Enable debug trace
set -x                         # Print each command before executing
echo "This will be traced"
set +x                         # Disable trace

# Debug specific section only
set -x
RESULT=$(ls /etc/*.conf | wc -l)
set +x
echo "Found $RESULT config files"

# Run entire script in debug mode
# bash -x script.sh

# Verbose mode flag
VERBOSE="${VERBOSE:-false}"
debug() {
    [[ "$VERBOSE" == "true" ]] && echo "[DEBUG] $*" >&2
}
# Run with: VERBOSE=true ./script.sh

# Print line number on error
trap 'echo "Error at line $LINENO: command exited with $?"' ERR

# ── Input Validation ──────────────────────────────────────────
validate_ip() {
    local ip="$1"
    local pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! "$ip" =~ $pattern ]]; then
        echo "ERROR: Invalid IP address: $ip" >&2
        return 1
    fi
    # Check each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        [[ $octet -gt 255 ]] && { echo "ERROR: Octet out of range: $octet" >&2; return 1; }
    done
    return 0
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] || { echo "ERROR: Port must be numeric" >&2; return 1; }
    [[ $port -ge 1 && $port -le 65535 ]] || { echo "ERROR: Port must be 1-65535" >&2; return 1; }
    return 0
}

validate_ip "192.168.1.100"  && echo "Valid IP"
validate_ip "999.1.2.3"      || echo "Invalid IP caught"
validate_port "8080"          && echo "Valid port"
validate_port "99999"         || echo "Invalid port caught"

# ── Timeout Handling ──────────────────────────────────────────
# Run a command with timeout
timeout 30 curl -sf http://api.example.com/health
if [[ $? -eq 124 ]]; then
    echo "Command timed out after 30 seconds"
fi

# Retry with exponential backoff
retry_with_backoff() {
    local max_retries=5
    local delay=1
    local cmd=("$@")
    for ((i=1; i<=max_retries; i++)); do
        "${cmd[@]}" && return 0
        echo "Attempt $i failed. Waiting ${delay}s..." >&2
        sleep $delay
        delay=$((delay * 2))   # Exponential backoff: 1s, 2s, 4s, 8s, 16s
    done
    echo "All $max_retries attempts failed." >&2
    return 1
}

retry_with_backoff curl -sf http://api.example.com/health
