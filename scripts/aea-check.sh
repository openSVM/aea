#!/usr/bin/env bash
#
# AEA Message Checker
# Simple script to check for unprocessed inter-agent messages
#
# Usage:
#   bash .aea/scripts/aea-check.sh
#
# This script is designed to be called by Claude automatically or manually

set -e

AEA_DIR=".aea"
PROCESSED_DIR=".aea/.processed"
LOG_FILE=".aea/agent.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Log script usage for validation
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$timestamp] aea-check.sh: Script started correctly (avoiding manual bash commands)" >> "$LOG_FILE"

# Validation check: Ensure running from correct directory
if [ ! -d "$AEA_DIR" ]; then
    echo -e "${RED}❌ Error: Not running from correct directory. AEA directory not found.${NC}"
    echo "[$timestamp] aea-check.sh: ERROR - AEA directory not found, possible incorrect usage" >> "$LOG_FILE"
    exit 1
fi

# Ensure processed directory exists
mkdir -p "$PROCESSED_DIR"

# Find unprocessed messages
unprocessed=()
for msg in "$AEA_DIR"/message-*.json; do
    # Skip if glob didn't match any files
    [ -e "$msg" ] || continue

    # Use parameter expansion instead of basename subprocess
    basename_msg="${msg##*/}"

    if [ ! -f "$PROCESSED_DIR/$basename_msg" ]; then
        unprocessed+=("$msg")
    fi
done

# Report findings
if [ ${#unprocessed[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ No new AEA messages${NC}"
    exit 0
fi

echo -e "${YELLOW}📬 Found ${#unprocessed[@]} unprocessed message(s):${NC}"
echo ""

# List unprocessed messages with details
for msg in "${unprocessed[@]}"; do
    # Use parameter expansion instead of basename
    basename_msg="${msg##*/}"
    echo -e "${YELLOW}  • $basename_msg${NC}"

    # Extract key info from JSON (v0.1.0 protocol)
    if command -v jq &> /dev/null; then
        # Single jq invocation to extract all fields at once
        msg_data=$(jq -r '"\(.message_type // "unknown")|\(.routing.priority // "normal")|\(.sender.agent_id // "unknown")|\(.content.subject // "No subject")"' "$msg" 2>/dev/null || echo "unknown|normal|unknown|No subject")

        IFS='|' read -r msg_type priority from_agent subject <<< "$msg_data"

        echo "    Type: $msg_type | Priority: $priority | From: $from_agent"
        echo "    Subject: $subject"
    else
        echo -e "${RED}    ⚠️  jq not installed - cannot parse message details${NC}"
        echo "    Install: apt-get install jq (Debian/Ubuntu) or brew install jq (Mac)"
    fi
    echo ""
done

# Provide instructions
echo -e "${GREEN}📋 Next steps:${NC}"
echo "  1. Run: /aea"
echo "  2. Or ask Claude: 'Process AEA messages'"
echo "  3. Claude will autonomously process messages according to policy"
echo ""

# Log this check
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "[$timestamp] AEA check: ${#unprocessed[@]} unprocessed messages found" >> "$LOG_FILE"

exit 1  # Exit with error code so caller knows there are messages
