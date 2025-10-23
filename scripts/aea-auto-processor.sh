#!/bin/bash
# aea-auto-processor.sh - Autonomous Message Processor
# Processes safe messages automatically, escalates complex ones to Claude

set -euo pipefail

# Get script directory (resolve symlinks)
SCRIPT_REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_REAL_PATH")" && pwd)"

# Find .aea directory (parent of scripts/ or current if in .aea/ root)
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    AEA_ROOT="$(dirname "$SCRIPT_DIR")"
else
    AEA_ROOT="$SCRIPT_DIR"
fi

# Source registry functions (check multiple locations)
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
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[AUTO]${NC} $1"; }
log_success() { echo -e "${GREEN}[AUTO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[AUTO]${NC} $1"; }
log_error() { echo -e "${RED}[AUTO]${NC} $1"; }
log_escalate() { echo -e "${CYAN}[ESCALATE]${NC} $1"; }

# Configuration
MAX_MESSAGES_PER_RUN=10  # Rate limiting: process max 10 messages per hook invocation

# Statistics
PROCESSED_COUNT=0
ESCALATED_COUNT=0
FAILED_COUNT=0

# ==============================================================================
# Helper Functions
# ==============================================================================

mark_processed() {
    local msg_file="$1"
    local marker_file=".aea/.processed/$(basename "$msg_file")"

    mkdir -p .aea/.processed
    touch "$marker_file"
}

is_processed() {
    local msg_file="$1"
    local marker_file=".aea/.processed/$(basename "$msg_file")"

    [ -f "$marker_file" ]
}

log_action() {
    local action="$1"
    local msg_file="$2"
    local details="${3:-}"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$timestamp [AUTO-PROCESSOR] $action: $(basename "$msg_file") $details" >> .aea/agent.log
}

# ==============================================================================
# Message Classification
# ==============================================================================

classify_message() {
    local msg_file="$1"

    local type=$(jq -r '.message_type' "$msg_file")
    local priority=$(jq -r '.priority' "$msg_file")
    local body=$(jq -r '.message.body' "$msg_file")

    # Decision matrix based on type and priority
    case "$type:$priority" in
        # Questions - auto-process if simple
        question:low|question:normal)
            if is_simple_query "$body"; then
                echo "AUTO_PROCESS"
            else
                echo "ESCALATE"
            fi
            ;;
        question:high|question:urgent)
            echo "ESCALATE"
            ;;

        # Updates - auto-acknowledge low/normal
        update:low|update:normal)
            echo "AUTO_PROCESS"
            ;;
        update:high|update:urgent)
            echo "ESCALATE"
            ;;

        # Responses - auto-process (just log and mark)
        response:*)
            echo "AUTO_PROCESS"
            ;;

        # Issues - escalate medium and above
        issue:low)
            echo "AUTO_PROCESS"
            ;;
        issue:*)
            echo "ESCALATE"
            ;;

        # Requests - always escalate (may involve code changes)
        request:*)
            echo "ESCALATE"
            ;;

        # Handoffs - always escalate (require review)
        handoff:*)
            echo "ESCALATE"
            ;;

        *)
            # Unknown - escalate
            echo "ESCALATE"
            ;;
    esac
}

is_simple_query() {
    local query="$1"

    # Simple query patterns that can be handled with grep/find
    if echo "$query" | grep -qiE "what files?|which files?|where is|find.*file|list.*file|show.*file"; then
        return 0
    fi

    if echo "$query" | grep -qiE "^(find|list|show|what|where|which)" && [ ${#query} -lt 200 ]; then
        return 0
    fi

    # If it's complex analysis, escalate
    if echo "$query" | grep -qiE "how does|why does|analyze|explain|refactor|implement|create|modify"; then
        return 1
    fi

    # Short queries are usually simple
    if [ ${#query} -lt 100 ]; then
        return 0
    fi

    return 1
}

# ==============================================================================
# Auto-Processors
# ==============================================================================

auto_process_question() {
    local msg_file="$1"

    local from_agent=$(jq -r '.from.agent_id' "$msg_file")
    local subject=$(jq -r '.message.subject' "$msg_file")
    local query=$(jq -r '.message.body' "$msg_file")
    local correlation_id=$(jq -r '.metadata.conversation_id' "$msg_file")

    log_info "Auto-processing question: $subject"

    # Extract search terms
    local search_terms=$(extract_search_terms "$query")

    if [ -z "$search_terms" ]; then
        log_warning "Could not extract search terms, escalating"
        return 1
    fi

    # Search codebase
    log_info "Searching for: $search_terms"
    local results=$(search_codebase "$search_terms")

    if [ -z "$results" ]; then
        results="No files found matching '$search_terms'"
    fi

    # Format response
    local response_body="Auto-search results for: $search_terms

$results

---
This response was automatically generated by searching the codebase.
If you need more detailed analysis, please ask again with more context."

    # Send response
    send_response "$from_agent" "$subject" "$response_body" "$correlation_id"

    log_success "Auto-responded to question from $from_agent"
    log_action "AUTO_RESPOND" "$msg_file" "question"

    return 0
}

auto_process_update() {
    local msg_file="$1"

    local from_agent=$(jq -r '.from.agent_id' "$msg_file")
    local subject=$(jq -r '.message.subject' "$msg_file")
    local update_body=$(jq -r '.message.body' "$msg_file")
    local correlation_id=$(jq -r '.metadata.conversation_id' "$msg_file")

    log_info "Auto-acknowledging update: $subject"

    # Simple acknowledgment
    local response_body="Update received and noted: $subject

Details:
$update_body

---
This acknowledgment was automatically generated.
The update has been logged for future reference."

    # Send acknowledgment
    send_response "$from_agent" "Re: $subject" "$response_body" "$correlation_id"

    log_success "Auto-acknowledged update from $from_agent"
    log_action "AUTO_ACK" "$msg_file" "update"

    return 0
}

auto_process_response() {
    local msg_file="$1"

    local from_agent=$(jq -r '.from.agent_id' "$msg_file")
    local subject=$(jq -r '.message.subject' "$msg_file")

    log_info "Processing response: $subject"

    # Just log it - responses don't need replies
    log_success "Logged response from $from_agent"
    log_action "AUTO_LOG" "$msg_file" "response"

    return 0
}

auto_process_low_issue() {
    local msg_file="$1"

    local from_agent=$(jq -r '.from.agent_id' "$msg_file")
    local subject=$(jq -r '.message.subject' "$msg_file")
    local issue_body=$(jq -r '.message.body' "$msg_file")
    local correlation_id=$(jq -r '.metadata.conversation_id' "$msg_file")

    log_info "Auto-acknowledging low-priority issue: $subject"

    local response_body="Low-priority issue acknowledged: $subject

Issue details:
$issue_body

---
This issue has been logged and will be reviewed.
For urgent issues, please resend with priority 'high' or 'urgent'."

    send_response "$from_agent" "Re: $subject" "$response_body" "$correlation_id"

    log_success "Auto-acknowledged low issue from $from_agent"
    log_action "AUTO_ACK_ISSUE" "$msg_file" "low-priority"

    return 0
}

# ==============================================================================
# Search & Response Helpers
# ==============================================================================

extract_search_terms() {
    local query="$1"

    # Extract meaningful search terms safely
    # Input is already sanitized from jq, but we use safe processing anyway

    # 1. Convert to lowercase and remove common words using awk (safer than sed)
    # 2. Extract words longer than 3 chars
    # 3. Take top 5 terms

    local terms
    terms=$(echo "$query" | \
        tr '[:upper:]' '[:lower:]' | \
        awk '
        {
            # Split into words and filter out common words
            gsub(/\b(what|which|where|when|who|why|how|show|list|find|get|the|is|are|was|were|do|does|did|can|could|would|should|in|on|at|to|from|for|with|by|of|a|an)\b/, " ")
            print
        }
        ' | \
        grep -oE '[a-z0-9_-]{4,}' | \
        head -5 | \
        tr '\n' ' ' || echo "")

    # If no terms found, try to get any word > 3 chars
    if [ -z "$terms" ]; then
        terms=$(echo "$query" | grep -oE '[a-zA-Z0-9_-]{4,}' | head -3 | tr '\n' ' ' || echo "")
    fi

    # Return trimmed result (use printf instead of echo for safety)
    printf '%s' "$terms" | xargs
}

search_codebase() {
    local search_terms="$1"
    local max_results=20
    local timeout_duration=10  # 10 second timeout
    local max_depth=5  # Limit search depth

    # Search for files and content
    local results=""

    # Check for faster tools and timeout command
    local use_ripgrep=false
    local use_fd=false
    local use_timeout=false

    if command -v rg &> /dev/null; then
        use_ripgrep=true
    fi

    if command -v fd &> /dev/null; then
        use_fd=true
    fi

    if command -v timeout &> /dev/null; then
        use_timeout=true
    fi

    # Search filenames with optional timeout
    for term in $search_terms; do
        local file_results=""

        if [ "$use_fd" = true ]; then
            # Use fd (much faster than find)
            if [ "$use_timeout" = true ]; then
                file_results=$(timeout "$timeout_duration" fd -d "$max_depth" -t f "$term" 2>/dev/null | head -10 || echo "")
            else
                file_results=$(fd -d "$max_depth" -t f "$term" 2>/dev/null | head -10 || echo "")
            fi
        else
            # Fallback to find with optional timeout and depth limit
            if [ "$use_timeout" = true ]; then
                file_results=$(timeout "$timeout_duration" find . -maxdepth "$max_depth" -type f -name "*${term}*" 2>/dev/null | \
                    grep -v "node_modules\|\.git\|\.aea\|vendor\|build\|dist\|target" | \
                    head -10 || echo "")
            else
                # Without timeout, use subshell with limited time awareness
                file_results=$(find . -maxdepth "$max_depth" -type f -name "*${term}*" 2>/dev/null | \
                    grep -v "node_modules\|\.git\|\.aea\|vendor\|build\|dist\|target" | \
                    head -10 || echo "")
            fi
        fi

        if [ -n "$file_results" ]; then
            results="${results}Files matching '$term':\n$file_results\n\n"
        fi
    done

    # Search content with optional timeout
    for term in $search_terms; do
        local content_results=""
        local search_status=0

        if [ "$use_ripgrep" = true ]; then
            # Use ripgrep (much faster than grep)
            if [ "$use_timeout" = true ]; then
                content_results=$(timeout "$timeout_duration" rg -l --max-depth "$max_depth" \
                    --type-add 'code:*.{py,js,ts,go,java,rs,c,cpp,h,hpp}' \
                    -t code "$term" 2>/dev/null | \
                    head -10 || echo "")
                search_status=$?
            else
                content_results=$(rg -l --max-depth "$max_depth" \
                    --type-add 'code:*.{py,js,ts,go,java,rs,c,cpp,h,hpp}' \
                    -t code "$term" 2>/dev/null | \
                    head -10 || echo "")
                search_status=$?
            fi
        else
            # Fallback to grep with optional timeout (note: grep doesn't have --max-depth)
            if [ "$use_timeout" = true ]; then
                content_results=$(timeout "$timeout_duration" grep -r "$term" . \
                    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.aea \
                    --exclude-dir=vendor --exclude-dir=build --exclude-dir=dist --exclude-dir=target \
                    --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.java" --include="*.rs" \
                    2>/dev/null | \
                    cut -d: -f1 | \
                    sort -u | \
                    head -10 || echo "")
                search_status=$?
            else
                content_results=$(grep -r "$term" . \
                    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.aea \
                    --exclude-dir=vendor --exclude-dir=build --exclude-dir=dist --exclude-dir=target \
                    --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.java" --include="*.rs" \
                    2>/dev/null | \
                    cut -d: -f1 | \
                    sort -u | \
                    head -10 || echo "")
                search_status=$?
            fi
        fi

        # Handle timeout (exit code 124)
        if [ $search_status -eq 124 ]; then
            results="${results}\n[Search timed out after ${timeout_duration}s - results may be incomplete]\n"
        fi

        if [ -n "$content_results" ]; then
            results="${results}Files containing '$term':\n$content_results\n\n"
        fi
    done

    if [ -z "$results" ]; then
        echo ""
    else
        echo -e "$results" | head -$max_results
    fi
}

send_response() {
    local to_agent="$1"
    local subject="$2"
    local body="$3"
    local correlation_id="$4"

    # Use aea-send.sh if available
    if [ -f "$SCRIPT_DIR/aea-send.sh" ]; then
        # Pass body directly - aea-send.sh will handle escaping properly
        bash "$SCRIPT_DIR/aea-send.sh" \
            --to "$to_agent" \
            --type response \
            --subject "$subject" \
            --message "$body" \
            --correlation-id "$correlation_id" \
            --priority normal \
            > /dev/null 2>&1 || {
                log_warning "Failed to send response via aea-send.sh"
                return 1
            }
    else
        log_warning "aea-send.sh not found, cannot send response"
        return 1
    fi
}

# ==============================================================================
# Main Processing Loop
# ==============================================================================

process_message() {
    local msg_file="$1"

    # Check if already processed
    if is_processed "$msg_file"; then
        return 0
    fi

    # Validate message against schema
    if [ -f "$SCRIPT_DIR/aea-validate-message.sh" ]; then
        if ! bash "$SCRIPT_DIR/aea-validate-message.sh" "$msg_file" 2>/dev/null; then
            log_error "Message validation failed: $(basename "$msg_file")"
            log_warning "Run: bash $SCRIPT_DIR/aea-validate-message.sh $msg_file for details"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            return 1
        fi
    else
        # Fallback: basic JSON validation
        if ! jq empty "$msg_file" 2>/dev/null; then
            log_error "Invalid JSON in message: $(basename "$msg_file")"
            log_warning "Skipping malformed message"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            return 1
        fi

        # Validate required fields (v0.1.0 protocol)
        local type=$(jq -r '.message_type // empty' "$msg_file")
        local from=$(jq -r '.sender.agent_id // empty' "$msg_file")

        if [ -z "$type" ] || [ -z "$from" ]; then
            log_error "Missing required fields in: $(basename "$msg_file")"
            log_warning "Required: message_type, sender.agent_id"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            return 1
        fi
    fi

    # Classify message
    local decision=$(classify_message "$msg_file")

    local type=$(jq -r '.message_type' "$msg_file")
    local priority=$(jq -r '.priority' "$msg_file")
    local from_agent=$(jq -r '.from.agent_id' "$msg_file")
    local subject=$(jq -r '.message.subject' "$msg_file")

    if [ "$decision" = "AUTO_PROCESS" ]; then
        # Auto-process based on type
        case "$type" in
            question)
                if auto_process_question "$msg_file"; then
                    mark_processed "$msg_file"
                    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
                else
                    log_escalate "Question too complex, escalating: $subject"
                    ESCALATED_COUNT=$((ESCALATED_COUNT + 1))
                    return 1
                fi
                ;;
            update)
                if auto_process_update "$msg_file"; then
                    mark_processed "$msg_file"
                    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
                else
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    return 1
                fi
                ;;
            response)
                if auto_process_response "$msg_file"; then
                    mark_processed "$msg_file"
                    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
                else
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    return 1
                fi
                ;;
            issue)
                if auto_process_low_issue "$msg_file"; then
                    mark_processed "$msg_file"
                    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
                else
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    return 1
                fi
                ;;
            *)
                log_escalate "Unknown type, escalating: $type"
                ESCALATED_COUNT=$((ESCALATED_COUNT + 1))
                return 1
                ;;
        esac
    else
        # Escalate to Claude
        log_escalate "$type ($priority) from $from_agent: $subject"
        echo "  📬 Message requires review: $(basename "$msg_file")"
        echo "     Type: $type | Priority: $priority"
        echo "     From: $from_agent"
        echo "     Subject: $subject"
        echo "     Use /aea to process this message"
        echo
        ESCALATED_COUNT=$((ESCALATED_COUNT + 1))
        return 1
    fi
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

main() {
    # Ensure we're in an AEA repo
    if [ ! -d ".aea" ]; then
        log_error "Not in an AEA repository (no .aea/ directory)"
        return 1
    fi

    # Find unprocessed messages (use array to handle spaces)
    local messages_array=()
    while IFS= read -r -d '' msg; do
        messages_array+=("$msg")
    done < <(find .aea -maxdepth 1 -name "message-*.json" -type f -print0 2>/dev/null)

    if [ ${#messages_array[@]} -eq 0 ]; then
        # No messages - silent success
        return 0
    fi

    # Count unprocessed
    local unprocessed=0
    for msg in "${messages_array[@]}"; do
        if ! is_processed "$msg"; then
            unprocessed=$((unprocessed + 1))
        fi
    done

    if [ $unprocessed -eq 0 ]; then
        # All messages processed - silent success
        return 0
    fi

    log_info "Found $unprocessed unprocessed message(s)"

    # Apply rate limiting
    if [ $unprocessed -gt $MAX_MESSAGES_PER_RUN ]; then
        log_warning "Rate limiting: Processing $MAX_MESSAGES_PER_RUN of $unprocessed messages"
        log_info "Remaining messages will be processed on next run"
    fi
    echo

    # Process messages (up to rate limit)
    local processed=0
    for msg in "${messages_array[@]}"; do
        if ! is_processed "$msg"; then
            if [ $processed -ge $MAX_MESSAGES_PER_RUN ]; then
                log_info "Rate limit reached ($MAX_MESSAGES_PER_RUN messages), stopping"
                break
            fi
            process_message "$msg" || true
            processed=$((processed + 1))
        fi
    done

    # Summary
    echo
    echo "Auto-Processing Summary:"
    echo "  ✅ Auto-processed: $PROCESSED_COUNT"
    if [ $ESCALATED_COUNT -gt 0 ]; then
        echo "  ⚠️  Escalated to Claude: $ESCALATED_COUNT"
    fi
    if [ $FAILED_COUNT -gt 0 ]; then
        echo "  ❌ Failed: $FAILED_COUNT"
    fi
    echo

    if [ $ESCALATED_COUNT -gt 0 ]; then
        echo "Run /aea to process escalated messages with Claude."
        echo
    fi
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
