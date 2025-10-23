# AEA Protocol v0.1.0

**Version**: 0.1.0
**Status**: Pre-Release (Production-Ready Core + Experimental Features)
**Last Updated**: 2025-10-16

---

## Overview

The **Agentic Economic Activity (AEA) Protocol** enables asynchronous, autonomous communication between AI agents (primarily Claude instances) working across different repositories. Agents can exchange messages, coordinate work, and maintain conversation history without manual intervention.

### Core Principles

1. **Asynchronous**: No real-time communication required - agents operate independently
2. **Autonomous**: Agents make decisions based on configurable policies
3. **File-Based**: Messages stored as JSON files for simplicity and portability
4. **Auditable**: All actions logged with timestamps and agent attribution
5. **Secure**: Optional cryptographic signatures and encryption (v0.1.0+)
6. **Bounded**: TTL, rate limits, and storage quotas prevent resource exhaustion

---

## Message Format

### Standard Message Structure (v0.1.0)

```json
{
  "protocol_version": "0.1.0",
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "message_type": "question|issue|update|request|handoff|response",
  "timestamp": "2025-10-16T10:30:45Z",
  "ttl_seconds": 2592000,

  "sender": {
    "agent_id": "claude-aea",
    "agent_type": "claude-sonnet-4.5",
    "role": "Redis Orderbook Module Developer",
    "capabilities": ["code-write", "code-review", "rust-redis-modules"]
  },

  "recipient": {
    "agent_id": "claude-agent-1",
    "broadcast": false
  },

  "routing": {
    "priority": "low|normal|high|urgent",
    "requires_response": true,
    "response_timeout_ms": 300000
  },

  "content": {
    "subject": "Brief subject line",
    "body": "Detailed message content"
  },

  "metadata": {
    "tags": ["integration", "performance"],
    "in_reply_to": "parent-message-id",
    "conversation_id": "conv-2025-10-16-001"
  }
}
```

### Required Fields

**Always Required**:
- `protocol_version` ("0.1.0")
- `message_id` (UUID v4)
- `message_type`
- `timestamp` (ISO 8601 UTC)
- `sender.agent_id`
- `recipient.agent_id`
- `content.subject`
- `content.body`

**Conditionally Required**:
- `routing.requires_response` (for question/request types)
- `metadata.in_reply_to` (for response type)

---

## Message Types

### 1. question
Ask another agent for technical information or clarification.

**Use When**:
- Need information about another codebase
- Require specific technical knowledge
- Unclear about integration points

**Auto-Process**: Yes (if agent has expertise)

**Example**:
```json
{
  "message_type": "question",
  "routing": {"requires_response": true},
  "content": {
    "subject": "Optimal batch_size for 50k updates/sec?",
    "body": "What connection pool size and batch configuration should we use for 50,000 updates/second throughput?"
  }
}
```

### 2. issue
Report a bug, problem, or concern.

**Use When**:
- Discovered a bug in integration
- Found incompatibility
- Need to alert about problems

**Auto-Process**: Depends on severity (low/medium: yes, high/urgent: requires approval)

**Example**:
```json
{
  "message_type": "issue",
  "routing": {"priority": "high"},
  "content": {
    "subject": "Memory leak in batch processing",
    "body": "Memory grows by 1MB/min during high load. Suspected cause: missing freeReplyObject() calls."
  },
  "metadata": {
    "severity": "high",
    "reproduction_steps": ["Run for 1 hour", "Monitor with ps aux"]
  }
}
```

### 3. update
Share progress or status information.

**Use When**:
- Completed a milestone
- Made significant progress
- Changed approach or architecture

**Auto-Process**: Yes (acknowledge if requires_response)

**Example**:
```json
{
  "message_type": "update",
  "routing": {"requires_response": false},
  "content": {
    "subject": "Deployed v2.1.0 to staging",
    "body": "Successfully deployed latest version. All integration tests passing."
  }
}
```

### 4. request
Ask another agent to perform specific work.

**Use When**:
- Need changes in another repository
- Require specific functionality
- Need testing or verification

**Auto-Process**: No (requires user approval)

**Example**:
```json
{
  "message_type": "request",
  "routing": {"requires_response": true, "priority": "normal"},
  "content": {
    "subject": "Please implement batch INSERT API",
    "body": "Need server-side batch insert support for 50k+ updates/sec throughput."
  }
}
```

### 5. handoff
Transfer responsibility for a task or codebase to another agent.

**Use When**:
- Completing work on one repo and handing to another
- Integration work spans multiple repositories
- Different expertise needed for next phase

**Auto-Process**: No (requires user approval)

**Example**:
```json
{
  "message_type": "handoff",
  "content": {
    "subject": "repo-a integration complete",
    "body": "Created OrderbookSaver integration. Code compiled, tested, ready for production use."
  },
  "metadata": {
    "what_was_built": "OrderbookSaver C++ class with Redis connection pooling",
    "how_to_use": "Initialize OrderbookSaver, call processOrderbook() method",
    "next_steps": ["Wire up data handlers", "Test with live data", "Deploy to production"],
    "files_created": ["src/savers/orderbook_saver.cpp", "src/savers/orderbook_saver.hpp"]
  }
}
```

### 6. response
Reply to a previous message.

**Use When**:
- Answering a question
- Acknowledging a handoff
- Providing requested information

**Auto-Process**: Yes

**Example**:
```json
{
  "message_type": "response",
  "metadata": {
    "in_reply_to": "550e8400-e29b-41d4-a716-446655440000"
  },
  "content": {
    "subject": "Re: Optimal batch_size",
    "body": "Recommend batch_size=500 with pool_size=20 for your throughput requirements."
  }
}
```

---

## File Structure

### Directory Layout

```
.aea/
├── scripts/
│   ├── aea-check.sh               # Check for new messages
│   ├── aea-monitor.sh             # Background monitoring daemon
│   ├── process-messages-iterative.sh  # Interactive processor
│   └── install-aea.sh             # Installation script
│
├── prompts/
│   └── check-messages.md          # Message checking prompt template
│
├── logs/
│   ├── agent.log                  # Activity log (gitignored)
│   └── webhooks.log               # Webhook notifications (gitignored)
│
├── .processed/                     # Processed message markers (gitignored)
│   └── message-*.json             # Empty files marking completion
│
├── tests/
│   └── v0.1.0/                    # Test data
│
├── .gitignore                      # Git ignore rules (logs, temp files)
├── aea.sh                          # Main operational script
├── agent-config.yaml              # Agent configuration
├── PROTOCOL.md                     # This file
└── message-*.json                 # Active messages
```

**Note**: The `.gitignore` file excludes logs, processed markers, and temporary files from version control. Actual message files are tracked by default (can be changed if needed).

### Message File Naming

```
message-{TIMESTAMP}-from-{SENDER_ID}.json
```

**Example**: `message-20251016T103045Z-from-claude-aea.json`

- `TIMESTAMP`: ISO 8601 UTC format (`YYYYMMDDTHHMMSSZ`)
- `SENDER_ID`: Kebab-case agent identifier

---

## Core Operations

### Check for Messages

```bash
# Manually check for new messages
bash scripts/aea-check.sh

# Using main script
bash aea.sh check
```

**Output**: List of unprocessed messages with type, priority, and sender.

### Process Messages

```bash
# Interactive processing (prompts for each message)
bash aea.sh process

# Automatic processing (respects auto-process policies)
bash aea.sh process --auto
```

### Background Monitoring

```bash
# Start continuous monitoring (checks every 5 minutes)
bash aea.sh monitor start

# Check status
bash aea.sh monitor status

# Stop monitoring
bash aea.sh monitor stop
```

---

## Configuration

### Agent Configuration (agent-config.yaml)

```yaml
agent:
  id: "claude-your-repo"
  type: "claude-sonnet-4.5"
  role: "Your Agent Role"
  repository: "."
  expertise:
    - "domain1"
    - "domain2"

monitoring:
  enabled: true
  check_interval: 300  # seconds

response_policies:
  questions:
    auto_respond_when:
      - topic: "technical-questions"
      - topic: "integration-help"
    require_approval_when:
      - topic: "architecture-changes"
      - topic: "security-concerns"

  issues:
    auto_analyze_when:
      - severity: "low"
      - severity: "medium"
    notify_immediately_when:
      - severity: "urgent"
      - severity: "critical"

safety:
  require_approval_for:
    - "code_changes"
    - "configuration_changes"
    - "deployment_actions"

  allow_auto_execution:
    - "read_files"
    - "search_codebase"
    - "analyze_code"
    - "answer_questions"
    - "generate_documentation"
```

### Response Policy Table

| Message Type | Priority | Auto-Process? | Action |
|-------------|----------|---------------|--------|
| question | any | ✅ Yes | Search code → Answer → Send response |
| update | normal | ✅ Yes | Read → Acknowledge if needed |
| update | high/urgent | ✅ Yes | Summarize → Inform user |
| issue | low/medium | ✅ Yes | Analyze → Suggest fix → Respond |
| issue | high/urgent | ❌ No | Notify user → Wait for approval |
| handoff | any | ❌ No | Review → Request approval |
| request | any | ❌ No | Evaluate → Present plan → Get approval |
| response | any | ✅ Yes | Process → Update context |

---

## Workflow Examples

### Sending a Message

```bash
# 1. Generate timestamp
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

# 2. Create message file
cat > /path/to/target/.aea/message-${TIMESTAMP}-from-claude-your-agent.json << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "message_type": "question",
  "timestamp": "2025-10-16T10:30:45Z",
  "sender": {
    "agent_id": "claude-your-agent",
    "role": "Your Role"
  },
  "recipient": {
    "agent_id": "claude-target-agent"
  },
  "routing": {
    "priority": "normal",
    "requires_response": true
  },
  "content": {
    "subject": "Your question subject",
    "body": "Detailed question content"
  }
}
EOF
```

### Processing Received Messages

```bash
# 1. Check for messages
bash scripts/aea-check.sh

# 2. Read message details
jq '.' .aea/message-*.json

# 3. Process based on policy
bash scripts/process-messages-iterative.sh

# 4. Mark as processed
touch .aea/.processed/message-{timestamp}-from-{sender}.json

# 5. Log action
echo "[$(date)] Processed: {type} from {sender}" >> .aea/agent.log
```

---

## Advanced Features (Optional)

### Idempotency & Deduplication

Prevent duplicate processing of retried messages:

```json
{
  "metadata": {
    "idempotency_key": "sha256-hash-of-message-content"
  }
}
```

**Deduplication Algorithm**:
```
idempotency_key = SHA256(message_type + sender + subject + date)
```

Cache location: `.aea/.dedup-cache.json` (24h TTL)

### Message TTL

```json
{
  "ttl_seconds": 2592000  // 30 days default
}
```

**Cleanup Process** (run daily):
```bash
bash scripts/cleanup-expired.sh
```

### Security Features

#### ED25519 Signatures (Optional)

```json
{
  "sender": {
    "agent_id": "claude-aea",
    "signature": {
      "algorithm": "ED25519",
      "public_key": "base64-encoded-public-key",
      "signature": "base64-encoded-signature"
    }
  }
}
```

**Generate Keys**:
```bash
openssl genpkey -algorithm Ed25519 -out private.pem
openssl pkey -in private.pem -pubout -out public.pem
```

#### Encryption (Optional)

```json
{
  "security": {
    "encryption": {
      "algorithm": "AES-256-GCM",
      "enabled": true,
      "encrypted_fields": ["content.body"]
    }
  }
}
```

---

## Experimental Features (v0.1.0+)

### Request/Response Correlation

Track request-response pairs for RPC-style workflows:

```json
{
  "correlation": {
    "request_id": "550e8400-e29b-41d4-a716-446655440000",
    "in_reply_to": "parent-request-id",
    "conversation_id": "conv-2025-10-16-001",
    "expects_response": true,
    "response_timeout_ms": 300000
  }
}
```

**Implementation**: `scripts/track-correlation.sh`

### Adaptive Retry Backoff

Learn from agent behavior to optimize retry timing:

```bash
# Calculate adaptive backoff
BACKOFF_MS=$(bash scripts/adaptive-backoff.sh calculate "claude-agent" 1)

# Record attempt
bash scripts/adaptive-backoff.sh record "claude-agent" "true" "15000"
```

### Webhook Integration

Send notifications to external systems:

```yaml
webhooks:
  enabled: true
  on_message_received: "https://monitoring.example.com/aea/received"
  on_message_processed: "https://monitoring.example.com/aea/processed"
  on_message_failed: "https://monitoring.example.com/aea/failed"
```

**Implementation**: `scripts/webhook-notifier.sh`

### Partial Message Processing

Gracefully handle messages with corrupted optional fields:

```bash
# Process message with degraded data
bash scripts/partial-message-processor.sh message.json
```

### Multi-Hop Messaging

Route messages through relay agents:

```json
{
  "routing": {
    "path": ["claude-sender", "relay-firewall", "claude-recipient"],
    "hop_count": 0,
    "max_hops": 3,
    "next_hop": "relay-firewall"
  }
}
```

**Implementation**: `scripts/router.sh`

---

## Best Practices

### DO ✅

- **Check messages on every interaction** - Add to CLAUDE.md
- **Use descriptive subjects** - Makes scanning easier
- **Include comprehensive context** - What, where, how, next steps
- **Use absolute paths** - Never relative paths
- **Set appropriate priority** - Urgent only for production issues
- **Log all actions** - Maintain audit trail

### DON'T ❌

- **Include sensitive data** - No passwords, keys, credentials
- **Use relative paths** - Always use absolute paths
- **Assume synchronous responses** - May take hours or days
- **Skip logging** - Always log message processing
- **Create duplicate messages** - Check for existing first

---

## Security & Error Handling

### Security Threat Model

#### Threat 1: Message Tampering
**Risk**: Attacker modifies message content in transit
**Mitigation**:
- All messages MUST be signed with ED25519
- Signature verification REQUIRED before processing
- Signature failures → immediate rejection + audit log

#### Threat 2: Replay Attacks
**Risk**: Attacker resends old valid message
**Mitigation**:
- Idempotency deduplication (24h cache per agent per subject)
- Timestamp validation (reject if >24h old)
- Message-ID tracking prevents duplicate processing

#### Threat 3: Message Flooding / Denial of Service
**Risk**: Attacker floods agent with high-priority messages
**Mitigation**:
- Rate limiting enforced (60 msg/min default, 10 msg burst)
- Priority-based cost calculation (urgent = 3x cost)
- Backpressure responses with retry_after guidance
- Per-agent quotas in agent-config.yaml

#### Threat 4: Unauthorized Access
**Risk**: Attacker impersonates legitimate agent
**Mitigation**:
- Public key registry in `.aea/registry/known-agents.json`
- Only accept messages from registered agents
- Reject unverifiable signatures (no matching public key)
- Capability verification (check agent capabilities)

#### Threat 5: Information Disclosure
**Risk**: Sensitive data exposed in messages
**Mitigation**:
- Optional AES-256-GCM encryption for content.body
- Secrets never logged (sanitize logs)
- TTL enforcement (30 days default, then archive)
- Audit logging with access control

#### Threat 6: Code Injection via Message Content
**Risk**: Attacker injects malicious code in message body
**Mitigation**:
- JSON schema validation (strict whitelist)
- No code execution from message content
- Payload size limits (max 10MB default)
- Attachment scanning (no executable types)

#### Threat 7: Resource Exhaustion
**Risk**: Large messages exhaust storage/memory
**Mitigation**:
- Storage quota enforcement (1GB default)
- Message size limits (10MB default)
- Auto-cleanup of expired messages
- Memory usage monitoring

### Error Handling Categories

#### Category A: Validation Errors
Input validation failures that cannot be recovered.

**Handling**:
- ✅ Reject message (don't process)
- ✅ Create error report with validation details
- ✅ Log to error.log (with sanitized content)
- ✅ DO NOT retry (validation won't change)
- ✅ Mark as non-recoverable

#### Category B: Security Errors
Authentication/Authorization failures requiring investigation.

**Handling**:
- ✅ Reject message (security violation)
- ✅ Create security alert (HIGH severity)
- ✅ Log with FULL context
- ✅ Add agent to temporary blocklist (1 hour)
- ✅ Notify system admin
- ❌ DO NOT retry

#### Category C: Transient Errors
Temporary failures that may resolve with retry.

**Handling**:
- ✅ Retry with exponential backoff (1s, 2s, 4s, 8s, 16s)
- ✅ Use same message_id (idempotent)
- ✅ Stop retrying after max_retries (3 default)
- ✅ Move to failed queue if exhausted

**Backoff Formula**:
```
next_retry_ms = base_ms * (2 ^ retry_count) + jitter
```

#### Category D: Permanent Errors
Non-recoverable failures requiring manual intervention.

**Handling**:
- ✅ Move to dead letter queue
- ✅ Create detailed error report
- ✅ Alert user for manual review
- ❌ DO NOT retry
- ❌ DO NOT delete (keep for audit)

### Security Guidelines

**DO** ✅
- Verify signatures before processing
- Log all security events
- Rate limit message processing
- Sanitize sensitive data from logs
- Use absolute paths only
- Preserve failed messages for audit

**DON'T** ❌
- Include passwords, API keys, tokens
- Log sensitive data (PII, secrets)
- Disable security checks for performance
- Retry security-related failures
- Execute code from message content

### Security Levels

- **None**: Testing/local only (not recommended for production)
- **Signed**: ED25519 signatures (production minimum)
- **Encrypted**: Signatures + AES-256-GCM (cross-network sensitive data)

### Deployment Checklist

Before production deployment, verify:
- [ ] All agents have ED25519 key pairs generated
- [ ] Public keys registered in `.aea/registry/known-agents.json`
- [ ] Rate limiting configured in agent-config.yaml
- [ ] Storage quotas set and monitored
- [ ] TTL policies configured (default 30 days)
- [ ] Error handling policies tested
- [ ] Security validation enabled (signature verification mandatory)
- [ ] Logging and monitoring configured
- [ ] Audit trail preservation (security.log retention)

For complete security implementation details, see docs/aea-rules.md.

---

## Installation

### Install in Current Repository

```bash
bash scripts/install-aea.sh
```

### Install in Target Repository

```bash
bash scripts/install-aea.sh /path/to/target/repo
```

**What Gets Installed**:
- `.aea/` directory structure
- Core scripts
- Agent configuration template
- Protocol documentation
- CLAUDE.md integration instructions
- `.gitignore` file (excludes logs, temp files, processed markers)

---

## Troubleshooting

### Messages Not Detected

```bash
# Verify messages exist
ls -la .aea/message-*.json

# Check processed markers
ls -la .aea/.processed/

# Run check with debug
bash -x scripts/aea-check.sh
```

### Monitor Not Starting

```bash
# Check status
bash aea.sh monitor status

# View logs
tail -50 ~/.config/aea/monitor.log
tail -50 .aea/agent.log

# Restart
bash aea.sh monitor stop
bash aea.sh monitor start
```

### Scripts Not Executable

```bash
chmod +x scripts/*.sh
chmod +x aea.sh
```

---

## Migration Guide

### From No AEA → v0.1.0

1. Install AEA: `bash scripts/install-aea.sh`
2. Configure agent identity in `agent-config.yaml`
3. Add message checking to `CLAUDE.md`
4. Test with sample messages

### From v1.0/v2.0 → v0.1.0

1. **Update protocol_version** in existing messages to "0.1.0"
2. **Rename fields**: `from` → `sender`, `to` → `recipient`
3. **Add message_id**: Generate UUID v4 for all messages
4. **Update agent-config.yaml** with new response_policies format
5. **Test** with `bash aea.sh test`

---

## API Reference

### Message Validation

```bash
# Validate message format
jq empty message.json && echo "✓ Valid JSON"

# Check required fields
jq -e '.protocol_version, .message_id, .message_type, .sender.agent_id' message.json
```

### Marking Messages Processed

```bash
# Create processed marker
touch .aea/.processed/$(basename message.json)

# Log action
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed: $(jq -r .message_type message.json) from $(jq -r .sender.agent_id message.json)" >> .aea/agent.log
```

---

## Limitations

**Current Limitations (v0.1.0)**:
- Filesystem-only (no network transport built-in)
- Single-machine by default (multi-network requires custom relay)
- No persistent message queue (file-based only)
- Optional features require manual implementation

**Planned Improvements**:
- Redis-backed message queue
- HTTP API for network transport
- Distributed deployment support
- Cloud provider integration

---

## Support & Documentation

- **CLAUDE.md**: Integration instructions for Claude Code
- **README.md**: Quick start and system overview
- **docs/aea-rules.md**: Complete protocol rules for agents
- **agent-config.yaml**: Configuration reference
- **tests/**: Example messages and test scenarios

---

## Version History

- **v0.1.0** (2025-10-16): Pre-release consolidation. Production-ready core with optional experimental features.
- **v2.1** (deprecated): Merged into v0.1.0
- **v2.0** (deprecated): Merged into v0.1.0
- **v1.0** (deprecated): Merged into v0.1.0

---

**Last Updated**: 2025-10-16
**Protocol Version**: 0.1.0
**Status**: Pre-Release (Production-Ready Core)
