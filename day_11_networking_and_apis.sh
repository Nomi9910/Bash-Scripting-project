#!/bin/bash
# =============================================================
#  Day 11 - Networking & API Calls in Bash Scripts
# =============================================================
#  Scripts often need to check network connectivity, test ports,
#  query REST APIs, and send notifications (Slack, email, etc.).
#
#  Key tools:
#   curl    — HTTP requests, API calls, file downloads
#   wget    — file downloads
#   nc      — port testing (netcat)
#   ping    — ICMP connectivity
#   ss/nc   — port scanning
#   dig/nslookup — DNS queries
# =============================================================

# ── Connectivity Checks ───────────────────────────────────────
check_connectivity() {
    local host="${1:-8.8.8.8}"
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        echo "Connected to $host"
        return 0
    else
        echo "Cannot reach $host"
        return 1
    fi
}

check_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    if nc -zw "$timeout" "$host" "$port" &>/dev/null; then
        echo "Port $port on $host is OPEN"
        return 0
    else
        echo "Port $port on $host is CLOSED or unreachable"
        return 1
    fi
}

check_connectivity "google.com"
check_port "localhost" 22
check_port "localhost" 80
check_port "localhost" 443

# ── HTTP Checks with curl ─────────────────────────────────────
check_http() {
    local url="$1"
    local expected_code="${2:-200}"
    local timeout="${3:-10}"

    response=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$timeout" \
        --max-time "$((timeout * 2))" \
        "$url")

    if [[ "$response" == "$expected_code" ]]; then
        echo "OK    [$response] $url"
        return 0
    else
        echo "FAIL  [$response] $url (expected $expected_code)"
        return 1
    fi
}

check_http "https://google.com"
check_http "https://api.github.com" 200
check_http "http://localhost:8080/health" 200

# ── REST API Calls ────────────────────────────────────────────
# GET request
api_get() {
    local url="$1"
    local token="${2:-}"
    local auth_header=""
    [[ -n "$token" ]] && auth_header="-H \"Authorization: Bearer $token\""

    curl -sf \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        ${token:+-H "Authorization: Bearer $token"} \
        "$url"
}

# POST request
api_post() {
    local url="$1"
    local data="$2"
    local token="${3:-}"

    curl -sf -X POST \
        -H "Content-Type: application/json" \
        ${token:+-H "Authorization: Bearer $token"} \
        -d "$data" \
        "$url"
}

# GitHub API example
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [[ -n "$GITHUB_TOKEN" ]]; then
    USER_INFO=$(api_get "https://api.github.com/user" "$GITHUB_TOKEN")
    echo "GitHub user: $(echo "$USER_INFO" | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])")"
fi

# ── Parsing JSON with jq ──────────────────────────────────────
# Install: dnf install -y jq
if command -v jq &>/dev/null; then
    # Parse API response
    RESPONSE='{"status":"ok","version":"1.2.3","uptime":12345}'
    echo "$RESPONSE" | jq '.status'
    echo "$RESPONSE" | jq -r '.version'        # -r = raw (no quotes)
    echo "$RESPONSE" | jq '.uptime / 3600 | floor'

    # Array processing
    USERS='[{"name":"Alice","role":"admin"},{"name":"Bob","role":"user"}]'
    echo "$USERS" | jq -r '.[] | .name'         # Extract all names
    echo "$USERS" | jq -r '.[] | select(.role=="admin") | .name'
fi

# ── Sending Notifications ─────────────────────────────────────
# Slack webhook notification
send_slack() {
    local webhook_url="$1"
    local message="$2"
    local channel="${3:-#alerts}"

    curl -sf -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "{\"channel\":\"$channel\",\"text\":\"$message\"}" \
        > /dev/null
    echo "Slack notification sent"
}

# Email via sendmail / mailx
send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    echo "$body" | mail -s "$subject" "$to"
    echo "Email sent to $to"
}

# ── Downloading Files ─────────────────────────────────────────
download_file() {
    local url="$1"
    local output="${2:-$(basename "$url")}"
    local checksum="${3:-}"

    echo "Downloading: $url"
    curl -fsSL -o "$output" "$url" || { echo "Download failed!"; return 1; }

    if [[ -n "$checksum" ]]; then
        actual=$(sha256sum "$output" | awk '{print $1}')
        if [[ "$actual" != "$checksum" ]]; then
            echo "Checksum MISMATCH! File may be corrupted."
            rm -f "$output"
            return 1
        fi
        echo "Checksum verified OK"
    fi

    echo "Downloaded: $output ($(du -sh "$output" | cut -f1))"
}

# Wait for a service to respond
wait_for_service() {
    local url="$1"
    local max_wait="${2:-60}"
    local interval="${3:-5}"
    local elapsed=0

    echo "Waiting for $url to become available..."
    while ! curl -sf "$url" &>/dev/null; do
        [[ $elapsed -ge $max_wait ]] && { echo "Timeout after ${max_wait}s!"; return 1; }
        echo "  Not ready yet... (${elapsed}s elapsed)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    echo "Service is UP after ${elapsed}s"
}
