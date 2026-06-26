#!/bin/bash
# =============================================================
#  Day 14 - Real-World Sysadmin Scripts
# =============================================================
#  This lesson covers practical, production-ready scripts
#  that a RHEL 9 system administrator uses daily:
#   - Bulk user management
#   - System hardening checks
#   - Package audit
#   - SSH key deployment
#   - Server inventory collection
# =============================================================

set -euo pipefail

# ── Bulk User Creation from CSV ───────────────────────────────
# CSV format: username,fullname,group,shell
# alice,Alice Smith,developers,/bin/bash
# bob,Bob Jones,ops,/bin/bash

bulk_create_users() {
    local csv_file="$1"
    local default_pass="${2:-ChangeMe123!}"

    [[ ! -f "$csv_file" ]] && { echo "CSV not found: $csv_file"; return 1; }

    local created=0 skipped=0 failed=0

    while IFS=',' read -r username fullname group shell; do
        [[ "$username" =~ ^# ]] && continue   # Skip comments
        [[ -z "$username" ]]    && continue   # Skip empty lines

        if id "$username" &>/dev/null; then
            echo "SKIP: $username already exists"
            ((skipped++))
            continue
        fi

        # Create group if needed
        groupadd "$group" 2>/dev/null || true

        # Create user
        if useradd -m -c "$fullname" -G "$group" -s "$shell" "$username"; then
            echo "$username:$default_pass" | chpasswd
            passwd -e "$username"          # Force password change on first login
            echo "CREATED: $username ($fullname) → group: $group"
            ((created++))
        else
            echo "FAILED: $username"
            ((failed++))
        fi

    done < <(grep -v '^#' "$csv_file")   # Skip comment lines

    echo ""
    echo "Summary: Created=$created Skipped=$skipped Failed=$failed"
}

# ── SSH Key Deployment to Multiple Servers ────────────────────
deploy_ssh_key() {
    local pub_key="$1"
    local remote_user="${2:-root}"
    shift 2
    local servers=("$@")

    [[ ! -f "$pub_key" ]] && { echo "Public key not found: $pub_key"; return 1; }

    local key_content=$(cat "$pub_key")
    local success=0 failed=0

    for server in "${servers[@]}"; do
        echo -n "Deploying to $server... "
        if ssh -o StrictHostKeyChecking=no \
               -o ConnectTimeout=10 \
               -o BatchMode=yes \
               "$remote_user@$server" \
               "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
                echo '$key_content' >> ~/.ssh/authorized_keys && \
                chmod 600 ~/.ssh/authorized_keys && \
                sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys" 2>/dev/null; then
            echo "OK"
            ((success++))
        else
            echo "FAILED"
            ((failed++))
        fi
    done

    echo "Deployed: $success OK, $failed failed"
}

# ── CIS Hardening Check ───────────────────────────────────────
security_audit() {
    local PASS=0 FAIL=0 WARN=0
    local report_file="/tmp/security-audit-$(date +%Y%m%d).txt"

    check() {
        local desc="$1"; shift
        if "$@" &>/dev/null; then
            echo "  [PASS] $desc"
            ((PASS++))
        else
            echo "  [FAIL] $desc"
            ((FAIL++))
        fi
    }

    {
        echo "=============================="
        echo " Security Audit Report"
        echo " Host: $(hostname)"
        echo " Date: $(date)"
        echo "=============================="

        echo ""
        echo "── SSH Hardening ──────────────────"
        check "Root login disabled"       grep -q "^PermitRootLogin no"        /etc/ssh/sshd_config
        check "Password auth disabled"    grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config
        check "MaxAuthTries <= 4"         awk '/^MaxAuthTries/{exit $2<=4?0:1}' /etc/ssh/sshd_config
        check "Protocol 2 enforced"       grep -q "^Protocol 2"                /etc/ssh/sshd_config

        echo ""
        echo "── Firewall ───────────────────────"
        check "firewalld is active"       systemctl is-active firewalld
        check "firewalld is enabled"      systemctl is-enabled firewalld

        echo ""
        echo "── SELinux ────────────────────────"
        check "SELinux is enforcing"      [ "$(getenforce)" = "Enforcing" ]

        echo ""
        echo "── Password Policy ────────────────"
        check "Max password age <= 90"    awk '/^PASS_MAX_DAYS/{exit $2<=90?0:1}'  /etc/login.defs
        check "Min password length >= 8"  awk '/^PASS_MIN_LEN/{exit $2>=8?0:1}'   /etc/login.defs
        check "Min password age >= 1"     awk '/^PASS_MIN_DAYS/{exit $2>=1?0:1}'  /etc/login.defs

        echo ""
        echo "── Services ───────────────────────"
        check "sshd is running"           systemctl is-active sshd
        check "telnet not installed"      ! rpm -q telnet-server &>/dev/null
        check "rsh not installed"         ! rpm -q rsh-server &>/dev/null
        check "ftp not installed"         ! rpm -q vsftpd &>/dev/null

        echo ""
        echo "=============================="
        echo " PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
        echo "=============================="

    } | tee "$report_file"

    echo "Report: $report_file"
    return $FAIL
}

# ── Server Inventory Collector ────────────────────────────────
collect_inventory() {
    local output_file="${1:-/tmp/inventory-$(hostname)-$(date +%Y%m%d).json}"

    python3 - << PYEOF > "$output_file"
import subprocess, json, datetime

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except:
        return "N/A"

inventory = {
    "collected_at": datetime.datetime.now().isoformat(),
    "hostname": run("hostname"),
    "ip_addresses": run("hostname -I").split(),
    "os": run("cat /etc/redhat-release"),
    "kernel": run("uname -r"),
    "arch": run("uname -m"),
    "cpu": run("grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2").strip(),
    "cpu_cores": int(run("nproc") or 0),
    "memory_gb": round(int(run("grep MemTotal /proc/meminfo | awk '{print \$2}') or 0) / 1024 / 1024, 1),
    "disk_gb": run("df -h / | awk 'NR==2{print \$2}'"),
    "selinux": run("getenforce"),
    "uptime": run("uptime -p"),
    "running_services": run("systemctl list-units --type=service --state=active --no-legend | awk '{print \$1}'").split()
}

print(json.dumps(inventory, indent=2))
PYEOF

    echo "Inventory saved: $output_file"
    cat "$output_file"
}

# Uncomment to run:
# security_audit
# collect_inventory
