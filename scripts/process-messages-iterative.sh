#!/bin/bash

# AEA Message Processing Script - Iterative with Context Compaction
# Processes messages one by one, compacting context after each

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - resolve .aea directory from script location
# Handle both cases: script in scripts/ subdirectory or in .aea/ root
SCRIPT_REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_REAL_PATH")" && pwd)"

# Find .aea directory (parent of scripts/ or current if scripts don't exist)
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    AEA_DIR="$(dirname "$SCRIPT_DIR")"
else
    AEA_DIR="$SCRIPT_DIR"
fi

# Validate we're in an AEA directory
if [ ! -d "$AEA_DIR/.processed" ] && [ ! -f "$AEA_DIR/agent-config.yaml" ]; then
    echo "ERROR: Could not locate .aea directory from script location"
    echo "Script: $SCRIPT_REAL_PATH"
    echo "Resolved AEA_DIR: $AEA_DIR"
    exit 1
fi

AGENT_ID=$(grep "^  id:" "$AEA_DIR/agent-config.yaml" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "claude-aea")
PROCESSED_DIR="${AEA_DIR}/.processed"
LOG_FILE="${AEA_DIR}/agent.log"

# Ensure directories exist
mkdir -p "$PROCESSED_DIR"

# Logging function
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "${GREEN}✓${NC} $1"
}

# Error logging
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    echo -e "${RED}✗${NC} ERROR: $1"
}

# Find unprocessed messages
find_unprocessed_messages() {
    local unprocessed=()

    for msg in "${AEA_DIR}"/message-*.json; do
        # Skip if glob didn't match any files
        [ -e "$msg" ] || continue

        # Use parameter expansion instead of basename subprocess
        local basename="${msg##*/}"

        if [ ! -f "${PROCESSED_DIR}/${basename}" ]; then
            unprocessed+=("$msg")
        fi
    done

    # Output array elements (will be read into array by caller)
    printf '%s\n' "${unprocessed[@]}"
}

# Process a single message
process_message() {
    local msg_file="$1"
    # Use parameter expansion instead of basename
    local basename="${msg_file##*/}"

    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📬 Processing: ${basename}${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"

    # Extract message details (v0.1.0 protocol)
    # Check jq availability
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Install: apt-get install jq (Debian/Ubuntu) or brew install jq (Mac)"
        return 1
    fi

    # Single jq invocation for better performance
    local msg_data=$(jq -r '"\(.message_type // "unknown")|\(.routing.priority // "normal")|\(.sender.agent_id // "unknown")|\(.routing.requires_response // false)"' "$msg_file" 2>/dev/null || echo "unknown|normal|unknown|false")

    IFS='|' read -r message_type priority from_agent requires_response <<< "$msg_data"

    echo "Type: $message_type"
    echo "Priority: $priority"
    echo "From: $from_agent"
    echo "Requires Response: $requires_response"
    echo ""

    # Display message content
    echo "Message Content:"
    jq -C '.content' "$msg_file" 2>/dev/null || cat "$msg_file"
    echo ""

    # Determine action based on type and priority
    local action="review"
    local auto_process="false"

    case "$message_type" in
        "question")
            action="auto-respond"
            auto_process="true"
            ;;
        "update")
            if [ "$priority" = "normal" ] || [ "$priority" = "low" ]; then
                action="auto-acknowledge"
                auto_process="true"
            else
                action="summarize-to-user"
                auto_process="true"
            fi
            ;;
        "issue")
            if [ "$priority" = "high" ] || [ "$priority" = "urgent" ]; then
                action="notify-user"
                auto_process="false"
            else
                action="auto-analyze"
                auto_process="true"
            fi
            ;;
        "handoff")
            action="review-with-user"
            auto_process="false"
            ;;
        "request")
            action="evaluate"
            auto_process="false"
            ;;
        *)
            action="unknown"
            auto_process="false"
            ;;
    esac

    echo -e "${GREEN}Recommended Action: ${action}${NC}"
    echo "Auto-processable: $auto_process"
    echo ""

    # Ask for user confirmation
    if [ "$auto_process" = "true" ]; then
        echo -e "${YELLOW}This message can be processed automatically.${NC}"
        read -p "Process automatically? (y/n/skip): " choice
    else
        echo -e "${YELLOW}This message requires review.${NC}"
        read -p "How to proceed? (review/skip): " choice
    fi

    case "$choice" in
        y|yes|review)
            echo ""
            echo "Processing message..."

            # Create processing instruction file
            cat > "${AEA_DIR}/current-message-instruction.md" << EOF
# Process AEA Message

**Message File:** $basename
**Type:** $message_type
**Priority:** $priority
**From:** $from_agent
**Action:** $action

## Instructions

Based on the message type and priority, please:

$(case "$action" in
    "auto-respond")
        echo "1. Read the question from the message"
        echo "2. Search the codebase for relevant information"
        echo "3. Generate a technical answer with code references"
        echo "4. Create response message in the sender's .aea directory"
        ;;
    "auto-acknowledge")
        echo "1. Read and understand the update"
        echo "2. If requires_response is true, create acknowledgment message"
        echo "3. Log the update information"
        ;;
    "summarize-to-user")
        echo "1. Read the high-priority update"
        echo "2. Summarize key points for the user"
        echo "3. Highlight any action items"
        ;;
    "auto-analyze")
        echo "1. Analyze the reported issue"
        echo "2. Search codebase for related code"
        echo "3. Suggest potential fixes"
        echo "4. Create response with analysis"
        ;;
    "notify-user")
        echo "1. Summarize the high-priority issue"
        echo "2. Explain potential impact"
        echo "3. Ask user for permission to act"
        ;;
    "review-with-user")
        echo "1. Summarize the handoff request"
        echo "2. Explain what's being handed off"
        echo "3. Wait for user approval"
        ;;
    "evaluate")
        echo "1. Analyze the request"
        echo "2. Create a plan to address it"
        echo "3. Send plan as response"
        ;;
    *)
        echo "1. Review the message"
        echo "2. Determine appropriate action"
        ;;
esac)

## Message Content

\`\`\`json
$(cat "$msg_file")
\`\`\`

## After Processing

Mark as processed:
\`\`\`bash
touch "${PROCESSED_DIR}/${basename}"
\`\`\`

Log action:
\`\`\`bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed $message_type from $from_agent: [YOUR_ACTION_SUMMARY]" >> "${LOG_FILE}"
\`\`\`
EOF

            echo -e "${GREEN}✓ Created instruction file: ${AEA_DIR}/current-message-instruction.md${NC}"
            echo ""
            echo "Please process this message now, then we'll continue with the next one."

            # Mark for processing
            echo "$basename" > "${AEA_DIR}/.current-processing"

            # Return to let AI process
            exit 0
            ;;

        skip|s)
            log_action "Skipped message: $basename"
            echo -e "${YELLOW}⊘ Skipping message${NC}"
            # Don't mark as processed, so it can be reviewed later
            ;;

        n|no)
            log_action "Deferred message: $basename"
            echo -e "${YELLOW}⏸ Deferring message for later${NC}"
            # Don't mark as processed
            ;;

        *)
            echo "Invalid choice. Skipping."
            ;;
    esac

    echo ""
    return 0
}

# Main execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   AEA Message Processing (Iterative)   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    # Check if we're continuing from a previous message
    if [ -f "${AEA_DIR}/.current-processing" ]; then
        local last_msg=$(cat "${AEA_DIR}/.current-processing")
        echo -e "${GREEN}✓ Marking previous message as processed: $last_msg${NC}"
        touch "${PROCESSED_DIR}/${last_msg}"
        rm "${AEA_DIR}/.current-processing"
        rm -f "${AEA_DIR}/current-message-instruction.md"
        log_action "Completed processing: $last_msg"
        echo ""

        # Note: Context compaction is a Claude Code feature that must be triggered manually
        # This script cannot automatically trigger /compact - user must do this themselves if needed
        echo -e "${YELLOW}Note: If you want to compact context, run /compact${NC}"
        echo ""
    fi

    # Find unprocessed messages (read into array properly)
    local unprocessed=()
    while IFS= read -r msg; do
        [ -n "$msg" ] && unprocessed+=("$msg")
    done < <(find_unprocessed_messages)

    if [ ${#unprocessed[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No unprocessed messages found${NC}"
        log_action "No unprocessed messages"
        exit 0
    fi

    echo "Found ${#unprocessed[@]} unprocessed message(s)"
    echo ""

    # Process the first unprocessed message
    if [ ${#unprocessed[@]} -gt 0 ]; then
        process_message "${unprocessed[0]}"

        # Check if there are more messages
        if [ ${#unprocessed[@]} -gt 1 ]; then
            echo -e "${YELLOW}Note: ${NC}There are $((${#unprocessed[@]} - 1)) more message(s) to process."
            echo "Run this script again after processing the current message."
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ Script completed${NC}"
}

# Run main function
main "$@"