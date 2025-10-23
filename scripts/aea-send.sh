#!/bin/bash
# aea-send.sh - Send messages to other AEA agents
# Supports cross-repository message delivery via registry

set -euo pipefail

# Get script directory for sourcing registry functions (resolve symlinks)
SCRIPT_REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_REAL_PATH")" && pwd)"

# Find .aea directory
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    AEA_ROOT="$(dirname "$SCRIPT_DIR")"
else
    AEA_ROOT="$SCRIPT_DIR"
fi

# Source registry functions if available (check multiple locations)
if [ -f "$SCRIPT_DIR/aea-registry.sh" ]; then
    source "$SCRIPT_DIR/aea-registry.sh"
elif [ -f "$AEA_ROOT/scripts/aea-registry.sh" ]; then
    source "$AEA_ROOT/scripts/aea-registry.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==============================================================================
# Usage
# ==============================================================================

usage() {
    cat << EOF
AEA Message Sender - Send messages to other AEA agents

Usage: $(basename "$0") [OPTIONS]

Required Options:
    --to <agent_id>             Destination agent ID
    --type <type>               Message type (question|issue|update|request|handoff|response)
    --subject <subject>         Message subject
    --message <body>            Message body

Optional:
    --priority <level>          Priority (low|normal|high|urgent) [default: normal]
    --requires-response         Message requires a response
    --context <json>            Additional context (JSON string)
    --correlation-id <id>       Conversation thread ID
    --local-only                Save to local .aea/ only (don't deliver)

Examples:
    # Ask a question
    $(basename "$0") \\
        --to backend-agent \\
        --type question \\
        --subject "Authentication implementation" \\
        --message "What files handle user authentication?"

    # Report an issue
    $(basename "$0") \\
        --to frontend-agent \\
        --type issue \\
        --priority high \\
        --subject "API endpoint changed" \\
        --message "Login endpoint moved to /api/v2/auth/login" \\
        --requires-response

    # Send update
    $(basename "$0") \\
        --to deployment-agent \\
        --type update \\
        --subject "Database migration complete" \\
        --message "Migration 2025_001 applied successfully"

EOF
}

# ==============================================================================
# Parse Arguments
# ==============================================================================

TO_AGENT=""
MESSAGE_TYPE=""
SUBJECT=""
MESSAGE_BODY=""
PRIORITY="normal"
REQUIRES_RESPONSE="false"
CONTEXT="{}"
CORRELATION_ID=""
LOCAL_ONLY="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --to)
            TO_AGENT="$2"
            shift 2
            ;;
        --type)
            MESSAGE_TYPE="$2"
            shift 2
            ;;
        --subject)
            SUBJECT="$2"
            shift 2
            ;;
        --message)
            MESSAGE_BODY="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --requires-response)
            REQUIRES_RESPONSE="true"
            shift
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        --correlation-id)
            CORRELATION_ID="$2"
            shift 2
            ;;
        --local-only)
            LOCAL_ONLY="true"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ==============================================================================
# Validate Required Arguments
# ==============================================================================

if [ -z "$TO_AGENT" ]; then
    log_error "Missing required argument: --to"
    echo ""
    echo "💡 How to fix: Add --to with the destination agent ID"
    echo "Example: $0 --to backend-agent ..."
    echo ""
    echo "📚 List registered agents: bash scripts/aea-registry.sh list"
    exit 1
fi

if [ -z "$MESSAGE_TYPE" ]; then
    log_error "Missing required argument: --type"
    echo ""
    echo "💡 How to fix: Add --type with one of these:"
    echo "  question  - Ask for information"
    echo "  issue     - Report a bug"
    echo "  update    - Share status"
    echo "  request   - Request changes"
    echo "  handoff   - Transfer work"
    echo ""
    exit 1
fi

if [ -z "$SUBJECT" ]; then
    log_error "Missing required argument: --subject"
    echo ""
    echo "💡 How to fix: Add --subject with a brief title"
    echo "Example: --subject \"How does auth work?\""
    echo ""
    exit 1
fi

if [ -z "$MESSAGE_BODY" ]; then
    log_error "Missing required argument: --message"
    echo ""
    echo "💡 How to fix: Add --message with detailed content"
    echo "Example: --message \"I need help understanding...\""
    echo ""
    exit 1
fi

# Validate message type
case "$MESSAGE_TYPE" in
    question|issue|update|request|handoff|response)
        ;;
    *)
        log_error "Invalid message type: $MESSAGE_TYPE"
        log_info "Valid types: question, issue, update, request, handoff, response"
        exit 1
        ;;
esac

# Validate priority
case "$PRIORITY" in
    low|normal|high|urgent)
        ;;
    *)
        log_error "Invalid priority: $PRIORITY"
        log_info "Valid priorities: low, normal, high, urgent"
        exit 1
        ;;
esac

# ==============================================================================
# Get Source Agent Info
# ==============================================================================

# Try to get agent_id from local config
SOURCE_AGENT=""
if [ -f ".aea/agent-config.yaml" ]; then
    SOURCE_AGENT=$(grep "^agent_id:" .aea/agent-config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
fi

if [ -z "$SOURCE_AGENT" ]; then
    # Use directory name as fallback
    SOURCE_AGENT="claude-$(basename "$(pwd)")"
    log_warning "No agent_id in config, using: $SOURCE_AGENT"
fi

# Validate agent_id format
if ! echo "$SOURCE_AGENT" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    log_error "Invalid agent_id format: $SOURCE_AGENT"
    log_info "Agent IDs must contain only alphanumeric characters, hyphens, and underscores"
    exit 1
fi

SOURCE_PATH="$(pwd)"
SOURCE_USER="${USER:-unknown}"

# Source common utilities for timestamp functions
if [ -f "$SCRIPT_DIR/aea-common.sh" ]; then
    source "$SCRIPT_DIR/aea-common.sh"
    TIMESTAMP_COMPACT=$(get_timestamp_compact)
    TIMESTAMP_ISO=$(get_timestamp_iso8601)
elif [ -f "$AEA_ROOT/scripts/aea-common.sh" ]; then
    source "$AEA_ROOT/scripts/aea-common.sh"
    TIMESTAMP_COMPACT=$(get_timestamp_compact)
    TIMESTAMP_ISO=$(get_timestamp_iso8601)
else
    # Fallback if common utilities not available
    TIMESTAMP_COMPACT=$(date -u +%Y%m%dT%H%M%SZ)
    TIMESTAMP_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
fi

# ==============================================================================
# Create Message
# ==============================================================================

MESSAGE_ID="msg-${TIMESTAMP_COMPACT}-$(openssl rand -hex 4 2>/dev/null || echo "$(date +%N | tail -c 6)")"
MESSAGE_FILE=".aea/message-${TIMESTAMP_COMPACT}-from-${SOURCE_AGENT}.json"

# Generate correlation ID if not provided
if [ -z "$CORRELATION_ID" ]; then
    CORRELATION_ID="conv-$(openssl rand -hex 8 2>/dev/null || echo "${TIMESTAMP_COMPACT}")"
fi

# Ensure .aea directory exists
mkdir -p .aea

# Check jq availability
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    log_info "Install: apt-get install jq (Debian/Ubuntu) or brew install jq (Mac)"
    exit 1
fi

# Create message JSON using jq for proper escaping
jq -n \
    --arg protocol_version "0.1.0" \
    --arg message_id "$MESSAGE_ID" \
    --arg message_type "$MESSAGE_TYPE" \
    --arg timestamp "$TIMESTAMP_ISO" \
    --arg priority "$PRIORITY" \
    --argjson requires_response "$REQUIRES_RESPONSE" \
    --arg source_agent "$SOURCE_AGENT" \
    --arg source_path "$SOURCE_PATH" \
    --arg source_user "$SOURCE_USER" \
    --arg to_agent "$TO_AGENT" \
    --arg subject "$SUBJECT" \
    --arg message_body "$MESSAGE_BODY" \
    --argjson context "$CONTEXT" \
    --arg correlation_id "$CORRELATION_ID" \
    '{
        protocol_version: $protocol_version,
        message_id: $message_id,
        message_type: $message_type,
        timestamp: $timestamp,
        sender: {
            agent_id: $source_agent,
            agent_type: "claude-sonnet-4.5",
            role: "AEA Agent"
        },
        recipient: {
            agent_id: $to_agent,
            broadcast: false
        },
        routing: {
            priority: $priority,
            requires_response: $requires_response
        },
        content: {
            subject: $subject,
            body: $message_body
        },
        metadata: {
            conversation_id: $correlation_id,
            tags: []
        }
    }' > "$MESSAGE_FILE"

log_success "Created message: $MESSAGE_FILE"

# ==============================================================================
# Deliver Message (Cross-Repo)
# ==============================================================================

if [ "$LOCAL_ONLY" = "true" ]; then
    log_info "Local-only mode: message saved to $MESSAGE_FILE"
    echo "$MESSAGE_FILE"
    exit 0
fi

# Get destination path from registry
log_info "Looking up destination agent: $TO_AGENT"

DEST_PATH=$(get_agent_path "$TO_AGENT" 2>/dev/null || true)

if [ -z "$DEST_PATH" ]; then
    log_error "Agent not found in registry: $TO_AGENT"
    echo ""
    echo "💡 How to fix:"
    echo "  1. Register the agent first:"
    echo "     bash scripts/aea-registry.sh register $TO_AGENT /path/to/repo \"Description\""
    echo ""
    echo "  2. Or list registered agents to find the correct name:"
    echo "     bash scripts/aea-registry.sh list"
    echo ""
    echo "📝 Your message was saved locally but NOT delivered:"
    echo "   $MESSAGE_FILE"
    echo ""
    echo "💡 After registering the agent, resend with:"
    echo "   bash $0 --to $TO_AGENT ... (same arguments)"
    echo ""
    exit 1
fi

# Validate destination path for security
case "$DEST_PATH" in
    *..*)
        log_error "Destination path contains '..' (path traversal detected)"
        log_warning "Message saved locally but NOT delivered"
        echo "$MESSAGE_FILE"
        exit 1
        ;;
    *$'\n'*|*$'\0'*)
        log_error "Destination path contains invalid characters"
        log_warning "Message saved locally but NOT delivered"
        echo "$MESSAGE_FILE"
        exit 1
        ;;
esac

# Check if destination is reachable
if [ ! -d "$DEST_PATH" ]; then
    log_error "Destination path not found: $DEST_PATH"
    log_warning "Message saved locally but NOT delivered"
    echo "$MESSAGE_FILE"
    exit 1
fi

if [ ! -d "$DEST_PATH/.aea" ]; then
    log_error "Destination is not an AEA repository: $DEST_PATH"
    log_warning "Message saved locally but NOT delivered"
    echo "$MESSAGE_FILE"
    exit 1
fi

# Check if destination agent is enabled
if ! get_agent_enabled "$TO_AGENT" 2>/dev/null; then
    log_warning "Destination agent is disabled: $TO_AGENT"
    log_info "Enable with: bash scripts/aea-registry.sh enable $TO_AGENT"
fi

# Deliver message to destination
DEST_FILE="$DEST_PATH/.aea/message-${TIMESTAMP_COMPACT}-from-${SOURCE_AGENT}.json"

log_info "Delivering to: $DEST_PATH"

# Update destination path in message (atomic operation)
if ! jq --arg path "$DEST_PATH" '.to.repo_path = $path' "$MESSAGE_FILE" > "$MESSAGE_FILE.tmp"; then
    log_error "Failed to update message with destination path"
    rm -f "$MESSAGE_FILE.tmp"
    exit 1
fi

if ! mv "$MESSAGE_FILE.tmp" "$MESSAGE_FILE"; then
    log_error "Failed to save updated message"
    rm -f "$MESSAGE_FILE.tmp"
    exit 1
fi

# Copy to destination with error checking
if ! cp "$MESSAGE_FILE" "$DEST_FILE"; then
    log_error "Failed to deliver message to destination"
    log_warning "Message saved locally at: $MESSAGE_FILE"
    exit 1
fi

log_success "Message delivered!"
echo
echo "  From: $SOURCE_AGENT ($SOURCE_PATH)"
echo "  To:   $TO_AGENT ($DEST_PATH)"
echo "  Type: $MESSAGE_TYPE"
echo "  Priority: $PRIORITY"
echo "  Subject: $SUBJECT"
echo
echo "Message file: $DEST_FILE"
echo
echo "The destination agent will detect this message on next check."

# Log the send action
if [ -f ".aea/agent.log" ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [SEND] Sent $MESSAGE_TYPE to $TO_AGENT: $SUBJECT" >> .aea/agent.log
fi

echo "$MESSAGE_FILE"
