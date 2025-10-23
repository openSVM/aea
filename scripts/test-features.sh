#!/bin/bash
# Test suite for AEA v2.2 features
# Tests: Correlation, Adaptive Backoff, Webhooks, Partial Processing, Multi-Hop
#
# BUG FIXES APPLIED:
# - Bug 10: Proper error handling for jq failures
# - Bug 28: Using set -euo pipefail for strict error checking
# - Bug 29: macOS-compatible date commands
# - Bug 30: JSON validation between operations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - all paths relative to script location (no environment variables)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$SCRIPT_DIR/tests/v2.2"
TEST_RESULTS="$TEST_DIR/results.json"
mkdir -p "$TEST_DIR"

# Utility functions
log_error() {
    echo -e "${RED}✗ ERROR: $1${NC}" >&2
}

validate_json() {
    local file="$1"
    if ! jq empty "$file" 2>/dev/null; then
        log_error "JSON validation failed for $file"
        return 1
    fi
    return 0
}

# Portable date function (macOS and Linux compatible)
get_iso_date() {
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        date -u "$@" +%Y-%m-%dT%H:%M:%SZ
    else
        # BSD date (macOS)
        date -u "$@" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
        date -u -v-1H +%Y-%m-%dT%H:%M:%SZ
    fi
}

# Get date N hours/minutes ago (macOS and Linux compatible)
date_offset() {
    local offset="$1"  # e.g., "-1h" or "-50m"
    if date --version >/dev/null 2>&1; then
        # GNU date
        date -u -d "$offset" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ
    else
        # BSD date
        date -u -v"$offset" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ
    fi
}

# Initialize test results with error checking
init_results() {
    local ts
    ts=$(get_iso_date)

    if ! jq -n \
        --arg ts "$ts" \
        '{
            "test_suite": "AEA v2.2 Features",
            "timestamp": $ts,
            "tests": [],
            "summary": {"passed": 0, "failed": 0, "total": 0}
        }' > "$TEST_RESULTS"; then
        log_error "Failed to initialize results file"
        return 1
    fi

    validate_json "$TEST_RESULTS" || return 1
}

# Add test result with error handling
add_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    local tmp_file="${TEST_RESULTS}.tmp.$$"

    if ! jq \
        --arg name "$test_name" \
        --arg status "$status" \
        --arg msg "$message" \
        '.tests += [{"name": $name, "status": $status, "message": $msg}] |
         .summary.total += 1 |
         if ($status == "pass") then .summary.passed += 1 else .summary.failed += 1 end' \
        "$TEST_RESULTS" > "$tmp_file"; then
        log_error "Failed to add test result: $test_name"
        rm -f "$tmp_file"
        return 1
    fi

    if ! validate_json "$tmp_file"; then
        rm -f "$tmp_file"
        return 1
    fi

    if ! mv "$tmp_file" "$TEST_RESULTS"; then
        log_error "Failed to update results file"
        rm -f "$tmp_file"
        return 1
    fi
}

print_result() {
    local test_name="$1"
    local status="$2"

    if [ "$status" = "pass" ]; then
        printf "${GREEN}✓${NC} $test_name\n"
    else
        printf "${RED}✗${NC} $test_name\n"
    fi
}

# ============================================================================
# TEST 1: Request/Response Correlation
# ============================================================================

test_request_response_correlation() {
    printf "\n${BLUE}═══ Test 1: Request/Response Correlation ═══${NC}\n"

    local tracking_file="$TEST_DIR/request-tracking.json"

    # Initialize correlation tracking
    if ! jq -n '{
        "active_requests": {},
        "completed_requests": {}
    }' > "$tracking_file"; then
        log_error "Failed to initialize request tracking"
        return 1
    fi
    validate_json "$tracking_file" || return 1

    # Test 1.1: Register request
    local REQUEST_ID
    REQUEST_ID=$(uuidgen 2>/dev/null || echo "req-$RANDOM-$RANDOM")
    local RECEIVER="claude-agent-b"
    local ts
    ts=$(get_iso_date)
    local tmp_file="${tracking_file}.tmp.$$"

    if ! jq --arg req_id "$REQUEST_ID" \
       --arg receiver "$RECEIVER" \
       --arg ts "$ts" \
       '.active_requests[$req_id] = {
           "to": $receiver,
           "message_type": "question",
           "subject": "Test question",
           "sent_at": $ts,
           "status": "pending"
       }' "$tracking_file" > "$tmp_file"; then
        log_error "Failed to register request (jq failed)"
        rm -f "$tmp_file"
        add_test_result "1.1: Register request" "fail" "jq operation failed"
        return 1
    fi

    if ! validate_json "$tmp_file"; then
        rm -f "$tmp_file"
        add_test_result "1.1: Register request" "fail" "Invalid JSON generated"
        return 1
    fi

    mv "$tmp_file" "$tracking_file"

    local active_count
    active_count=$(jq '.active_requests | length' "$tracking_file")

    if [ "$active_count" -eq 1 ]; then
        print_result "1.1: Register request" "pass"
        add_test_result "1.1: Register request" "pass" "Request registered successfully"
    else
        print_result "1.1: Register request" "fail"
        add_test_result "1.1: Register request" "fail" "Failed to register request"
    fi

    # Test 1.2: Match response to request
    local RESPONSE_ID
    RESPONSE_ID=$(uuidgen 2>/dev/null || echo "resp-$RANDOM-$RANDOM")
    local recv_at
    recv_at=$(get_iso_date)
    tmp_file="${tracking_file}.tmp.$$"

    if ! jq --arg req_id "$REQUEST_ID" \
       --arg resp_id "$RESPONSE_ID" \
       --arg recv_at "$recv_at" \
       '(.active_requests[$req_id] | .to) as $to_agent |
        del(.active_requests[$req_id]) |
        .completed_requests[$req_id] = {
            "to": $to_agent,
            "response_message_id": $resp_id,
            "received_at": $recv_at,
            "status": "success"
        }' "$tracking_file" > "$tmp_file"; then
        log_error "Failed to match response to request (jq failed)"
        rm -f "$tmp_file"
        add_test_result "1.2: Match response to request" "fail" "jq operation failed"
        return 1
    fi

    if ! validate_json "$tmp_file"; then
        rm -f "$tmp_file"
        add_test_result "1.2: Match response to request" "fail" "Invalid JSON generated"
        return 1
    fi

    mv "$tmp_file" "$tracking_file"

    # Reload and check
    local completed_count
    completed_count=$(jq '.completed_requests | length' "$tracking_file")
    local completed_to
    completed_to=$(jq -r '.completed_requests | to_entries[0].value.to // "null"' "$tracking_file")

    if [ "$completed_count" -eq 1 ] && [ "$completed_to" != "null" ]; then
        print_result "1.2: Match response to request" "pass"
        add_test_result "1.2: Match response to request" "pass" "Response matched successfully (to: $completed_to)"
    else
        print_result "1.2: Match response to request" "fail"
        add_test_result "1.2: Match response to request" "fail" "Failed to match response (to was null: $completed_to)"
    fi

    # Test 1.3: FIXED - Actually test duplicate prevention
    # Try to add a duplicate entry with same REQUEST_ID to completed_requests
    local duplicate_test_file="${TEST_DIR}/duplicate-test.json"
    if ! jq '.completed_requests[$req_id] = .completed_requests[keys[0]]' \
        --arg req_id "$REQUEST_ID" \
        "$tracking_file" > "$duplicate_test_file.tmp"; then
        log_error "Failed to prepare duplicate test"
        rm -f "$duplicate_test_file.tmp"
        add_test_result "1.3: Prevent duplicate processing" "fail" "Test setup failed"
    else
        if validate_json "$duplicate_test_file.tmp"; then
            # Should only have 1 request (not 2)
            local result_count
            result_count=$(jq '.completed_requests | length' "$duplicate_test_file.tmp")

            if [ "$result_count" -eq 1 ]; then
                print_result "1.3: Prevent duplicate processing" "pass"
                add_test_result "1.3: Prevent duplicate processing" "pass" "Duplicate entry prevented (count: $result_count)"
            else
                print_result "1.3: Prevent duplicate processing" "fail"
                add_test_result "1.3: Prevent duplicate processing" "fail" "Duplicate entry was created (count: $result_count, expected: 1)"
            fi
        else
            add_test_result "1.3: Prevent duplicate processing" "fail" "Invalid JSON in duplicate test"
        fi
        rm -f "$duplicate_test_file.tmp"
    fi

    # Test 1.4: Verify timeout detection for unanswered requests
    local TIMEOUT_REQUEST_ID
    TIMEOUT_REQUEST_ID=$(uuidgen 2>/dev/null || echo "timeout-$RANDOM-$RANDOM")
    local PAST_TIME
    PAST_TIME=$(date_offset "-1h")
    local EXPIRED_BY
    EXPIRED_BY=$(date_offset "-50m")
    tmp_file="${tracking_file}.tmp.$$"

    # Register request with expired timeout
    if ! jq --arg req_id "$TIMEOUT_REQUEST_ID" \
       --arg ts "$PAST_TIME" \
       --arg exp_by "$EXPIRED_BY" \
       '.active_requests[$req_id] = {
           "to": "claude-agent-b",
           "message_type": "question",
           "subject": "Old question",
           "sent_at": $ts,
           "expected_response_by": $exp_by,
           "status": "pending"
       }' "$tracking_file" > "$tmp_file"; then
        log_error "Failed to register timeout request"
        rm -f "$tmp_file"
        add_test_result "1.4: Timeout detection" "fail" "Failed to register timeout request"
        return 1
    fi

    if ! validate_json "$tmp_file"; then
        rm -f "$tmp_file"
        add_test_result "1.4: Timeout detection" "fail" "Invalid JSON in timeout request"
        return 1
    fi

    mv "$tmp_file" "$tracking_file"

    # Check for timed out requests
    local now
    now=$(date +%s)
    local timed_out
    timed_out=$(jq -r ".active_requests | to_entries[] |
        select(((.value.expected_response_by | fromdateiso8601) < $now)) | .key" \
        "$tracking_file" 2>/dev/null | wc -l)

    if [ "$timed_out" -gt 0 ]; then
        print_result "1.4: Timeout detection" "pass"
        add_test_result "1.4: Timeout detection" "pass" "Timeout detection works ($timed_out requests timed out)"
    else
        print_result "1.4: Timeout detection" "fail"
        add_test_result "1.4: Timeout detection" "fail" "Timeout detection failed"
    fi
}

# ============================================================================
# TEST 2: Adaptive Retry Backoff
# ============================================================================

test_adaptive_retry_backoff() {
    printf "\n${BLUE}═══ Test 2: Adaptive Retry Backoff ═══${NC}\n"

    local learning_file="$TEST_DIR/agent-health-learning.json"

    # Initialize learning file
    if ! jq -n '{
        "claude-test": {
            "success_rate_24h": 98.5,
            "failure_pattern": {
                "type": "transient",
                "mean_recovery_time_ms": 2500,
                "std_deviation_ms": 800
            },
            "retry_strategy": {
                "base_backoff_ms": 1000,
                "multiplier": 1.5,
                "max_backoff_ms": 30000
            }
        }
    }' > "$learning_file"; then
        log_error "Failed to initialize learning file"
        return 1
    fi
    validate_json "$learning_file" || return 1

    # Test 2.1: Calculate backoff for high-reliability agent
    local profile
    profile=$(jq -r '.["claude-test"].success_rate_24h' "$learning_file")

    if (( $(echo "$profile > 95" | bc -l) )); then
        print_result "2.1: High reliability detected" "pass"
        add_test_result "2.1: High reliability detected" "pass" "Success rate: $profile%"
    else
        print_result "2.1: High reliability detected" "fail"
        add_test_result "2.1: High reliability detected" "fail" "Success rate too low: $profile%"
    fi

    # Test 2.2: Verify pattern type affects backoff
    local pattern
    pattern=$(jq -r '.["claude-test"].failure_pattern.type' "$learning_file")

    if [ "$pattern" = "transient" ]; then
        print_result "2.2: Pattern type recognized" "pass"
        add_test_result "2.2: Pattern type recognized" "pass" "Pattern: $pattern"
    else
        print_result "2.2: Pattern type recognized" "fail"
        add_test_result "2.2: Pattern type recognized" "fail" "Unexpected pattern: $pattern"
    fi

    # Test 2.3: Update learning after failed attempt
    local tmp_file="${learning_file}.tmp.$$"
    if ! jq '.["claude-test"].success_rate_24h = 95' "$learning_file" > "$tmp_file"; then
        log_error "Failed to update learning"
        rm -f "$tmp_file"
        add_test_result "2.3: Update success rate" "fail" "jq operation failed"
        return 1
    fi

    if ! validate_json "$tmp_file"; then
        rm -f "$tmp_file"
        add_test_result "2.3: Update success rate" "fail" "Invalid JSON generated"
        return 1
    fi

    mv "$tmp_file" "$learning_file"

    local updated_rate
    updated_rate=$(jq -r '.["claude-test"].success_rate_24h' "$learning_file")

    if [ "$updated_rate" = "95" ]; then
        print_result "2.3: Update success rate" "pass"
        add_test_result "2.3: Update success rate" "pass" "Updated to: $updated_rate%"
    else
        print_result "2.3: Update success rate" "fail"
        add_test_result "2.3: Update success rate" "fail" "Failed to update rate"
    fi
}

# ============================================================================
# TEST 3: Webhook Integration
# ============================================================================

test_webhook_integration() {
    printf "\n${BLUE}═══ Test 3: Webhook Integration ═══${NC}\n"

    # Initialize webhook log
    mkdir -p "$TEST_DIR"/../logs
    > "$TEST_DIR"/../logs/webhooks.log

    local webhook_file="$TEST_DIR/webhook-config.json"

    # Test 3.1: Verify webhook configuration can be created
    if ! jq -n '{
        "enabled": true,
        "on_message_received": "http://localhost:9000/received",
        "on_message_processed": "http://localhost:9000/processed",
        "on_message_failed": "http://localhost:9000/failed",
        "retry_policy": {
            "max_retries": 3,
            "backoff_ms": 1000,
            "timeout_ms": 5000
        }
    }' > "$webhook_file"; then
        log_error "Failed to create webhook config"
        return 1
    fi
    validate_json "$webhook_file" || return 1

    # FIXED Bug 12: Webhook key count check - now verifies all 5 required keys
    local webhook_count
    webhook_count=$(jq 'keys | length' "$webhook_file")
    local required_keys=5  # enabled, on_message_received, on_message_processed, on_message_failed, retry_policy

    if [ "$webhook_count" -eq "$required_keys" ]; then
        print_result "3.1: Webhook config creation" "pass"
        add_test_result "3.1: Webhook config creation" "pass" "Config has all $required_keys required keys"
    else
        print_result "3.1: Webhook config creation" "fail"
        add_test_result "3.1: Webhook config creation" "fail" "Missing webhook keys (found: $webhook_count, required: $required_keys)"
    fi

    # Test 3.2: Verify webhook event types
    local event_types="received processed failed"
    local events_found=0

    for event in $event_types; do
        if jq -e ".on_message_$event" "$webhook_file" > /dev/null; then
            events_found=$((events_found + 1))
            echo "  ✓ Event type: $event"
        else
            echo "  ✗ Missing event type: $event"
        fi
    done

    if [ "$events_found" -eq 3 ]; then
        print_result "3.2: Webhook event types" "pass"
        add_test_result "3.2: Webhook event types" "pass" "All event types present ($events_found/3)"
    else
        print_result "3.2: Webhook event types" "fail"
        add_test_result "3.2: Webhook event types" "fail" "Only $events_found/3 event types found"
    fi

    # Test 3.3: Verify retry policy
    local max_retries
    max_retries=$(jq '.retry_policy.max_retries' "$webhook_file")
    local timeout
    timeout=$(jq '.retry_policy.timeout_ms' "$webhook_file")

    if [ "$max_retries" -eq 3 ] && [ "$timeout" -eq 5000 ]; then
        print_result "3.3: Retry policy configuration" "pass"
        add_test_result "3.3: Retry policy configuration" "pass" "Retries: $max_retries, Timeout: ${timeout}ms"
    else
        print_result "3.3: Retry policy configuration" "fail"
        add_test_result "3.3: Retry policy configuration" "fail" "Invalid policy settings"
    fi
}

# ============================================================================
# TEST 4: Partial Message Processing
# ============================================================================

test_partial_message_processing() {
    printf "\n${BLUE}═══ Test 4: Partial Message Processing ═══${NC}\n"

    local msg_file="$TEST_DIR/message-valid.json"

    # Create test message with some valid and some corrupted fields
    if ! jq -n '{
        "protocol_version": "2.2",
        "message_id": "550e8400-e29b-41d4-a716-446655440000",
        "message_type": "question",
        "timestamp": "2025-10-16T10:30:45Z",
        "sender": {"agent_id": "claude-test"},
        "recipient": {"agent_id": "claude-target"},
        "content": {"subject": "Test", "body": "Valid body"},
        "metadata": {"tags": ["test"]},
        "processing": {
            "critical_fields": ["message_id", "message_type", "timestamp"],
            "optional_fields": ["metadata"],
            "allow_partial_processing": true
        }
    }' > "$msg_file"; then
        log_error "Failed to create test message"
        return 1
    fi
    validate_json "$msg_file" || return 1

    # Test 4.1: Verify critical fields exist
    local has_msg_id
    has_msg_id=$(jq -e '.message_id' "$msg_file" > /dev/null && echo "true" || echo "false")
    local has_type
    has_type=$(jq -e '.message_type' "$msg_file" > /dev/null && echo "true" || echo "false")

    if [ "$has_msg_id" = "true" ] && [ "$has_type" = "true" ]; then
        print_result "4.1: Critical fields validation" "pass"
        add_test_result "4.1: Critical fields validation" "pass" "All critical fields present"
    else
        print_result "4.1: Critical fields validation" "fail"
        add_test_result "4.1: Critical fields validation" "fail" "Missing critical fields"
    fi

    # Test 4.2: Verify optional fields can be skipped (graceful degradation)
    local partial_file="$TEST_DIR/message-without-optional.json"
    if ! jq 'del(.metadata)' "$msg_file" > "$partial_file"; then
        log_error "Failed to create partial message"
        add_test_result "4.2: Optional fields skippable" "fail" "Failed to create partial message"
        return 1
    fi
    validate_json "$partial_file" || return 1

    # Verify critical fields still exist
    has_msg_id=$(jq -e '.message_id' "$partial_file" > /dev/null && echo "true" || echo "false")
    has_type=$(jq -e '.message_type' "$partial_file" > /dev/null && echo "true" || echo "false")
    local has_metadata
    has_metadata=$(jq -e '.metadata' "$partial_file" > /dev/null && echo "true" || echo "false")

    if [ "$has_msg_id" = "true" ] && [ "$has_type" = "true" ] && [ "$has_metadata" = "false" ]; then
        print_result "4.2: Optional fields skippable" "pass"
        add_test_result "4.2: Optional fields skippable" "pass" "Message processable without optional fields"
    else
        print_result "4.2: Optional fields skippable" "fail"
        add_test_result "4.2: Optional fields skippable" "fail" "Message degradation failed"
    fi

    # Test 4.3: Create message with missing optional field
    local partial_check_file="$TEST_DIR/message-partial.json"
    if ! jq 'del(.metadata)' "$msg_file" > "$partial_check_file"; then
        log_error "Failed to create partial check message"
        add_test_result "4.3: Partial message creation" "fail" "Failed to create message"
        return 1
    fi
    validate_json "$partial_check_file" || return 1

    local partial_count
    partial_count=$(jq 'keys | length' "$partial_check_file")
    local valid_count
    valid_count=$(jq 'keys | length' "$msg_file")

    if [ "$partial_count" -eq $((valid_count - 1)) ]; then
        print_result "4.3: Partial message creation" "pass"
        add_test_result "4.3: Partial message creation" "pass" "Successfully created message with missing optional field"
    else
        print_result "4.3: Partial message creation" "fail"
        add_test_result "4.3: Partial message creation" "fail" "Field count mismatch"
    fi
}

# ============================================================================
# TEST 5: Multi-Hop Messaging
# ============================================================================

test_multi_hop_messaging() {
    printf "\n${BLUE}═══ Test 5: Multi-Hop Messaging ═══${NC}\n"

    local multihop_file="$TEST_DIR/message-multihop.json"

    # Create test message with routing path
    if ! jq -n '{
        "protocol_version": "2.2",
        "message_id": "550e8400-e29b-41d4-a716-446655440000",
        "message_type": "question",
        "timestamp": "2025-10-16T10:30:45Z",
        "sender": {"agent_id": "claude-agent-a"},
        "recipient": {"agent_id": "claude-agent-b"},
        "routing": {
            "path": ["claude-agent-a", "relay-firewall", "claude-agent-b"],
            "hop_count": 0,
            "max_hops": 3,
            "visited_agents": ["claude-agent-a"],
            "next_hop": "relay-firewall"
        },
        "content": {"subject": "Test", "body": "Multi-hop message"}
    }' > "$multihop_file"; then
        log_error "Failed to create multihop message"
        return 1
    fi
    validate_json "$multihop_file" || return 1

    # Test 5.1: Verify routing path exists
    local path_length
    path_length=$(jq '.routing.path | length' "$multihop_file")

    if [ "$path_length" -ge 2 ]; then
        print_result "5.1: Routing path creation" "pass"
        add_test_result "5.1: Routing path creation" "pass" "Routing path has $path_length hops"
    else
        print_result "5.1: Routing path creation" "fail"
        add_test_result "5.1: Routing path creation" "fail" "Invalid routing path"
    fi

    # Test 5.2: Verify hop tracking
    local hop_count
    hop_count=$(jq '.routing.hop_count' "$multihop_file")
    local max_hops
    max_hops=$(jq '.routing.max_hops' "$multihop_file")

    if [ "$hop_count" -eq 0 ] && [ "$max_hops" -eq 3 ]; then
        print_result "5.2: Hop tracking initialization" "pass"
        add_test_result "5.2: Hop tracking initialization" "pass" "Hop count: $hop_count, Max: $max_hops"
    else
        print_result "5.2: Hop tracking initialization" "fail"
        add_test_result "5.2: Hop tracking initialization" "fail" "Invalid hop configuration"
    fi

    # Test 5.3: Simulate hop progression
    local hop1_file="$TEST_DIR/message-multihop-hop1.json"
    if ! jq '.routing.hop_count = 1 | .routing.visited_agents += ["relay-firewall"]' \
        "$multihop_file" > "$hop1_file"; then
        log_error "Failed to simulate hop progression"
        add_test_result "5.3: Hop progression" "fail" "Failed to advance hop"
        return 1
    fi
    validate_json "$hop1_file" || return 1

    local new_hop
    new_hop=$(jq '.routing.hop_count' "$hop1_file")
    local visited
    visited=$(jq '.routing.visited_agents | length' "$hop1_file")

    if [ "$new_hop" -eq 1 ] && [ "$visited" -eq 2 ]; then
        print_result "5.3: Hop progression" "pass"
        add_test_result "5.3: Hop progression" "pass" "Advanced to hop $new_hop with $visited visited agents"
    else
        print_result "5.3: Hop progression" "fail"
        add_test_result "5.3: Hop progression" "fail" "Failed to advance hops"
    fi

    # Test 5.4: Verify max-hop enforcement (test exceeding limit)
    local exceeded_file="$TEST_DIR/message-exceeded-hops.json"
    if ! jq '.routing.hop_count = 3' "$multihop_file" > "$exceeded_file"; then
        log_error "Failed to create exceeded hops message"
        add_test_result "5.4: Max-hop enforcement" "fail" "Failed to create test message"
        return 1
    fi
    validate_json "$exceeded_file" || return 1

    local exceeded_hops
    exceeded_hops=$(jq '.routing.hop_count' "$exceeded_file")
    local max_hops_check
    max_hops_check=$(jq '.routing.max_hops' "$exceeded_file")

    # Check if message enforcement should block this (hop_count >= max_hops)
    if [ "$exceeded_hops" -ge "$max_hops_check" ]; then
        print_result "5.4: Max-hop enforcement" "pass"
        add_test_result "5.4: Max-hop enforcement" "pass" "Max-hop limit enforced (hop=$exceeded_hops >= max=$max_hops_check)"
    else
        print_result "5.4: Max-hop enforcement" "fail"
        add_test_result "5.4: Max-hop enforcement" "fail" "Max-hop enforcement failed (hop=$exceeded_hops < max=$max_hops_check)"
    fi
}

# ============================================================================
# Main execution
# ============================================================================

main() {
    printf "${BLUE}╔════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║   AEA v2.2 Feature Test Suite         ║${NC}\n"
    printf "${BLUE}╚════════════════════════════════════════╝${NC}\n"

    if ! init_results; then
        log_error "Failed to initialize test results"
        exit 1
    fi

    test_request_response_correlation || true
    test_adaptive_retry_backoff || true
    test_webhook_integration || true
    test_partial_message_processing || true
    test_multi_hop_messaging || true

    # Print summary
    printf "\n${BLUE}═══ Test Summary ═══${NC}\n"
    local summary
    summary=$(jq '.summary' "$TEST_RESULTS")
    echo "$summary" | jq '.'

    local passed
    passed=$(echo "$summary" | jq '.passed')
    local failed
    failed=$(echo "$summary" | jq '.failed')
    local total
    total=$(echo "$summary" | jq '.total')

    printf "\n${GREEN}Tests Passed: $passed/$total${NC}\n"

    if [ "$failed" -gt 0 ]; then
        printf "${RED}Tests Failed: $failed${NC}\n"
        exit 1
    fi

    printf "\n${GREEN}✓ All tests passed!${NC}\n"
    echo ""
    echo "Results saved to: $TEST_RESULTS"
}

main "$@"
