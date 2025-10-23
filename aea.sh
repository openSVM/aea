#!/bin/bash
# AEA Protocol v0.1.0 - Main Operational Script
# Unified interface for all AEA operations

set -euo pipefail

AEA_VERSION="0.1.0"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure critical directories exist early (for logging)
AEA_DIR="$SCRIPT_DIR"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
PROCESSED_DIR="$AEA_DIR/.processed"
LOG_FILE="$AEA_DIR/agent.log"

# Create directories with error handling
if ! mkdir -p "$PROCESSED_DIR" "$AEA_DIR/logs" 2>/dev/null; then
    echo "ERROR: Failed to create required directories" >&2
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Utility Functions
# ============================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗ ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

# ============================================================================
# COMMAND: check
# ============================================================================

cmd_check() {
    # Delegate to the actual check script if it exists
    if [ -f "$SCRIPTS_DIR/aea-check.sh" ]; then
        bash "$SCRIPTS_DIR/aea-check.sh"
        return $?
    fi

    # Fallback implementation
    echo -e "${BLUE}═══ Checking for messages ═══${NC}"

    local unprocessed=()
    for msg in "$AEA_DIR"/message-*.json; do
        # Skip if glob didn't match any files
        [ -e "$msg" ] || continue

        # Use parameter expansion instead of basename subprocess
        local basename="${msg##*/}"

        if [ ! -f "${PROCESSED_DIR}/${basename}" ]; then
            unprocessed+=("$msg")
        fi
    done

    if [ ${#unprocessed[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No unprocessed messages${NC}"
        return 0
    fi

    echo -e "${YELLOW}Found ${#unprocessed[@]} unprocessed message(s):${NC}"
    echo ""

    # Check jq availability once before loop
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ ERROR: jq is required but not installed${NC}"
        echo "Install: apt-get install jq (Debian/Ubuntu) or brew install jq (Mac)"
        return 1
    fi

    for msg in "${unprocessed[@]}"; do
        # Use parameter expansion instead of basename subprocess
        local basename="${msg##*/}"

        # Use single jq invocation to extract all fields at once
        local msg_data=$(jq -r '"\(.message_type // "unknown")|\(.sender.agent_id // "unknown")|\(.routing.priority // "normal")|\(.content.subject // "No subject")"' "$msg" 2>/dev/null || echo "unknown|unknown|normal|No subject")

        IFS='|' read -r type from priority subject <<< "$msg_data"

        echo "  • $basename"
        echo "    Type: $type | Priority: $priority | From: $from"
        echo "    Subject: $subject"
    done
    echo ""
}

# ============================================================================
# COMMAND: process
# ============================================================================

cmd_process() {
    # Delegate to the actual processing script if it exists
    # Note: process-messages-iterative.sh always runs in interactive mode
    if [ -f "$SCRIPTS_DIR/process-messages-iterative.sh" ]; then
        bash "$SCRIPTS_DIR/process-messages-iterative.sh"
        return $?
    fi

    # Fallback implementation
    local mode="${1:-interactive}"  # interactive or auto

    # Fallback implementation
    echo -e "${BLUE}═══ Processing messages ═══${NC}"

    local unprocessed=()
    for msg in "$AEA_DIR"/message-*.json; do
        # Skip if glob didn't match any files
        [ -e "$msg" ] || continue

        # Use parameter expansion instead of basename subprocess
        local basename="${msg##*/}"

        if [ ! -f "${PROCESSED_DIR}/${basename}" ]; then
            unprocessed+=("$msg")
        fi
    done

    if [ ${#unprocessed[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No messages to process${NC}"
        return 0
    fi

    for msg in "${unprocessed[@]}"; do
        # Use parameter expansion instead of basename
        local basename="${msg##*/}"
        echo -e "${YELLOW}Processing: $basename${NC}"

        # Extract all message details with single jq invocation
        local msg_data=$(jq -r '"\(.message_type // "unknown")|\(.sender.agent_id // "unknown")|\(.routing.priority // "normal")|\(.routing.requires_response // false)|\(.content.subject // "No subject")"' "$msg" 2>/dev/null || echo "unknown|unknown|normal|false|No subject")

        IFS='|' read -r type from priority requires_response subject <<< "$msg_data"

        echo "  Type: $type | From: $from | Priority: $priority"
        echo "  Subject: $subject"

        if [ "$mode" = "interactive" ]; then
            # Show message content
            echo ""
            echo "  Message content:"
            jq -C '.content' "$msg" 2>/dev/null || cat "$msg"
            echo ""

            read -p "  Process this message? (y/n): " choice
            if [ "$choice" != "y" ] && [ "$choice" != "yes" ]; then
                echo -e "${YELLOW}  Skipped${NC}"
                continue
            fi
        fi

        # Mark as processed
        mkdir -p "$PROCESSED_DIR"
        touch "${PROCESSED_DIR}/${basename}"
        log_message "Processed: $type from $from"
        echo -e "${GREEN}  ✓ Marked as processed${NC}"
        echo ""
    done
}

# ============================================================================
# COMMAND: monitor
# ============================================================================

cmd_monitor() {
    local action="${1:-start}"

    # Delegate to the actual monitor script if it exists
    if [ -f "$SCRIPTS_DIR/aea-monitor.sh" ]; then
        bash "$SCRIPTS_DIR/aea-monitor.sh" "$action"
        return $?
    fi

    # Fallback implementation
    case "$action" in
        start)
            # Check if monitor is already running
            if [ -f "$AEA_DIR/.monitor.pid" ]; then
                local existing_pid=$(cat "$AEA_DIR/.monitor.pid" 2>/dev/null)
                if [ -n "$existing_pid" ] && ps -p "$existing_pid" > /dev/null 2>&1; then
                    echo -e "${YELLOW}Monitor already running (PID: $existing_pid)${NC}"
                    return 0
                else
                    # Stale PID file, remove it
                    rm -f "$AEA_DIR/.monitor.pid"
                fi
            fi

            echo -e "${BLUE}Starting background monitor...${NC}"
            mkdir -p "$AEA_DIR/logs"
            nohup bash "$SCRIPT_DIR/aea.sh" _monitor_loop >> "$AEA_DIR/logs/monitor.log" 2>&1 &
            local new_pid=$!
            # Atomic write with temp file
            echo "$new_pid" > "$AEA_DIR/.monitor.pid.tmp" && mv "$AEA_DIR/.monitor.pid.tmp" "$AEA_DIR/.monitor.pid"
            echo -e "${GREEN}✓ Monitor started (PID: $new_pid)${NC}"
            echo "  Logs: $AEA_DIR/logs/monitor.log"
            ;;
        stop)
            if [ -f "$AEA_DIR/.monitor.pid" ]; then
                local pid=$(cat "$AEA_DIR/.monitor.pid" 2>/dev/null)
                if [ -n "$pid" ]; then
                    if ps -p "$pid" > /dev/null 2>&1; then
                        kill "$pid" 2>/dev/null || true
                        echo -e "${GREEN}✓ Monitor stopped${NC}"
                    else
                        echo -e "${YELLOW}Monitor not running (stale PID: $pid)${NC}"
                    fi
                fi
                rm -f "$AEA_DIR/.monitor.pid"
            else
                echo -e "${YELLOW}Monitor not running${NC}"
            fi
            ;;
        status)
            if [ -f "$AEA_DIR/.monitor.pid" ]; then
                local pid=$(cat "$AEA_DIR/.monitor.pid" 2>/dev/null)
                if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ Monitor running (PID: $pid)${NC}"
                else
                    echo -e "${RED}✗ Monitor not running (stale PID: ${pid:-unknown})${NC}"
                fi
            else
                echo -e "${YELLOW}Monitor not running${NC}"
            fi
            ;;
        _monitor_loop)
            # Internal: background monitor loop
            while true; do
                if bash "$SCRIPT_DIR/aea.sh" check >/dev/null 2>&1; then
                    bash "$SCRIPT_DIR/aea.sh" process --auto >/dev/null 2>&1 || true
                fi
                sleep 300  # Check every 5 minutes
            done
            ;;
        *)
            echo -e "${RED}Unknown monitor action: $action${NC}"
            echo "Usage: aea.sh monitor [start|stop|status]"
            return 1
            ;;
    esac
}

# ============================================================================
# COMMAND: test
# ============================================================================

cmd_test() {
    local scope="${1:-all}"

    # Delegate to the actual test script if it exists
    if [ -f "$SCRIPTS_DIR/test-features.sh" ]; then
        bash "$SCRIPTS_DIR/test-features.sh" "$scope"
        return $?
    fi

    # Fallback implementation
    echo -e "${BLUE}═══ Running tests ═══${NC}"

    local tests_passed=0
    local tests_failed=0

    # Test 1: Check message format
    echo -e "${YELLOW}Test 1: Message format validation${NC}"
    for msg in "$AEA_DIR"/message-*.json; do
        if [ -f "$msg" ]; then
            if jq empty "$msg" 2>/dev/null; then
                ((tests_passed++))
                echo -e "${GREEN}  ✓ Valid JSON: $(basename "$msg")${NC}"
            else
                ((tests_failed++))
                echo -e "${RED}  ✗ Invalid JSON: $(basename "$msg")${NC}"
            fi
        fi
    done

    # Test 2: Required fields
    if [ -f "$AEA_DIR/agent-config.yaml" ]; then
        echo -e "${YELLOW}Test 2: Configuration validation${NC}"
        if grep -q "^agent:" "$AEA_DIR/agent-config.yaml"; then
            ((tests_passed++))
            echo -e "${GREEN}  ✓ agent-config.yaml has required sections${NC}"
        else
            ((tests_failed++))
            echo -e "${RED}  ✗ agent-config.yaml missing required sections${NC}"
        fi
    fi

    # Test 3: Directory structure
    echo -e "${YELLOW}Test 3: Directory structure${NC}"
    for dir in ".processed" "logs" "scripts"; do
        if [ -d "$AEA_DIR/$dir" ]; then
            ((tests_passed++))
            echo -e "${GREEN}  ✓ Directory exists: $dir${NC}"
        else
            ((tests_failed++))
            echo -e "${RED}  ✗ Directory missing: $dir${NC}"
        fi
    done

    # Optional: Check for tests directory (not required in installed repos)
    if [ -d "$AEA_DIR/tests" ]; then
        ((tests_passed++))
        echo -e "${GREEN}  ✓ Optional: tests directory exists${NC}"
    fi

    # Test 4: Required scripts
    echo -e "${YELLOW}Test 4: Required scripts${NC}"
    for script in "aea-check.sh" "aea-monitor.sh" "process-messages-iterative.sh"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            ((tests_passed++))
            echo -e "${GREEN}  ✓ Script exists: $script${NC}"
        else
            ((tests_failed++))
            echo -e "${RED}  ✗ Script missing: $script${NC}"
        fi
    done

    # Summary
    echo ""
    echo -e "${BLUE}═══ Test Summary ═══${NC}"
    echo -e "${GREEN}Passed: $tests_passed${NC}"
    if [ $tests_failed -gt 0 ]; then
        echo -e "${RED}Failed: $tests_failed${NC}"
        return 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    fi
}

# ============================================================================
# COMMAND: install
# ============================================================================

cmd_install() {
    local target_dir="${1:-.}"

    if [ -f "$SCRIPTS_DIR/install-aea.sh" ]; then
        bash "$SCRIPTS_DIR/install-aea.sh" "$target_dir"
        return $?
    fi

    echo -e "${RED}✗ Install script not found: $SCRIPTS_DIR/install-aea.sh${NC}"
    return 1
}

# ============================================================================
# COMMAND: create-test
# ============================================================================

cmd_create_test() {
    local scenario="${1:-all}"

    if [ -f "$SCRIPTS_DIR/create-test-scenarios.sh" ]; then
        bash "$SCRIPTS_DIR/create-test-scenarios.sh" "$scenario"
        return $?
    fi

    echo -e "${RED}✗ Test scenario script not found: $SCRIPTS_DIR/create-test-scenarios.sh${NC}"
    return 1
}

# ============================================================================
# COMMAND: setup-global
# ============================================================================

cmd_setup_global() {
    if [ -f "$SCRIPTS_DIR/setup-global-alias.sh" ]; then
        bash "$SCRIPTS_DIR/setup-global-alias.sh" "$@"
        return $?
    fi

    echo -e "${RED}✗ Setup script not found: $SCRIPTS_DIR/setup-global-alias.sh${NC}"
    return 1
}

# ============================================================================
# COMMAND: help
# ============================================================================

cmd_help() {
    cat << EOF
${BLUE}═══════════════════════════════════════════════════════════${NC}
${BLUE}    AEA Protocol v${AEA_VERSION} - Main Operational Script    ${NC}
${BLUE}═══════════════════════════════════════════════════════════${NC}

${GREEN}USAGE:${NC}
  aea.sh <command> [options]

${GREEN}COMMANDS:${NC}

  ${YELLOW}check${NC}
    Check for unprocessed messages
    Usage: aea.sh check

  ${YELLOW}process${NC} [mode]
    Process messages interactively or automatically
    Usage:
      aea.sh process                 # Interactive (prompt for each)
      aea.sh process --auto          # Automatic (no prompts)

  ${YELLOW}monitor${NC} [action]
    Start/stop background message monitor
    Usage:
      aea.sh monitor start           # Start background daemon
      aea.sh monitor stop            # Stop daemon
      aea.sh monitor status          # Show daemon status

  ${YELLOW}test${NC} [scope]
    Run test suite
    Usage:
      aea.sh test                    # Run all tests (default)
      aea.sh test all                # All tests
      aea.sh test basic              # Basic tests only

  ${YELLOW}install${NC} [target_dir]
    Install AEA in another repository
    Usage:
      aea.sh install /path/to/repo   # Install in target repo
      aea.sh install                 # Install in current dir

  ${YELLOW}create-test${NC} [scenario]
    Create test message scenarios
    Usage:
      aea.sh create-test all         # All scenarios
      aea.sh create-test simple-question
      aea.sh create-test urgent-issue

  ${YELLOW}setup-global${NC}
    Setup global 'a' command for shell integration
    Usage:
      aea.sh setup-global            # Interactive setup
      aea.sh setup-global --auto     # Automatic setup

  ${YELLOW}help${NC}
    Show this help message
    Usage: aea.sh help

${GREEN}EXAMPLES:${NC}

  ${BLUE}# Check for messages (run frequently)${NC}
  bash aea.sh check

  ${BLUE}# Process messages interactively${NC}
  bash aea.sh process

  ${BLUE}# Start continuous background monitoring${NC}
  bash aea.sh monitor start

  ${BLUE}# Run all tests${NC}
  bash aea.sh test

  ${BLUE}# Install AEA in another repository${NC}
  bash aea.sh install /path/to/other/repo

  ${BLUE}# Create test scenarios${NC}
  bash aea.sh create-test simple-question

  ${BLUE}# Setup global 'a' command (one-time setup)${NC}
  bash aea.sh setup-global

${GREEN}DOCUMENTATION:${NC}
  - PROTOCOL.md          Full protocol specification
  - README.md            Quick start guide
  - CLAUDE.md            Integration instructions
  - docs/aea-rules.md    Complete protocol rules

${GREEN}VERSION:${NC}
  Protocol: v${AEA_VERSION}
  Status: Pre-Release (Production-Ready Core)
EOF
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Ensure required directories exist (already done at top, but double-check)
    if ! mkdir -p "$PROCESSED_DIR" "$AEA_DIR/logs" 2>/dev/null; then
        echo "ERROR: Failed to create required directories" >&2
        return 1
    fi

    local command="${1:-help}"
    shift || true

    case "$command" in
        check)
            cmd_check "$@"
            ;;
        process)
            cmd_process "$@"
            ;;
        monitor)
            cmd_monitor "$@"
            ;;
        test)
            cmd_test "$@"
            ;;
        install)
            cmd_install "$@"
            ;;
        create-test)
            cmd_create_test "$@"
            ;;
        setup-global|setup)
            cmd_setup_global "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        _monitor_loop)
            # Internal command for monitor fallback
            cmd_monitor _monitor_loop
            ;;
        version|--version|-v)
            echo "AEA Protocol v${AEA_VERSION}"
            echo "Status: Pre-Release (Production-Ready Core)"
            ;;
        *)
            echo -e "${RED}✗ Unknown command: $command${NC}"
            echo ""
            cmd_help
            return 1
            ;;
    esac
}

main "$@"
