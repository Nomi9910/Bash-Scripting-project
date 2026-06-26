#!/bin/bash
# =============================================================
#  Day 1 - Introduction to Bash Scripting
# =============================================================
#  Bash (Bourne Again SHell) is the default shell on RHEL 9.
#  A shell script is a plain text file containing a sequence
#  of shell commands that are executed top to bottom.
#
#  Why Bash scripting?
#   - Automate repetitive system administration tasks
#   - Schedule jobs with cron
#   - Process log files and generate reports
#   - Deploy applications, manage users, configure servers
#   - Glue together Linux tools (grep, awk, sed, curl, etc.)
#
#  File:      script.sh  (or any name — .sh is convention)
#  Shebang:   #!/bin/bash  (always first line — tells OS which interpreter)
#  Run it:    bash script.sh   OR   ./script.sh (needs execute permission)
# =============================================================

# ── Your First Script ─────────────────────────────────────────
# Step 1: Create the file
# vim my_first_script.sh

# Step 2: Add content
cat > /tmp/my_first_script.sh << 'SCRIPT'
#!/bin/bash
# My first Bash script
# Author: Nomi
# Date: 2025-06-25

echo "Hello, World!"
echo "Welcome to Bash Scripting on RHEL 9"
echo "Today's date is: $(date)"
echo "You are logged in as: $(whoami)"
echo "Current directory: $(pwd)"
echo "Hostname: $(hostname)"
SCRIPT

# Step 3: Make it executable
chmod +x /tmp/my_first_script.sh

# Step 4: Run it
bash /tmp/my_first_script.sh       # Run with bash interpreter
# OR
/tmp/my_first_script.sh            # Run directly (needs execute bit)

# ── Understanding the Shebang ─────────────────────────────────
# #!/bin/bash        → Use Bash (most common)
# #!/usr/bin/env bash → Find bash in PATH (more portable)
# #!/bin/sh          → POSIX sh (more compatible, fewer features)
# #!/usr/bin/python3 → Python script
# #!/usr/bin/env perl → Perl script

# RHEL 9 bash location
which bash          # /bin/bash
bash --version      # GNU bash, version 5.1.x

# ── Script Permissions ────────────────────────────────────────
chmod +x script.sh          # Add execute for everyone
chmod 755 script.sh         # rwxr-xr-x  (standard for scripts)
chmod 700 script.sh         # rwx------  (private scripts)
ls -l script.sh             # Verify permissions

# ── Running Scripts — Different Ways ──────────────────────────
bash script.sh              # Run in a new bash subshell
source script.sh            # Run in CURRENT shell (variables persist)
. script.sh                 # Same as source
sh script.sh                # Run with /bin/sh (POSIX mode)
./script.sh                 # Run directly (needs chmod +x)

# ── Comments ──────────────────────────────────────────────────
# This is a single-line comment — ignored by bash

# Multi-line comment trick (not real syntax, but useful):
: '
This is a multi-line
comment block. Everything
between the quotes is ignored.
'

# Inline comment
echo "Hello"    # This comment explains what echo does

# ── echo & printf ─────────────────────────────────────────────
echo "Simple output"
echo -n "No newline at end"         # -n = suppress trailing newline
echo -e "Tab:\there\nNew line"      # -e = interpret escape sequences
echo -e "\033[32mGreen text\033[0m" # ANSI colors

# printf — more control than echo (like C's printf)
printf "Name: %s\n" "Alice"
printf "Age:  %d\n" 30
printf "Pi:   %.2f\n" 3.14159
printf "%-10s %5d\n" "Alice" 95     # Left-align name, right-align score

# ── Script Header Template (Best Practice) ────────────────────
cat > /tmp/template.sh << 'TEMPLATE'
#!/usr/bin/env bash
# =============================================================
# Script Name:  template.sh
# Description:  Brief description of what this script does
# Author:       Your Name
# Email:        you@example.com
# Created:      2025-06-25
# Modified:     2025-06-25
# Version:      1.0.0
# Usage:        ./template.sh [options] <arguments>
# Example:      ./template.sh -v --user alice
# Dependencies: curl, jq, systemctl
# =============================================================

set -euo pipefail   # Exit on error, undefined vars, pipe failures
# set -x            # Uncomment to enable debug mode (traces every command)

# ── Constants ────────────────────────────────────────────────
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/${SCRIPT_NAME%.sh}.log"
readonly TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ── Logging Functions ─────────────────────────────────────────
log_info()    { echo "[INFO]  $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_warn()    { echo "[WARN]  $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE" >&2; }
log_error()   { echo "[ERROR] $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE" >&2; }
log_success() { echo "[OK]    $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }

# ── Main Logic ────────────────────────────────────────────────
main() {
    log_info "Script started: $SCRIPT_NAME"
    # Your code here
    log_success "Script completed successfully"
}

main "$@"
TEMPLATE
chmod +x /tmp/template.sh
echo "Template created at /tmp/template.sh"
