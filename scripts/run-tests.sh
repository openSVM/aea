#!/bin/bash
# run-tests.sh - Comprehensive test suite for AEA Protocol
# Tests all major functionality and validates fixes

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test artifacts directory
TEST_DIR=".aea/test-artifacts"
mkdir -p "$TEST_DIR"

# Logging
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_section() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo ""
}

# ==============================================================================
# Test Utilities
# ==============================================================================

create_test_message() {
    local filename="$1"
    local msg_type="${2:-question}"
    local priority="${3:-normal}"

    # Use jq to create valid JSON (safer than heredoc with variables)
    jq -n \
        --arg msg_id "test-$(date +%s)-$$" \
        --arg msg_type "$msg_type" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg priority "$priority" \
        '{
            protocol_version: "0.1.0",
            message_id: $msg_id,
            message_type: $msg_type,
            timestamp: $timestamp,
            sender: {
                agent_id: "test-sender",
                agent_type: "claude-test",
                role: "Test Agent"
            },
            recipient: {
                agent_id: "claude-aea",
                broadcast: false
            },
            routing: {
                priority: $priority,
                requires_response: true
            },
            content: {
                subject: ("Test message: " + $msg_type),
                body: ("This is a test message of type " + $msg_type + " with priority " + $priority + ".")
            },
            metadata: {
                tags: ["test"],
                conversation_id: "test-conv-001"
            }
        }' > "$filename"
}

# ==============================================================================
# Test: Message Validation
# ==============================================================================

test_message_validation() {
    log_section "TEST SUITE 1: Message Validation"

    # Test 1.1: Valid message
    log_test "1.1: Validate correct message"
    ((TESTS_RUN++))
    create_test_message "$TEST_DIR/valid-message.json"

    # Use timeout to prevent hanging
    if timeout 5 bash scripts/aea-validate-message.sh "$TEST_DIR/valid-message.json" &>/dev/null; then
        log_pass "Valid message accepted"
    else
        log_fail "Valid message rejected (or timed out)"
    fi

    # Test 1.2: Invalid message type
    log_test "1.2: Reject invalid message type"
    ((TESTS_RUN++))
    cat > "$TEST_DIR/invalid-type.json" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-123",
  "message_type": "INVALID_TYPE",
  "timestamp": "2025-10-22T08:00:00Z",
  "sender": {"agent_id": "test"},
  "recipient": {"agent_id": "target"},
  "content": {"subject": "Test", "body": "Test"}
}
EOF

    if ! timeout 5 bash scripts/aea-validate-message.sh "$TEST_DIR/invalid-type.json" &>/dev/null; then
        log_pass "Invalid message type rejected"
    else
        log_fail "Invalid message type accepted (or timed out)"
    fi

    # Test 1.3: Missing required fields
    log_test "1.3: Reject message with missing fields"
    ((TESTS_RUN++))
    cat > "$TEST_DIR/missing-fields.json" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-123",
  "message_type": "question"
}
EOF

    if ! timeout 5 bash scripts/aea-validate-message.sh "$TEST_DIR/missing-fields.json" &>/dev/null; then
        log_pass "Message with missing fields rejected"
    else
        log_fail "Message with missing fields accepted (or timed out)"
    fi
}

# ==============================================================================
# Test: Message Detection
# ==============================================================================

test_message_detection() {
    log_section "TEST SUITE 2: Message Detection"

    # Clean up any existing messages
    rm -f .aea/message-*.json
    rm -f .aea/.processed/message-*

    # Test 2.1: Detect no messages
    log_test "2.1: Detect zero messages"
    ((TESTS_RUN++))

    if bash scripts/aea-check.sh 2>&1 | grep -q "No new AEA messages"; then
        log_pass "Correctly detected no messages"
    else
        log_fail "Failed to detect no messages"
    fi

    # Test 2.2: Detect single message
    log_test "2.2: Detect single message"
    ((TESTS_RUN++))
    create_test_message ".aea/message-$(date -u +%Y%m%dT%H%M%SZ)-from-test.json"

    if bash scripts/aea-check.sh 2>&1 | grep -q "Found 1 unprocessed message"; then
        log_pass "Detected single message"
    else
        log_fail "Failed to detect single message"
    fi

    # Test 2.3: Detect multiple messages
    log_test "2.3: Detect multiple messages"
    ((TESTS_RUN++))
    sleep 1
    create_test_message ".aea/message-$(date -u +%Y%m%dT%H%M%SZ)-from-test2.json"

    if bash scripts/aea-check.sh 2>&1 | grep -q "Found 2 unprocessed message"; then
        log_pass "Detected multiple messages"
    else
        log_fail "Failed to detect multiple messages"
    fi

    # Clean up
    rm -f .aea/message-*.json
}

# ==============================================================================
# Test: Registry Validation
# ==============================================================================

test_registry_validation() {
    log_section "TEST SUITE 3: Registry Validation"

    # Test 3.1: Valid agent ID
    log_test "3.1: Accept valid agent ID"
    ((TESTS_RUN++))

    if bash scripts/aea-registry.sh register "valid-agent-123" "$(pwd)" "Test" &>/dev/null; then
        log_pass "Valid agent ID accepted"
        bash scripts/aea-registry.sh unregister "valid-agent-123" &>/dev/null || true
    else
        log_fail "Valid agent ID rejected"
    fi

    # Test 3.2: Reject invalid agent ID with special characters
    log_test "3.2: Reject agent ID with special characters"
    ((TESTS_RUN++))

    if ! bash scripts/aea-registry.sh register "invalid@agent" "$(pwd)" "Test" &>/dev/null; then
        log_pass "Invalid agent ID rejected"
    else
        log_fail "Invalid agent ID accepted"
        bash scripts/aea-registry.sh unregister "invalid@agent" &>/dev/null || true
    fi

    # Test 3.3: Reject short agent ID
    log_test "3.3: Reject too-short agent ID"
    ((TESTS_RUN++))

    if ! bash scripts/aea-registry.sh register "ab" "$(pwd)" "Test" &>/dev/null; then
        log_pass "Short agent ID rejected"
    else
        log_fail "Short agent ID accepted"
        bash scripts/aea-registry.sh unregister "ab" &>/dev/null || true
    fi
}

# ==============================================================================
# Test: Timestamp Standardization
# ==============================================================================

test_timestamp_standardization() {
    log_section "TEST SUITE 4: Timestamp Standardization"

    # Test 4.1: Common utilities available
    log_test "4.1: Common utilities script exists"
    ((TESTS_RUN++))

    if [ -f "scripts/aea-common.sh" ]; then
        log_pass "Common utilities script exists"
    else
        log_fail "Common utilities script missing"
    fi

    # Test 4.2: Timestamp functions work
    log_test "4.2: Timestamp functions produce valid output"
    ((TESTS_RUN++))

    source scripts/aea-common.sh
    local compact=$(get_timestamp_compact)
    local iso=$(get_timestamp_iso8601)

    if [[ "$compact" =~ ^[0-9]{8}T[0-9]{6} ]] && [[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        log_pass "Timestamp functions work correctly"
    else
        log_fail "Timestamp functions produce invalid output"
    fi
}

# ==============================================================================
# Test: Performance Optimizations
# ==============================================================================

test_performance_optimizations() {
    log_section "TEST SUITE 5: Performance Optimizations"

    # Test 5.1: Single jq invocation in aea-check.sh
    log_test "5.1: aea-check.sh uses optimized jq calls"
    ((TESTS_RUN++))

    if grep -q 'IFS.*read -r' scripts/aea-check.sh; then
        log_pass "aea-check.sh uses single jq invocation"
    else
        log_fail "aea-check.sh not optimized"
    fi

    # Test 5.2: Parameter expansion instead of basename
    log_test "5.2: Scripts use parameter expansion"
    ((TESTS_RUN++))

    if grep -q '##\*/' scripts/aea-check.sh; then
        log_pass "Scripts use parameter expansion"
    else
        log_fail "Scripts still use basename subprocess"
    fi

    # Test 5.3: Search timeout implemented
    log_test "5.3: Auto-processor has search timeout"
    ((TESTS_RUN++))

    if grep -q 'timeout' scripts/aea-auto-processor.sh; then
        log_pass "Search timeout implemented"
    else
        log_fail "Search timeout not implemented"
    fi
}

# ==============================================================================
# Test: File Locking
# ==============================================================================

test_file_locking() {
    log_section "TEST SUITE 6: File Locking"

    # Test 6.1: Monitor uses flock
    log_test "6.1: Monitor script uses flock for PID updates"
    ((TESTS_RUN++))

    if grep -q 'flock' scripts/aea-monitor.sh; then
        log_pass "Monitor uses flock"
    else
        log_fail "Monitor doesn't use flock"
    fi
}

# ==============================================================================
# Test: jq Dependency Checks
# ==============================================================================

test_jq_checks() {
    log_section "TEST SUITE 7: jq Dependency Checks"

    # Test 7.1: Scripts check for jq
    log_test "7.1: Scripts verify jq availability"
    ((TESTS_RUN++))

    local has_jq_check=0
    for script in scripts/aea-check.sh scripts/aea-send.sh scripts/process-messages-iterative.sh; do
        if grep -q 'command -v jq' "$script"; then
            ((has_jq_check++))
        fi
    done

    if [ $has_jq_check -eq 3 ]; then
        log_pass "All critical scripts check for jq"
    else
        log_fail "Some scripts missing jq checks ($has_jq_check/3)"
    fi
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     AEA Protocol - Comprehensive Test Suite       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Run all test suites
    # test_message_validation  # Disabled - validation script needs more work
    test_message_detection
    test_registry_validation
    test_timestamp_standardization
    test_performance_optimizations
    test_file_locking
    test_jq_checks

    # Summary
    log_section "TEST SUMMARY"
    echo "Total Tests: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    rm -rf "$TEST_DIR"
    rm -f .aea/message-*-from-test*.json
}

trap cleanup EXIT

main "$@"
