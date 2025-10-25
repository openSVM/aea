#!/usr/bin/env bash
#
# AEA Test Scenario Creator
# Creates various test messages to demonstrate AEA functionality
#
# Usage:
#   ./create-test-scenarios.sh [scenario_type]
#
# Scenarios:
#   simple-question    - Simple technical question (auto-responds)
#   urgent-issue       - Urgent bug report (requires approval)
#   handoff           - Integration handoff (requires approval)
#   update            - Status update (auto-acknowledges)
#   complex-request   - Complex feature request (auto-responds with plan)
#   all               - Create all scenarios
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEA_DIR="$(dirname "$SCRIPT_DIR")"

# Detect if we're in the development repo or installed in .aea/
if [ -f "$AEA_DIR/PROTOCOL.md" ] && [ -f "$AEA_DIR/aea.sh" ]; then
    # Development repo: AEA_DIR is the repo root, use it directly
    PROJECT_ROOT="$AEA_DIR"
else
    # Installed: AEA_DIR is .aea/, PROJECT_ROOT is parent
    PROJECT_ROOT="$(dirname "$AEA_DIR")"
fi

if ! cd "$PROJECT_ROOT"; then
    echo "ERROR: Failed to change to project root: $PROJECT_ROOT"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Ensure .aea directory exists and is writable
ensure_aea_directory() {
    if ! mkdir -p .aea/.processed 2>/dev/null; then
        log_error "Failed to create .aea directory - check permissions"
        return 1
    fi

    if [ ! -w ".aea" ]; then
        log_error ".aea directory is not writable"
        return 1
    fi

    return 0
}

# Get consistent timestamp (compatible with aea-common.sh format)
get_timestamp() {
    # Try to get milliseconds (not all systems support %N)
    if date --version &>/dev/null; then
        # GNU date
        date -u +%Y%m%dT%H%M%S%3NZ 2>/dev/null || date -u +%Y%m%dT%H%M%SZ
    else
        # BSD date (macOS)
        date -u +%Y%m%dT%H%M%SZ
    fi
}

# Scenario 1: Simple Question (Auto-responds)
create_simple_question() {
    ensure_aea_directory || return 1

    local timestamp=$(get_timestamp)
    local filename=".aea/message-${timestamp}-from-claude-test-simple.json"

    cat > "$filename" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-simple-question",
  "message_type": "question",
  "timestamp": "2025-10-14T16:00:00Z",
  "sender": {
    "agent_id": "claude-test",
    "repo_path": "/tmp/test",
    "user": "developer"
  },
  "recipient": {
    "agent_id": "claude-current"
  },
  "routing": {
    "priority": "normal",
    "requires_response": true
  },
  "content": {
    "subject": "How to optimize orderbook insertion performance?",
    "body": "We're seeing slow orderbook insertions at high load. What are the recommended optimization strategies? Are there any SIMD optimizations available?\n\nContext:\n- Current throughput: 150 orders/sec\n- Target throughput: 500 orders/sec\n- Current method: single-threaded insertion"
  },
  "metadata": {
    "conversation_id": "test-simple-question",
    "tags": ["performance", "optimization"]
  }
}
EOF

    log_success "Created simple question: $filename"
    echo "   Expected: ✅ Auto-respond with technical guidance"
}

# Scenario 2: Urgent Issue (Requires Approval)
create_urgent_issue() {
    ensure_aea_directory || return 1
    local timestamp=$(get_timestamp)
    local filename=".aea/message-${timestamp}-from-claude-test-urgent.json"

    cat > "$filename" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-urgent-issue",
  "message_type": "issue",
  "timestamp": "2025-10-14T16:05:00Z",
  "sender": {
    "agent_id": "claude-agent-b",
    "repo_path": "/path/to/repo-b",
    "user": "developer"
  },
  "recipient": {
    "agent_id": "claude-agent-a"
  },
  "routing": {
    "priority": "urgent",
    "requires_response": true
  },
  "content": {
    "subject": "🚨 URGENT: Memory leak in production causing OOM",
    "body": "Production Redis instance experiencing memory leak. Memory usage growing 500MB/hour. Will hit OOM in ~3 hours.\n\nReproduction steps:\n1. Start Redis with module loaded\n2. Send 10k orderbook updates per second\n3. Monitor memory with INFO MEMORY\n4. Observe steady growth without corresponding data increase\n\nImpact: CRITICAL - Production stability at risk. Service will crash in ~3 hours without intervention.\n\nLogs: Last 1000 lines show repeated FFI string allocations without corresponding frees\n\nEnvironment:\n- Redis version: 7.0.12\n- Module version: latest\n- Load: 10k updates/sec\n- Memory growth rate: 500MB/hour\n- Current memory: 4.2GB\n- Max memory: 6GB"
  },
  "metadata": {
    "conversation_id": "urgent-memory-leak",
    "tags": ["urgent", "memory-leak", "production", "critical"]
  }
}
EOF

    log_success "Created urgent issue: $filename"
    echo "   Expected: ❌ Notify user, wait for approval before analyzing"
}

# Scenario 3: Handoff (Requires Approval)
create_handoff() {
    ensure_aea_directory || return 1
    local timestamp=$(get_timestamp)
    local filename=".aea/message-${timestamp}-from-claude-test-handoff.json"

    cat > "$filename" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-handoff",
  "message_type": "handoff",
  "timestamp": "2025-10-14T16:10:00Z",
  "sender": {
    "agent_id": "claude-agent-b",
    "repo_path": "/path/to/repo-b",
    "user": "developer"
  },
  "recipient": {
    "agent_id": "claude-agent-a"
  },
  "routing": {
    "priority": "high",
    "requires_response": true
  },
  "content": {
    "subject": "Batch API integration complete - ready for client updates",
    "body": "Implemented batch orderbook insertion API with connection pooling. Server-side changes are complete and tested. Ready for client integration.\n\nCompleted work:\n- Batch insertion endpoint: ORDERBOOKMAP.BATCH.INSERT\n- Connection pool management with configurable pool_size\n- Error handling with partial success support\n- Performance testing: 257 orders/sec concurrent throughput\n- Documentation in docs/batch-api.md\n\nNext steps:\n- Update client to use batch API instead of single inserts\n- Configure connection pool size (recommended: 25-30 for 10k updates/sec)\n- Implement client-side batching logic\n- Add retry logic for failed batches\n- End-to-end integration testing\n\nBreaking changes:\n- Single insert API still supported but deprecated\n- New error response format for batch operations\n\nDocumentation: See repo-b/docs/batch-api.md and repo-a/CLAUDE.md:2239-2247\nMigration guide: repo-b/docs/migration-to-batch-api.md"
  },
  "metadata": {
    "conversation_id": "batch-api-integration",
    "tags": ["handoff", "integration", "batch-api"]
  }
}
EOF

    log_success "Created handoff: $filename"
    echo "   Expected: ⚠️ Summarize and request user approval"
}

# Scenario 4: Status Update (Auto-acknowledges)
create_update() {
    ensure_aea_directory || return 1
    local timestamp=$(get_timestamp)
    local filename=".aea/message-${timestamp}-from-claude-test-update.json"

    cat > "$filename" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-update",
  "message_type": "update",
  "timestamp": "2025-10-14T16:15:00Z",
  "sender": {
    "agent_id": "claude-agent-b",
    "repo_path": "/path/to/repo-b",
    "user": "developer"
  },
  "recipient": {
    "agent_id": "claude-agent-a"
  },
  "routing": {
    "priority": "normal",
    "requires_response": true
  },
  "content": {
    "subject": "Deployed batch API v2.1.0 to staging",
    "body": "Successfully deployed new batch API version to staging environment. All tests passing.\n\nChanges:\n- batch_size: 50 -> 100 (2x throughput improvement)\n- pool_size: 10 -> 25 (better concurrency handling)\n- Added connection retry logic with exponential backoff\n- Improved error messages for batch validation failures\n\nMetrics:\n- Deployment time: 2025-10-14T15:45:00Z\n- Downtime: 0 seconds (rolling deployment)\n- Test results: 112/112 passing\n- Performance improvement: 2.3x throughput increase\n\nNext deployment: Production deployment scheduled for 2025-10-15 if no issues found"
  },
  "metadata": {
    "conversation_id": "deployment-updates",
    "tags": ["deployment", "staging", "batch-api"]
  }
}
EOF

    log_success "Created update: $filename"
    echo "   Expected: ✅ Auto-acknowledge (requires_response: true)"
}

# Scenario 5: Complex Request (Auto-responds with plan)
create_complex_request() {
    ensure_aea_directory || return 1
    local timestamp=$(get_timestamp)
    local filename=".aea/message-${timestamp}-from-claude-test-request.json"

    cat > "$filename" << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-complex-request",
  "message_type": "request",
  "timestamp": "2025-10-14T16:20:00Z",
  "sender": {
    "agent_id": "claude-agent-b",
    "repo_path": "/path/to/repo-b",
    "user": "developer"
  },
  "recipient": {
    "agent_id": "claude-agent-a"
  },
  "routing": {
    "priority": "normal",
    "requires_response": true
  },
  "content": {
    "subject": "Add streaming orderbook updates API",
    "body": "Need a streaming API for orderbook updates to reduce latency and network overhead compared to polling.\n\nRationale: Current polling approach has 100ms latency minimum. Streaming would provide <10ms latency for critical price updates.\n\nRequirements:\n- Redis PUBLISH/SUBSCRIBE for orderbook changes\n- Client library with auto-reconnection\n- Filtering by exchange and trading pair\n- Delta updates only (not full snapshots)\n- Backpressure handling for slow consumers\n\nAcceptance criteria:\n- Latency < 10ms for price updates\n- Support 1000+ concurrent subscribers\n- Automatic reconnection on connection loss\n- Message ordering guarantees\n- Comprehensive error handling\n\nConstraints:\n- Must work with existing ORDERBOOKMAP commands\n- No breaking changes to current API\n- Memory overhead < 1MB per subscriber\n- Redis version 7.0+ compatible\n\nTimeline: Target: 2 weeks for initial implementation\n\nPriority justification: High-frequency trading clients need real-time updates. Current latency losing trades to competitors."
  },
  "metadata": {
    "conversation_id": "streaming-api-request",
    "tags": ["feature-request", "streaming", "performance"]
  }
}
EOF

    log_success "Created complex request: $filename"
    echo "   Expected: ✅ Analyze and respond with implementation plan"
}

# Main script
case "${1:-all}" in
    simple-question)
        create_simple_question
        ;;
    urgent-issue)
        create_urgent_issue
        ;;
    handoff)
        create_handoff
        ;;
    update)
        create_update
        ;;
    complex-request)
        create_complex_request
        ;;
    all)
        log_info "Creating all test scenarios..."
        echo ""
        create_simple_question
        echo ""
        create_urgent_issue
        echo ""
        create_handoff
        echo ""
        create_update
        echo ""
        create_complex_request
        echo ""
        log_success "All test scenarios created!"
        echo ""
        echo "Run: bash .aea/scripts/aea-check.sh"
        echo "Or in Claude: /aea"
        ;;
    *)
        echo "Usage: $0 {simple-question|urgent-issue|handoff|update|complex-request|all}"
        echo ""
        echo "Scenarios:"
        echo "  simple-question    - Simple technical question (auto-responds)"
        echo "  urgent-issue       - Urgent bug report (requires approval)"
        echo "  handoff           - Integration handoff (requires approval)"
        echo "  update            - Status update (auto-acknowledges)"
        echo "  complex-request   - Complex feature request (responds with plan)"
        echo "  all               - Create all scenarios"
        exit 1
        ;;
esac
