#!/bin/bash
# =============================================================
#  Day 6 - Functions in Bash
# =============================================================
#  Functions let you group commands into reusable blocks.
#  They reduce repetition and make scripts maintainable.
#
#  Key rules:
#   - Define BEFORE calling (or use a main() pattern)
#   - Arguments passed via $1, $2, ... (NOT in definition)
#   - local keyword prevents variable leaking out of function
#   - return only returns 0-255 (exit code, not values)
#   - To return a value: echo it and capture with $()
# =============================================================

# ── Basic Function Definition ─────────────────────────────────
greet() {
    echo "Hello, World!"
}
greet                          # Call the function

# Function with arguments
greet_user() {
    local name="$1"
    local greeting="${2:-Hello}"   # Default greeting
    echo "$greeting, $name!"
}
greet_user "Alice"
greet_user "Bob" "Hi"
greet_user "Charlie" "Welcome"

# ── Return Values ─────────────────────────────────────────────
# Method 1: echo (capture with command substitution)
get_date() {
    echo "$(date '+%Y-%m-%d')"
}
TODAY=$(get_date)
echo "Today is: $TODAY"

# Method 2: return exit code (0=success, 1-255=error)
is_root() {
    [[ $EUID -eq 0 ]]
}
if is_root; then
    echo "Running as root"
else
    echo "Not root"
fi

# Method 3: global variable (use sparingly)
parse_config() {
    CONFIG_HOST="localhost"
    CONFIG_PORT=5432
    CONFIG_DB="mydb"
}
parse_config
echo "DB: $CONFIG_HOST:$CONFIG_PORT/$CONFIG_DB"

# ── Local Variables ───────────────────────────────────────────
GREETING="Global greeting"

set_greeting() {
    local GREETING="Local greeting"   # Only lives inside this function
    echo "Inside:  $GREETING"
}
set_greeting
echo "Outside: $GREETING"             # Still "Global greeting"

# ── Error Handling in Functions ───────────────────────────────
create_user() {
    local username="$1"
    local home_dir="/home/$username"

    if [[ -z "$username" ]]; then
        echo "ERROR: Username cannot be empty" >&2
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo "WARN: User $username already exists"
        return 2
    fi

    useradd -m -s /bin/bash "$username" || {
        echo "ERROR: Failed to create user $username" >&2
        return 3
    }

    echo "SUCCESS: User $username created"
    return 0
}

create_user "alice"
EXIT_CODE=$?
case $EXIT_CODE in
    0) echo "User created successfully" ;;
    1) echo "Invalid username" ;;
    2) echo "User already exists" ;;
    3) echo "System error creating user" ;;
esac

# ── Reusable Logging Library ──────────────────────────────────
LOG_FILE="/tmp/script.log"

log()         { echo "[$(date '+%H:%M:%S')] [INFO]    $*" | tee -a "$LOG_FILE"; }
log_success() { echo "[$(date '+%H:%M:%S')] [SUCCESS] $*" | tee -a "$LOG_FILE"; }
log_warn()    { echo "[$(date '+%H:%M:%S')] [WARN]    $*" | tee -a "$LOG_FILE" >&2; }
log_error()   { echo "[$(date '+%H:%M:%S')] [ERROR]   $*" | tee -a "$LOG_FILE" >&2; }
log_debug()   { [[ "${DEBUG:-false}" == "true" ]] && echo "[$(date '+%H:%M:%S')] [DEBUG]   $*" >&2; }

log "Script started"
log_warn "Low disk space detected"
log_error "Connection to DB failed"

# ── Utility Functions Library ─────────────────────────────────
# Check if command exists
command_exists() { command -v "$1" &>/dev/null; }

# Check if running as root
require_root() {
    [[ $EUID -ne 0 ]] && { log_error "Must run as root."; exit 1; }
}

# Check if a service is running
service_running() {
    systemctl is-active --quiet "$1"
}

# Confirm before dangerous action
confirm() {
    local prompt="${1:-Are you sure?}"
    read -rp "$prompt (yes/no): " answer
    [[ "$answer" == "yes" ]]
}

# Retry a command N times
retry() {
    local max="$1"; shift
    local delay="${1:-5}"; shift
    local cmd=("$@")
    local attempt=1
    until "${cmd[@]}"; do
        [[ $attempt -ge $max ]] && { log_error "Failed after $max attempts"; return 1; }
        log_warn "Attempt $attempt failed. Retrying in ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
}

# Usage examples
command_exists curl   && log "curl is available"
service_running sshd  && log "SSH is running"
retry 3 2 curl -sf http://api.example.com/health

# ── main() Pattern — Best Practice ───────────────────────────
setup()   { log "Setting up environment..."; }
deploy()  { log "Deploying application..."; }
cleanup() { log "Cleaning up temp files..."; }

main() {
    setup
    deploy
    cleanup
    log_success "All done!"
}

# Only run main() if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
