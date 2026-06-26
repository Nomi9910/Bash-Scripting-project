#!/bin/bash
# =============================================================
#  Day 3 - User Input & Script Arguments
# =============================================================
#  Scripts become dynamic when they accept input — either
#  interactively (read) or via command-line arguments ($1, $2...).
#
#  Two ways to get input:
#   1. Command-line arguments: ./script.sh arg1 arg2
#   2. Interactive prompts:    read -p "Enter name: " NAME
#
#  Best practice: always validate input before using it.
# =============================================================

# ── Command-Line Arguments ────────────────────────────────────
# Run as: ./script.sh Alice 30 admin

echo "Script name : $0"
echo "Arg 1       : $1"        # Alice
echo "Arg 2       : $2"        # 30
echo "Arg 3       : $3"        # admin
echo "All args    : $@"        # Alice 30 admin
echo "Arg count   : $#"        # 3

# Shift — move positional params left
echo "Before shift: \$1=$1"
shift                          # Discard $1, $2 becomes $1, etc.
echo "After shift : \$1=$1"

# ── Validating Arguments ──────────────────────────────────────
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <username> <action>"
    echo "Example: $0 alice start"
    exit 1
fi

USERNAME="$1"
ACTION="$2"
echo "User: $USERNAME | Action: $ACTION"

# ── Default Values for Arguments ─────────────────────────────
SERVER="${1:-localhost}"       # Default to localhost if $1 is empty
PORT="${2:-8080}"              # Default to 8080 if $2 is empty
ENV="${3:-production}"

echo "Connecting to $SERVER:$PORT in $ENV mode"

# ── Interactive Input with read ───────────────────────────────
read -p "Enter your name: " NAME
echo "Hello, $NAME!"

read -p "Enter your age: " AGE
echo "You are $AGE years old."

# Silent input (passwords)
read -sp "Enter password: " PASSWORD
echo
echo "Password received (length: ${#PASSWORD})"

# Read with timeout
read -t 10 -p "You have 10 seconds to answer: " ANSWER
if [ $? -ne 0 ]; then
    echo "Timed out!"
fi

# Read with default value
read -p "Enter environment [production]: " ENV
ENV="${ENV:-production}"
echo "Environment: $ENV"

# Read single character (no Enter needed)
read -n 1 -p "Continue? (y/n): " CHOICE
echo
if [[ "$CHOICE" == "y" || "$CHOICE" == "Y" ]]; then
    echo "Continuing..."
else
    echo "Aborted."
    exit 0
fi

# ── Reading from a File ───────────────────────────────────────
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/hostname

# Read CSV file
while IFS=',' read -r name age city; do
    echo "Name: $name | Age: $age | City: $city"
done < users.csv

# ── getopts — Parsing Flags & Options ────────────────────────
# Usage: ./script.sh -u alice -p 8080 -v

usage() {
    echo "Usage: $0 [-u username] [-p port] [-v] [-h]"
    echo "  -u  Username (required)"
    echo "  -p  Port number (default: 8080)"
    echo "  -v  Verbose mode"
    echo "  -h  Show this help"
    exit 1
}

VERBOSE=false
PORT=8080
USERNAME=""

while getopts ":u:p:vh" opt; do
    case $opt in
        u) USERNAME="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        v) VERBOSE=true ;;
        h) usage ;;
        :) echo "Option -$OPTARG requires an argument."; usage ;;
        \?) echo "Unknown option: -$OPTARG"; usage ;;
    esac
done

shift $((OPTIND - 1))      # Remove processed options, leave remaining args

[ -z "$USERNAME" ] && { echo "Error: username is required."; usage; }

echo "Username : $USERNAME"
echo "Port     : $PORT"
echo "Verbose  : $VERBOSE"
$VERBOSE && echo "[VERBOSE] Debug mode enabled"

# ── select — Interactive Menu ──────────────────────────────────
echo "Select an action:"
select ACTION in "Start Service" "Stop Service" "Restart Service" "Check Status" "Quit"; do
    case $ACTION in
        "Start Service")   echo "Starting...";   break ;;
        "Stop Service")    echo "Stopping...";   break ;;
        "Restart Service") echo "Restarting..."; break ;;
        "Check Status")    echo "Checking...";   break ;;
        "Quit")            echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option. Try again." ;;
    esac
done
