#!/bin/bash
# =============================================================
#  Day 15 - Best Practices & Building a Script Library
# =============================================================
#  After mastering the mechanics of bash scripting, the final
#  step is writing scripts that are production-ready:
#   - Readable, maintainable, and documented
#   - Safe with proper error handling
#   - Reusable as a library (source-able functions)
#   - Tested and versioned in Git
#
#  This lesson brings everything together into a complete
#  production-quality script library for RHEL 9 sysadmins.
# =============================================================

# ══════════════════════════════════════════════════════════════
# PART 1: COMPLETE BASH LIBRARY (lib.sh)
# Source this in any script: source /usr/local/lib/bash/lib.sh
# ══════════════════════════════════════════════════════════════

# ── Colors & Formatting ───────────────────────────────────────
RED='\033[0;31m';    LRED='\033[1;31m'
GREEN='\033[0;32m';  LGREEN='\033[1;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m';   WHITE='\033[1;37m'
BOLD='\033[1m';      NC='\033[0m'

print_header() { echo -e "\n${BOLD}${BLUE}══ $* ══${NC}"; }
print_ok()     { echo -e "${GREEN}  ✔ $*${NC}"; }
print_warn()   { echo -e "${YELLOW}  ⚠ $*${NC}"; }
print_fail()   { echo -e "${RED}  ✘ $*${NC}" >&2; }
print_info()   { echo -e "${CYAN}  ℹ $*${NC}"; }
hr()           { printf '%*s\n' "${COLUMNS:-60}" '' | tr ' ' '─'; }

# ── Strict Validation Guards ──────────────────────────────────
require_root() {
    [[ $EUID -ne 0 ]] && { print_fail "Must run as root (sudo $0)"; exit 1; }
}

require_commands() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    [[ ${#missing[@]} -gt 0 ]] && {
        print_fail "Missing required commands: ${missing[*]}"
        print_info "Install with: dnf install -y ${missing[*]}"
        exit 1
    }
}

require_file() {
    [[ -f "$1" ]] || { print_fail "Required file not found: $1"; exit 1; }
}

require_variable() {
    local var_name="$1"
    [[ -n "${!var_name}" ]] || { print_fail "Required variable not set: $var_name"; exit 1; }
}

# ── Robust Execution Helpers ──────────────────────────────────
run_as_root() { sudo "$@"; }

try() {
    local description="$1"; shift
    print_info "Running: $description"
    if "$@"; then
        print_ok "$description"
        return 0
    else
        print_fail "$description"
        return 1
    fi
}

must_succeed() {
    "$@" || { print_fail "Fatal: command failed: $*"; exit 1; }
}

# ── String Utilities ──────────────────────────────────────────
str_upper()     { echo "${1^^}"; }
str_lower()     { echo "${1,,}"; }
str_trim()      { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
str_contains()  { [[ "$1" == *"$2"* ]]; }
str_startswith(){ [[ "$1" == "$2"* ]]; }
str_endswith()  { [[ "$1" == *"$2" ]]; }
str_repeat()    { printf "%${2}s" | tr ' ' "${1}"; }
str_pad()       { printf "%-${2}s" "$1"; }

# ── Array Utilities ───────────────────────────────────────────
array_contains() {
    local needle="$1"; shift
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

array_join() {
    local delim="$1"; shift
    local result=""
    for item in "$@"; do
        result="${result:+${result}${delim}}${item}"
    done
    echo "$result"
}

# ── Number Utilities ──────────────────────────────────────────
is_integer()    { [[ "$1" =~ ^-?[0-9]+$ ]]; }
is_positive()   { is_integer "$1" && [[ $1 -gt 0 ]]; }
clamp()         { local val=$1 min=$2 max=$3; echo $(( val < min ? min : val > max ? max : val )); }
bytes_to_human(){ numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

# ── System Utilities ──────────────────────────────────────────
get_os_version()   { grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1; }
get_total_ram_mb() { awk '/MemTotal/{print int($2/1024)}' /proc/meminfo; }
get_free_ram_mb()  { awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo; }
get_disk_free_gb() { df -BG "${1:-/}" | awk 'NR==2{print $4}' | tr -d 'G'; }
get_public_ip()    { curl -sf --max-time 5 https://api.ipify.org 2>/dev/null || echo "N/A"; }

is_service_active() { systemctl is-active --quiet "$1"; }
is_port_open()      { ss -tuln | grep -q ":${1} "; }

# ══════════════════════════════════════════════════════════════
# PART 2: BASH SCRIPTING BEST PRACTICES CHECKLIST
# ══════════════════════════════════════════════════════════════

: <<'CHECKLIST'
✅ SAFETY
  set -euo pipefail at the top of every script
  Trap EXIT for cleanup: trap cleanup EXIT
  Use flock to prevent duplicate cron runs
  Validate ALL inputs before using them
  Use readonly for constants
  Quote all variables: "$VAR" not $VAR

✅ RELIABILITY
  Use full paths in cron scripts
  Redirect output: command >> logfile 2>&1
  Check commands exist: command -v tool || exit 1
  Use mktemp for temp files (never /tmp/hardcoded)
  Test return codes: if ! command; then...
  Use timeout for network commands

✅ MAINTAINABILITY
  Header with: name, description, author, usage
  One function per logical task
  Use descriptive variable names (UPPER for globals)
  Comment the WHY not the WHAT
  Keep functions under 50 lines
  Use main() pattern with: if [[ "${BASH_SOURCE[0]}" == "${0}" ]]

✅ SECURITY
  Never log passwords or secrets
  Validate user input (injection prevention)
  Use chmod 700 or 750 for scripts
  Never use eval on user input
  Run as least-privileged user possible
  Store secrets in files with 600 permissions, not env vars

✅ LOGGING
  Log to file AND stderr
  Include timestamps in every log line
  Log start, completion, and errors
  Use log levels: DEBUG INFO WARN ERROR
  Rotate logs: logrotate or built-in rotation

✅ TESTING
  Test with bash -n script.sh (syntax check)
  Test with bash -x script.sh (trace mode)
  Use shellcheck: dnf install -y shellcheck
  Test in a VM before running in production
  Test error paths (not just happy path)
  Version scripts in Git
CHECKLIST

# ── ShellCheck Integration ────────────────────────────────────
# Install: dnf install -y shellcheck
# Run:     shellcheck my_script.sh

# Common shellcheck fixes:
# SC2086: Double quote to prevent globbing and word splitting
#   Before: ls $FILE    After: ls "$FILE"
# SC2046: Quote to prevent word splitting
#   Before: cp $(ls)    After: Use arrays instead
# SC2155: Declare and assign separately
#   Before: local var=$(cmd)   After: local var; var=$(cmd)
# SC2164: Use cd ... || exit
#   Before: cd /tmp     After: cd /tmp || exit 1

print_header "Bash Scripting Library Ready"
print_info "Source this file in your scripts:"
print_info "  source /usr/local/lib/bash/lib.sh"
print_info ""
print_info "Available functions: logging, validation,"
print_info "  string/array/number utils, system helpers"
print_ok "Day 15 complete! You now have a production-ready bash toolkit."
hr
