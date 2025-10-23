# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⚠️ REPOSITORY CONTEXT

**This repository uses the AEA Protocol for inter-agent communication.**

AEA is installed in the `.aea/` subdirectory. All AEA-related commands should be run with the `.aea/` prefix.

---

## Project Overview

**AEA (Agentic Economic Activity) Protocol** - Enables asynchronous, autonomous communication between Claude Code agents across multiple repositories via JSON message files.

**Current Protocol Version**: v0.1.0

**Core Capability**: Agents exchange messages via `.aea/message-*.json` files, auto-process safe operations (questions, documentation), and request approval for risky operations (code changes, deployments).

**Working Directory**: All AEA commands assume you're in the repository root unless otherwise noted.

---

## Automatic Checking

**AEA automatically checks for messages via Claude Code hooks!**

After installation, `.claude/settings.json` contains:
```json
{
  "hooks": {
    "SessionStart": {
      "command": "bash .aea/scripts/aea-check.sh",
      "enabled": true
    },
    "UserPromptSubmit": {
      "command": "bash .aea/scripts/aea-check.sh",
      "enabled": true
    },
    "Stop": {
      "command": "bash .aea/scripts/aea-check.sh",
      "enabled": true
    }
  }
}
```

**This means:**
- ✅ Messages are checked when Claude Code starts
- ✅ Messages are checked before processing user prompts
- ✅ Messages are checked after completing tasks
- ✅ No manual `/aea` needed (though it still works!)

**To disable automatic checking**, edit `.claude/settings.json` and set `"enabled": false`.

---

## Essential Commands

### Daily Operations

```bash
# Manual message check (automatic via hooks, but can still run manually)
bash .aea/scripts/aea-check.sh

# Process messages interactively
bash .aea/scripts/process-messages-iterative.sh

# Start background monitor (optional - hooks handle most cases)
bash .aea/scripts/aea-monitor.sh start

# Check monitor status
bash .aea/scripts/aea-monitor.sh status
```

### Testing & Development

```bash
# Create test message scenarios (if installed)
bash .aea/scripts/create-test-scenarios.sh simple-question
bash .aea/scripts/create-test-scenarios.sh urgent-issue
bash .aea/scripts/create-test-scenarios.sh all
```

---

## Architecture Overview

### Message Flow (The Big Picture)

```
[Sender Agent]
    ↓
Creates message-*.json → Writes to {this-repo}/.aea/
    ↓
[Your Agent] bash .aea/scripts/aea-check.sh
    ↓
Classifies message by type + priority
    ├─→ Auto-Process (safe operations)
    │   → Read code, analyze, respond
    │   → Mark processed, create response
    │
    └─→ Request Approval (risky operations)
        → Notify user with summary
        → Wait for approval
        → Execute if approved
    ↓
Response created → {source}/.aea/message-{timestamp}-from-{agent}.json
```

### Message Types & Auto-Processing Policy

| Type | Priority | Auto-Process? | Action |
|------|----------|---------------|--------|
| `question` | any | ✅ Yes | Search code → Answer → Send response |
| `update` | normal/high | ✅ Yes | Read → Acknowledge if needed |
| `issue` | low/medium | ✅ Yes | Analyze → Suggest fix → Send response |
| `issue` | high/urgent | ❌ No | Notify user → Wait for approval |
| `handoff` | any | ❌ No | Review → Request approval |
| `request` | any | ❌ No | Evaluate → Present plan → Get approval |
| `response` | any | ✅ Yes | Process → Update context |

### Key Components

**1. Message Processing Pipeline**
- `.aea/scripts/aea-check.sh` - Detects unprocessed messages
- `.aea/scripts/process-messages-iterative.sh` - Interactive processor
- `.aea/agent-config.yaml` - Response policies and agent identity
- `.aea/.processed/` - Deduplication markers

**2. Background Monitor Architecture**
- `.aea/scripts/aea-monitor.sh` - Background daemon (5 min interval)
- `~/.config/aea/projects.yaml` - Centralized multi-project configuration
- PID-based health checks with graceful failover
- Auto-registration on monitor start

**3. Message Storage**
- `.aea/message-{TIMESTAMP}-from-{SENDER}.json` - Incoming messages
- `.aea/.processed/message-*.json` - Empty marker files (idempotency)
- `.aea/agent.log` - Activity audit trail
- `~/.config/aea/monitor.log` - Daemon logs

**4. Configuration Layers**
- `.aea/agent-config.yaml` - Agent identity, response policies, safety constraints
- `.aea/PROTOCOL.md` - Protocol specification (v0.1.0)
- `.aea/prompts/check-messages.md` - Message checking prompt template

---

## Development Workflow

### On Every Interaction

```bash
# Step 1: Check for agent messages (ALWAYS DO THIS FIRST)
bash .aea/scripts/aea-check.sh

# Step 2: Process if messages found
bash .aea/scripts/process-messages-iterative.sh

# Step 3: Continue with user's request
```

### When Completing Cross-Repo Work

**Consider sending a handoff message**:

```bash
# 1. Generate timestamp
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

# 2. Create message in target repo
cat > /path/to/target/.aea/message-${TIMESTAMP}-from-your-agent-id.json << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "message_type": "handoff",
  "timestamp": "2025-10-16T10:30:00Z",
  "sender": {"agent_id": "your-agent-id"},
  "recipient": {"agent_id": "claude-target-agent"},
  "routing": {"priority": "normal"},
  "content": {
    "subject": "Integration complete",
    "body": "Created X. Use via Y. Next steps: Z."
  },
  "metadata": {
    "files_created": ["/absolute/path/to/file.ext"]
  }
}
EOF
```

**Include**:
- What was built
- How to use it
- Next steps
- References to created files (absolute paths)

### Testing Changes

```bash
# 1. Create test scenario
bash .aea/scripts/create-test-scenarios.sh simple-question

# 2. Test processing
bash .aea/scripts/aea-check.sh
bash .aea/scripts/process-messages-iterative.sh

# 3. Verify logs
tail -20 .aea/agent.log
```

---

## Important Implementation Details

### Security & Safety

**Auto-Execution Allowed** (read-only operations):
- Read files, search codebase, analyze code
- Answer technical questions, generate documentation
- Create response messages

**Require Approval** (write operations):
- Code changes, configuration modifications
- Deployment actions, database modifications
- Security-related changes

**Cryptographic Security** (optional, v0.1.0):
- ED25519 signatures for message authenticity
- AES-256-GCM encryption for sensitive content
- Keys stored in `~/.aea/{agent-id}/{repo}/{branch}/`
- Never commit private keys to repository

### Idempotency & Deduplication

**Processed markers** prevent duplicate processing:
```bash
# Mark as processed
touch ".aea/.processed/$(basename message.json)"

# Check if processed
[ -f ".aea/.processed/message-20251016T103000Z-from-claude-agent.json" ]
```

**Deduplication cache** (optional):
- SHA256 hash of message content
- 24h TTL per agent per subject
- `.aea/.dedup-cache.json`

### Message Expiration

**TTL enforcement**:
- Default: 30 days (`ttl_seconds: 2592000`)
- Max age: 24 hours for processing (`safety.max_message_age: 86400`)
- Cleanup: Manual deletion or cron-based removal of expired messages

---

## Configuration Reference

### agent-config.yaml Structure

Located at `.aea/agent-config.yaml`:

```yaml
agent:
  id: "claude-your-repo"           # Unique agent identifier
  type: "claude-sonnet-4.5"         # Agent model
  role: "Your Agent Role"           # Description
  repository: "."                   # Relative path
  expertise: ["domain1", "domain2"] # Capabilities

monitoring:
  enabled: true                     # Auto-check enabled
  check_interval: 300               # Check every 5 min
  watch_directories: ["./.aea"]     # Paths to monitor

response_policies:
  questions:
    auto_respond_when:              # Topics for auto-response
      - topic: "technical-questions"
    require_approval_when:          # Topics requiring approval
      - topic: "architecture-changes"

  issues:
    auto_analyze_when:              # Severities for auto-analysis
      - severity: "low"
      - severity: "medium"
    notify_immediately_when:        # Critical thresholds
      - severity: "urgent"

safety:
  require_approval_for:             # Operations requiring approval
    - "code_changes"
    - "deployment_actions"
  allow_auto_execution:             # Safe operations
    - "read_files"
    - "answer_questions"
  max_message_age: 86400            # Max age to process (24h)
```

---

## Common Patterns

### Reading Unprocessed Messages

```bash
# List unprocessed messages
for msg in .aea/message-*.json; do
    if [ ! -f ".aea/.processed/$(basename $msg)" ]; then
        echo "Unprocessed: $msg"
        jq '.' "$msg"
    fi
done
```

### Creating Response Messages

```bash
# Generate message ID and timestamps
MESSAGE_ID=$(cat /proc/sys/kernel/random/uuid)  # Linux
# For macOS: MESSAGE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FILE_TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

# Create response
cat > /path/to/target/.aea/message-${FILE_TIMESTAMP}-from-your-agent-id.json << EOF
{
  "protocol_version": "0.1.0",
  "message_id": "$MESSAGE_ID",
  "message_type": "response",
  "timestamp": "$CURRENT_TIME",
  "sender": {"agent_id": "your-agent-id"},
  "recipient": {"agent_id": "target-agent-id"},
  "routing": {"priority": "normal", "requires_response": false},
  "content": {
    "subject": "Re: Your question",
    "body": "Detailed response here..."
  },
  "metadata": {
    "in_reply_to": "original-message-id"
  }
}
EOF
```

### Logging Actions

```bash
# Log message processing
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed: ${message_type} from ${sender}" >> .aea/agent.log

# View recent activity
tail -20 .aea/agent.log
```

---

## Troubleshooting

### Messages Not Detected

```bash
# Verify messages exist
ls -la .aea/message-*.json

# Check processed markers
ls -la .aea/.processed/

# Run check with debug output
bash -x .aea/scripts/aea-check.sh
```

### Monitor Issues

```bash
# Check status
bash .aea/scripts/aea-monitor.sh status

# View logs
tail -50 ~/.config/aea/monitor.log
tail -50 .aea/agent.log

# Kill stale monitors
pkill -f aea-monitor.sh

# Restart fresh
bash .aea/scripts/aea-monitor.sh stop
bash .aea/scripts/aea-monitor.sh start
```

### Scripts Not Executable

```bash
chmod +x .aea/scripts/*.sh
```

---

## Key Files

- **.aea/agent-config.yaml** - Agent configuration and response policies
- **.aea/PROTOCOL.md** - Protocol specification (v0.1.0)
- **.aea/scripts/aea-check.sh** - Primary message checking script
- **.aea/scripts/aea-monitor.sh** - Background monitoring daemon
- **.aea/scripts/process-messages-iterative.sh** - Interactive message processor
- **.aea/docs/aea-rules.md** - Complete protocol rules for agent integration

---

## External Dependencies

- `bash` (4.0+)
- `jq` - JSON parsing
- `openssl` - Cryptographic signatures (optional, v0.1.0)
- Standard utilities: `date`, `touch`, `mkdir`, `cat`, `grep`

---

## About This Installation

The AEA protocol has been installed in this repository's `.aea/` directory. All protocol files, scripts, and documentation are contained within that subdirectory.

For information about developing the AEA protocol itself, see the source repository at the location where `install-aea.sh` was run from.

**Remember**: Always prefix AEA commands with `.aea/` when working in this repository.
