#!/bin/bash

# =====================================================================
# AppDynamics Status Check Script (Solaris Servers)
# =====================================================================

source /home/gs185313/gaurav_s/appd_status/cnfg_AppD.sh

EMAIL="$EMAIL_RECIPIENT"
REPORT="$REPORT_PATH"
SERVER_FILE="$SERVER_FILE_PATH"
USERNAME="$SCRIPT_USERNAME"
PASSWORD="$SCRIPT_PASSWORD"

SERVERS=()

# Read server list
if [ -f "$SERVER_FILE" ]; then
    while IFS= read -r host || [ -n "$host" ]; do
        host=$(echo "$host" | xargs)
        if [[ ! "$host" =~ ^\s*# ]] && [[ -n "$host" ]]; then
            SERVERS+=("$host")
        fi
    done < "$SERVER_FILE"
else
    echo "Error: Server file $SERVER_FILE not found."
    exit 1
fi

# CSV Header
echo "Server,AppD Status,Installation Status" > "$REPORT"

# Function to execute SSH (FIXED VERSION)
run_remote_check() {
    local target="$1"
    local command_str="$2"

    output=$(sshpass -p "$PASSWORD" ssh \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    -o ConnectionAttempts=1 \
    -o LogLevel=ERROR \
    "${USERNAME}@${target}" "$command_str" 2>&1)

    # ✅ Clean output
    output=$(echo "$output" | tr -d '\r' | sed '/^$/d' | tail -1)

    # ✅ Detect failures
    if echo "$output" | grep -qi "Could not resolve hostname"; then
        echo "DNS_FAILED"

    elif echo "$output" | grep -qi "Permission denied\|Authentication failed"; then
        echo "AUTH_FAILED"

    elif echo "$output" | grep -qi "Connection refused\|No route to host\|timed out"; then
        echo "SSH_FAILED"

    else
        echo "$output"
    fi
}

# Loop through servers
for HOSTNAME in "${SERVERS[@]}"; do

    echo "Checking $HOSTNAME..."

    REMOTE_COMMAND="PATH=/usr/bin:/usr/sbin:/bin:/sbin; \
    RESULT='N/A,Not Installed'; \
    if [ -x /opt/appdynamics/appdagent ]; then \
        STATUS=\`/opt/appdynamics/appdagent status 2>/dev/null\`; \
        echo \"\$STATUS\" | grep -qi up && RESULT='Up,Installed' || RESULT='Down,Installed'; \
    elif [ -d /opt/appdynamics ]; then \
        AGENT_DIR=\`ls -d /opt/appdynamics/MachineAgent-* 2>/dev/null | head -1\`; \
        if [ -n \"\$AGENT_DIR\" ]; then \
            pgrep -f machineagent >/dev/null 2>&1 && RESULT='Up,Installed' || RESULT='Down,Installed'; \
        fi; \
    fi; \
    echo \$RESULT"

    OUTPUT=$(run_remote_check "$HOSTNAME" "$REMOTE_COMMAND")

    # ✅ FINAL CLASSIFICATION
    if [[ "$OUTPUT" == "DNS_FAILED" ]]; then
        DATA_LINE="$HOSTNAME,Unreachable,Unknown"

    elif [[ "$OUTPUT" == "AUTH_FAILED" ]]; then
        DATA_LINE="$HOSTNAME,Unreachable,Authentication Failed"

    elif [[ "$OUTPUT" == "SSH_FAILED" ]]; then
        DATA_LINE="$HOSTNAME,Unreachable,Unknown"

    elif [[ -z "$OUTPUT" ]]; then
        DATA_LINE="$HOSTNAME,N/A,Not Installed"

    else
        DATA_LINE="$HOSTNAME,$OUTPUT"
    fi

    echo "$DATA_LINE" >> "$REPORT"

done

# Send email
mail -s "Sun Solaris Servers AppDynamics Status Report - ($(date +'%Y-%m-%d'))" \
-a "$REPORT" \
-r "Gaurav Sahu GSSM-UNIX-Gurgaon <gs185313@ncrvoyix.com>" \
"$EMAIL" <<EOF

Hello All,

Please find attached the AppDynamics status report for Solaris servers.

Columns:
- AppD Status → Up / Down / Unreachable
- Installation Status → Installed / Not Installed / Unknown


Regards,
Gaurav Sahu
Unix Engineering Team
Gurgaon, India
gaurav.sahu@ncrvoyix.com | ncrvoyix.com
EOF
