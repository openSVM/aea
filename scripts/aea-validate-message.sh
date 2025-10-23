#!/bin/bash
# aea-validate-message.sh - Message Schema Validator
# Validates AEA messages against protocol v0.1.0 schema

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() { echo -e "${RED}[VALIDATE]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[VALIDATE]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[VALIDATE]${NC} $1"; }

# ==============================================================================
# Validation Functions
# ==============================================================================

validate_message() {
    local msg_file="$1"
    local errors=0

    # Check file exists
    if [ ! -f "$msg_file" ]; then
        log_error "File does not exist: $msg_file"
        return 1
    fi

    # Check jq availability
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        return 1
    fi

    # Check valid JSON
    if ! jq empty "$msg_file" 2>/dev/null; then
        log_error "Invalid JSON in $msg_file"
        return 1
    fi

    # Required fields validation
    local required_fields=(
        ".protocol_version"
        ".message_id"
        ".message_type"
        ".timestamp"
        ".sender.agent_id"
        ".recipient.agent_id"
        ".content.subject"
        ".content.body"
    )

    for field in "${required_fields[@]}"; do
        local value=$(jq -r "$field // empty" "$msg_file" 2>/dev/null)
        if [ -z "$value" ] || [ "$value" = "null" ]; then
            log_error "Missing required field: $field"
            ((errors++))
        fi
    done

    # Validate protocol version
    local protocol_version=$(jq -r '.protocol_version' "$msg_file" 2>/dev/null)
    if [ "$protocol_version" != "0.1.0" ]; then
        log_warning "Protocol version mismatch: expected '0.1.0', got '$protocol_version'"
    fi

    # Validate message_type
    local msg_type=$(jq -r '.message_type' "$msg_file" 2>/dev/null)
    case "$msg_type" in
        question|issue|update|request|handoff|response)
            # Valid
            ;;
        *)
            log_error "Invalid message_type: $msg_type (must be: question, issue, update, request, handoff, or response)"
            ((errors++))
            ;;
    esac

    # Validate priority if present
    local priority=$(jq -r '.routing.priority // empty' "$msg_file" 2>/dev/null)
    if [ -n "$priority" ]; then
        case "$priority" in
            low|normal|high|urgent)
                # Valid
                ;;
            *)
                log_error "Invalid priority: $priority (must be: low, normal, high, or urgent)"
                ((errors++))
                ;;
        esac
    fi

    # Validate timestamp format (ISO 8601)
    local timestamp=$(jq -r '.timestamp' "$msg_file" 2>/dev/null)
    if ! echo "$timestamp" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z?$'; then
        log_error "Invalid timestamp format: $timestamp (expected ISO 8601: YYYY-MM-DDTHH:MM:SSZ)"
        ((errors++))
    fi

    # Validate message_id format (should be UUID or unique identifier)
    local msg_id=$(jq -r '.message_id' "$msg_file" 2>/dev/null)
    if [ ${#msg_id} -lt 10 ]; then
        log_warning "Message ID seems too short: $msg_id"
    fi

    # Validate agent_id format
    local sender_id=$(jq -r '.sender.agent_id' "$msg_file" 2>/dev/null)
    if ! echo "$sender_id" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        log_error "Invalid sender.agent_id format: $sender_id (must be alphanumeric with hyphens/underscores)"
        ((errors++))
    fi

    local recipient_id=$(jq -r '.recipient.agent_id' "$msg_file" 2>/dev/null)
    if ! echo "$recipient_id" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        log_error "Invalid recipient.agent_id format: $recipient_id (must be alphanumeric with hyphens/underscores)"
        ((errors++))
    fi

    # Validate subject length
    local subject=$(jq -r '.content.subject' "$msg_file" 2>/dev/null)
    if [ ${#subject} -gt 200 ]; then
        log_warning "Subject is very long (${#subject} chars, recommended < 200)"
    fi

    # Validate body is not empty
    local body=$(jq -r '.content.body' "$msg_file" 2>/dev/null)
    if [ ${#body} -lt 5 ]; then
        log_error "Message body is too short (${#body} chars, minimum 5)"
        ((errors++))
    fi

    # Return validation result
    if [ $errors -eq 0 ]; then
        log_success "Message validation passed: ${msg_file##*/}"
        return 0
    else
        log_error "Message validation failed with $errors error(s): ${msg_file##*/}"
        return 1
    fi
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

usage() {
    cat << EOF
AEA Message Validator - Validate messages against protocol v0.1.0 schema

Usage: $(basename "$0") <message_file>

Example:
    $(basename "$0") .aea/message-20251016T123456Z-from-agent.json

Exit Codes:
    0 - Validation passed
    1 - Validation failed or file error

EOF
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        usage
        exit 0
    fi

    local msg_file="$1"

    validate_message "$msg_file"
    exit $?
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
