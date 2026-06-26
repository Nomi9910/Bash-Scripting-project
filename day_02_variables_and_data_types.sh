#!/bin/bash
# =============================================================
#  Day 2 - Variables & Data Types in Bash
# =============================================================
#  Bash variables are untyped by default — everything is a string.
#  No spaces around = when assigning: VAR="value"  (NOT VAR = "value")
#  Access with $VAR or ${VAR}  — curly braces avoid ambiguity.
#
#  Variable types:
#   - Local variables     — script-scoped
#   - Environment vars    — inherited by child processes
#   - Special variables   — $0, $1, $$, $?, $#, $@, $*
#   - Arrays              — indexed and associative
#   - Read-only           — constants (readonly/declare -r)
#   - Integer             — declare -i (arithmetic enforced)
# =============================================================

# ── Basic Variable Assignment ─────────────────────────────────
NAME="Alice"
AGE=30
CITY="New York"
IS_ADMIN=true

# Access variables
echo "$NAME"                # Alice
echo "${NAME}"              # Alice — preferred (explicit boundary)
echo "Hello, ${NAME}!"     # Hello, Alice!

# Common mistake — NO spaces around =
# NAME = "Alice"   ← ERROR: bash treats NAME as a command
# NAME= "Alice"    ← ERROR: empty NAME, runs "Alice" as command

# ── Variable Naming Rules ─────────────────────────────────────
myVar="ok"            # camelCase
my_var="ok"           # snake_case (most common in bash)
MY_CONSTANT="ok"      # UPPER_SNAKE for constants/env vars
_private="ok"         # underscore prefix for private-ish vars
# 2var="bad"          # Cannot start with a digit
# my-var="bad"        # No hyphens allowed

# ── Quoting Rules ─────────────────────────────────────────────
NAME="Alice Smith"
echo $NAME            # Alice Smith (word splitting may cause issues)
echo "$NAME"          # Alice Smith (safe — always double-quote variables!)
echo '${NAME}'        # ${NAME}    (single quotes: NO expansion)
echo "${NAME}"        # Alice Smith (best practice)

# When NOT quoting causes bugs:
FILE="my file.txt"
ls $FILE              # ls: my: No such file — splits on space!
ls "$FILE"            # ls: my file.txt — correct!

# ── Command Substitution ──────────────────────────────────────
TODAY=$(date '+%Y-%m-%d')         # Modern syntax (preferred)
HOSTNAME_VAR=`hostname`           # Old backtick syntax (avoid)
KERNEL=$(uname -r)
USER_COUNT=$(who | wc -l)
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')

echo "Date    : $TODAY"
echo "Kernel  : $KERNEL"
echo "Users   : $USER_COUNT"
echo "Disk    : $DISK_USAGE"

# ── readonly & Constants ──────────────────────────────────────
readonly MAX_RETRIES=3
readonly LOG_DIR="/var/log/myapp"
declare -r PI=3.14159              # Same as readonly

# MAX_RETRIES=5   ← ERROR: cannot change readonly variable

# ── Integer Variables ─────────────────────────────────────────
declare -i count=0
declare -i total=100
count=count+1                      # Arithmetic without $(())
echo "Count: $count"               # 1

# ── Environment Variables ─────────────────────────────────────
export DB_HOST="localhost"         # Export to child processes
export DB_PORT=5432
export PATH="$PATH:/opt/myapp/bin" # Append to PATH

printenv                           # Show all env vars
printenv HOME                      # Show specific env var
env                                # Same as printenv

# Unset a variable
TEMP="temporary"
unset TEMP
echo "${TEMP:-empty}"              # empty (variable gone)

# ── Special / Built-in Variables ─────────────────────────────
echo "Script name    : $0"         # Name of current script
echo "First argument : $1"         # First positional argument
echo "Second argument: $2"         # Second positional argument
echo "All arguments  : $@"         # All args (separate quoted strings)
echo "All arguments  : $*"         # All args (single string)
echo "Arg count      : $#"         # Number of arguments
echo "Current PID    : $$"         # PID of current bash process
echo "Last PID       : $!"         # PID of last background process
echo "Last exit code : $?"         # Exit code of last command
echo "Bash version   : $BASH_VERSION"
echo "Home directory : $HOME"
echo "Current user   : $USER"
echo "Current dir    : $PWD"
echo "Previous dir   : $OLDPWD"
echo "Hostname       : $HOSTNAME"

# ── Variable Expansion & Defaults ────────────────────────────
UNSET_VAR=""

echo "${UNSET_VAR:-default}"       # Use "default" if unset or empty
echo "${UNSET_VAR:=default}"       # Set AND use "default" if unset/empty
echo "${UNSET_VAR:+replacement}"   # Use "replacement" if SET and non-empty
echo "${UNSET_VAR:?error message}" # Print error and exit if unset/empty

NAME="Alexander"
echo "${NAME:0:4}"                 # Alex        (substring: start=0, len=4)
echo "${NAME: -4}"                 # nder        (last 4 chars)
echo "${NAME^^}"                   # ALEXANDER   (uppercase)
echo "${NAME,,}"                   # alexander   (lowercase)
echo "${#NAME}"                    # 9           (string length)

FILE="/var/log/messages.log"
echo "${FILE##*/}"                 # messages.log    (basename)
echo "${FILE%/*}"                  # /var/log         (dirname)
echo "${FILE%.log}"                # /var/log/messages (strip .log)
echo "${FILE/log/LOG}"             # /var/LOG/messages (replace first)
echo "${FILE//log/LOG}"            # /var/LOG/messages.LOG (replace all)

# ── Arrays ────────────────────────────────────────────────────
# Indexed array
FRUITS=("apple" "banana" "cherry" "mango")
echo "${FRUITS[0]}"                # apple
echo "${FRUITS[2]}"                # cherry
echo "${FRUITS[@]}"                # All elements
echo "${#FRUITS[@]}"               # 4 (length)
FRUITS+=("pineapple")              # Append
unset FRUITS[1]                    # Remove element

for fruit in "${FRUITS[@]}"; do
    echo "  - $fruit"
done

# Associative array (like dict/hashmap)
declare -A USER_INFO
USER_INFO[name]="Alice"
USER_INFO[age]=30
USER_INFO[role]="admin"

echo "${USER_INFO[name]}"          # Alice
echo "${!USER_INFO[@]}"            # All keys: name age role
echo "${USER_INFO[@]}"             # All values

for key in "${!USER_INFO[@]}"; do
    echo "  $key = ${USER_INFO[$key]}"
done
