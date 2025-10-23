#!/usr/bin/env bash
#
# AEA (Asynchronous Agent-to-Agent) Communication System Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/your-org/aea/main/install.sh | bash
#   OR
#   ./install-aea.sh [target_directory]
#
# Examples:
#   ./install-aea.sh                    # Install in current directory
#   ./install-aea.sh ~/my/project       # Install in specified directory
#   curl https://... | bash             # Install from web
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine AEA source directory (before changing directories!)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEA_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# Determine installation directory
if [ -n "$1" ]; then
    INSTALL_DIR="$1"

    # Validate installation directory for security
    case "$INSTALL_DIR" in
        *..*)
            log_error "Installation path contains '..' (path traversal attempt blocked)"
            exit 1
            ;;
        *$'\n'*|*$'\0'*)
            log_error "Installation path contains invalid characters"
            exit 1
            ;;
    esac

    log_info "Installing AEA in specified directory: $INSTALL_DIR"
else
    INSTALL_DIR="$(pwd)"
    log_info "Installing AEA in current directory: $INSTALL_DIR"
fi

# Create directory if it doesn't exist
if ! mkdir -p "$INSTALL_DIR"; then
    log_error "Failed to create installation directory: $INSTALL_DIR"
    exit 1
fi

if ! cd "$INSTALL_DIR"; then
    log_error "Failed to change to installation directory: $INSTALL_DIR"
    exit 1
fi

log_info "Starting AEA installation..."

# ==============================================================================
# 1. Create .aea directory structure
# ==============================================================================

log_info "Creating .aea directory structure..."

mkdir -p .aea/{docs,prompts,scripts,.processed}

# ==============================================================================
# 2. Create agent-config.yaml
# ==============================================================================

log_info "Creating agent-config.yaml..."

cat > .aea/agent-config.yaml << 'EOF'
# AEA Agent Configuration
# This file defines how this agent processes inter-agent messages

agent:
  id: "claude-$(basename $(pwd))"
  name: "Claude Code Agent"
  description: "Autonomous development agent for $(basename $(pwd))"
  capabilities:
    - code_analysis
    - documentation
    - testing
    - debugging
    - performance_optimization

# Message Processing Policies
response_policy:
  # Questions: Auto-respond with technical answers
  question:
    auto_respond: true
    approval_required: false
    actions:
      - search_codebase
      - analyze_code
      - provide_answer
      - send_response

  # Updates: Acknowledge or summarize based on priority
  update:
    normal:
      auto_respond: true
      approval_required: false
      actions:
        - read_update
        - acknowledge_if_requested
    high:
      auto_respond: true
      approval_required: false
      actions:
        - read_update
        - summarize_for_user
    urgent:
      auto_respond: true
      approval_required: false
      actions:
        - read_update
        - notify_user
        - summarize_key_points

  # Issues: Auto-analyze low/medium, request approval for high/urgent
  issue:
    low:
      auto_respond: true
      approval_required: false
      actions:
        - analyze_issue
        - suggest_fix
        - send_response
    medium:
      auto_respond: true
      approval_required: false
      actions:
        - analyze_issue
        - suggest_fix
        - send_response
    high:
      auto_respond: false
      approval_required: true
      actions:
        - analyze_issue
        - notify_user
        - wait_for_approval
    urgent:
      auto_respond: false
      approval_required: true
      actions:
        - analyze_issue
        - notify_user
        - wait_for_approval

  # Handoffs: Always review with user
  handoff:
    auto_respond: false
    approval_required: true
    actions:
      - summarize_handoff
      - notify_user
      - wait_for_approval

  # Requests: Evaluate and respond with plan
  request:
    auto_respond: true
    approval_required: false
    actions:
      - analyze_request
      - create_plan
      - send_response

# Auto-safe operations (no approval needed)
auto_safe_operations:
  - read_files
  - search_codebase
  - analyze_code
  - generate_documentation
  - answer_questions
  - create_response_messages
  - log_actions

# Operations requiring approval
approval_required_operations:
  - modify_code
  - change_configuration
  - deploy_changes
  - delete_files
  - security_changes
  - database_operations

# Monitoring
monitoring:
  enabled: true
  log_file: ".aea/agent.log"
  check_interval: 60  # seconds
EOF

log_success "Created agent-config.yaml"

# ==============================================================================
# 3. Create docs/aea-rules.md (Protocol Documentation)
# ==============================================================================

log_info "Creating docs/aea-rules.md..."

cat > .aea/docs/aea-rules.md << 'EOF'
# AEA Inter-Agent Communication Protocol

**Version:** 1.0
**Last Updated:** 2025-10-14

## Overview

The AEA (Asynchronous Agent-to-Agent) protocol enables autonomous Claude Code agents across different repositories to communicate, coordinate, and collaborate without requiring constant user intervention.

## Core Principles

1. **Asynchronous by Design**: Agents check for messages periodically, not in real-time
2. **File-Based Communication**: Messages are JSON files in `.aea/` directories
3. **Policy-Driven Responses**: Each agent has configurable response policies
4. **Safe by Default**: Autonomous for reads/analysis, approval required for modifications
5. **Audit Trail**: All actions logged to `.aea/agent.log`

## Message Format

All messages are JSON files with this structure:

```json
{
  "protocol_version": "1.0",
  "message_id": "uuid",
  "message_type": "question|update|issue|handoff|request",
  "timestamp": "ISO8601",
  "priority": "low|normal|high|urgent",
  "requires_response": true,
  "from": {
    "agent_id": "claude-repo-name",
    "repo_path": "/absolute/path",
    "user": "username"
  },
  "to": {
    "agent_id": "claude-target-repo",
    "repo_path": "/absolute/path"
  },
  "message": {
    "subject": "Brief subject line",
    "body": "Detailed message content",
    "context": {},
    "attachments": []
  },
  "metadata": {
    "conversation_id": "uuid",
    "reply_to": "message_id",
    "tags": []
  }
}
```

## Message Types

### 1. `question`
Ask technical questions about code, architecture, or implementation.

**Example:**
```json
{
  "message_type": "question",
  "priority": "normal",
  "message": {
    "subject": "Connection pool sizing for high throughput?",
    "question": "What pool_size should we use for 10k updates/sec?",
    "context": {
      "current_throughput": "10000 updates/sec",
      "batch_size": 100
    }
  }
}
```

**Auto-Response:** ✅ Yes (searches codebase, analyzes, provides answer)

### 2. `update`
Inform about changes, progress, or status updates.

**Example:**
```json
{
  "message_type": "update",
  "priority": "normal",
  "requires_response": false,
  "message": {
    "subject": "Deployed v2.1.0 to production",
    "body": "New version includes batch optimization...",
    "changes": ["batch_size: 50 -> 100", "pool_size: 10 -> 25"]
  }
}
```

**Auto-Response:** ✅ Acknowledges if `requires_response: true`

### 3. `issue`
Report bugs, problems, or concerns.

**Example:**
```json
{
  "message_type": "issue",
  "priority": "high",
  "message": {
    "subject": "Memory leak in batch processing",
    "issue_description": "Memory grows 100MB/hour under load",
    "reproduction_steps": ["Start server", "Send 10k updates", "Monitor memory"],
    "impact": "Production stability at risk"
  }
}
```

**Auto-Response:**
- Low/Medium: ✅ Analyzes and suggests fix
- High/Urgent: ❌ Notifies user, waits for approval

### 4. `handoff`
Transfer integration work affecting multiple repos.

**Example:**
```json
{
  "message_type": "handoff",
  "priority": "normal",
  "message": {
    "subject": "Batch API integration complete",
    "handoff_details": "Implemented batch endpoints, ready for client integration",
    "next_steps": ["Update client to use batch API", "Test end-to-end"],
    "documentation": "See docs/batch-api.md"
  }
}
```

**Auto-Response:** ❌ Always requires user review

### 5. `request`
Request changes, features, or actions.

**Example:**
```json
{
  "message_type": "request",
  "priority": "normal",
  "message": {
    "subject": "Add connection retry logic",
    "request_details": "Need exponential backoff for failed connections",
    "rationale": "Improve resilience during Redis restarts",
    "acceptance_criteria": ["3 retries", "Exponential backoff", "Logging"]
  }
}
```

**Auto-Response:** ✅ Analyzes and responds with implementation plan

## File Naming Convention

Messages must follow this naming pattern:

```
message-{timestamp}-from-{agent_id}[-{optional_descriptor}].json
```

**Examples:**
- `message-20251014T054200Z-from-claude-agent-1.json`
- `message-20251014T161000Z-from-claude-agent-1-test.json`

**Timestamp Format:** ISO8601 compact (`YYYYMMDDTHHMMSSZz`)

## Message Processing Workflow

### 1. **Discovery**
```bash
ls -1t .aea/message-*.json 2>/dev/null
```

### 2. **Check Processed Status**
```bash
for msg in .aea/message-*.json; do
    if [ ! -f ".aea/.processed/$(basename $msg)" ]; then
        echo "Unprocessed: $msg"
    fi
done
```

### 3. **Read and Parse**
```bash
msg_content=$(cat "$msg")
msg_type=$(echo "$msg_content" | jq -r '.message_type')
priority=$(echo "$msg_content" | jq -r '.priority')
```

### 4. **Apply Policy**
Load policy from `.aea/agent-config.yaml` and determine action based on message type and priority.

### 5. **Execute Action**
Perform autonomous actions (safe operations) or request user approval (risky operations).

### 6. **Mark as Processed**
```bash
touch ".aea/.processed/$(basename $msg)"
```

### 7. **Log Action**
```bash
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Processed: $msg -> Action taken" >> .aea/agent.log
```

## Sending Messages

Use the provided script:

```bash
.aea/scripts/aea-send.sh \
  --to claude-target-repo \
  --to-path /path/to/target/repo \
  --type question \
  --priority normal \
  --subject "Your question" \
  --message "Detailed message body"
```

Or create manually:

\`\`\`bash
cat > /target/repo/.aea/message-\$(date -u +%Y%m%dT%H%M%SZ)-from-claude-myrepo.json << 'HEREDOC'
{
  "protocol_version": "1.0",
  "message_type": "question",
  ...
}
HEREDOC
\`\`\`

## Automated Checking

### Periodic Check (Every Interaction)
Add to `CLAUDE.md`:

```markdown
**CRITICAL: Check for AEA messages on EVERY interaction:**

```bash
bash .aea/scripts/aea-check.sh || cat .aea/prompts/check-messages.md
```

### Background Monitor
Start persistent monitoring:

```bash
.aea/scripts/aea-monitor.sh start
```

Stop monitoring:

```bash
.aea/scripts/aea-monitor.sh stop
```

## Security Considerations

1. **Path Validation**: Always use absolute paths, validate they exist
2. **Input Sanitization**: Validate all JSON fields before processing
3. **Approval Gates**: Require approval for destructive operations
4. **Audit Logging**: Log all message processing to `.aea/agent.log`
5. **No Secret Transmission**: Never include credentials in messages

## Best Practices

1. **Use Descriptive Subjects**: Make it easy to scan messages
2. **Include Context**: Provide enough information for autonomous processing
3. **Set Appropriate Priority**: Use `urgent` sparingly
4. **Tag Related Messages**: Use `conversation_id` for threaded discussions
5. **Clean Up Old Messages**: Archive processed messages periodically

## Troubleshooting

### Messages Not Being Processed

```bash
# Check if messages exist
ls -1 .aea/message-*.json

# Check if they're marked as processed
ls -1 .aea/.processed/

# Check logs
tail -50 .aea/agent.log

# Manually trigger check
bash .aea/scripts/aea-check.sh
```

### Response Not Received

```bash
# Check if response was created in target repo
ls -1 /target/repo/.aea/message-*-from-$(basename $(pwd)).json

# Check if target repo processed it
ls -1 /target/repo/.aea/.processed/
```

### Permission Issues

```bash
# Ensure scripts are executable
chmod +x .aea/scripts/*.sh

# Ensure directories are writable
chmod -R u+w .aea/
```

## Examples

See `.aea/prompts/` for example templates and `.aea/README.md` for quick start guide.

## Version History

- **1.0** (2025-10-14): Initial protocol specification
EOF

log_success "Created docs/aea-rules.md"

# Copy PROTOCOL.md from source if available
if [ -f "$AEA_SOURCE_DIR/PROTOCOL.md" ]; then
    log_info "Copying PROTOCOL.md..."
    cp "$AEA_SOURCE_DIR/PROTOCOL.md" .aea/PROTOCOL.md
    log_success "Copied PROTOCOL.md"
else
    log_warning "PROTOCOL.md not found in source, skipping..."
fi

# ==============================================================================
# 4. Create README.md
# ==============================================================================

log_info "Creating README.md..."

cat > .aea/README.md << 'EOF'
# AEA Inter-Agent Communication

**Asynchronous Agent-to-Agent communication system for Claude Code**

## Quick Start

### 1. Check for Messages

```bash
# Manual check
bash .aea/scripts/aea-check.sh

# Or use slash command in Claude
/aea
```

### 2. Send a Message

```bash
.aea/scripts/aea-send.sh \
  --to claude-other-repo \
  --to-path /path/to/other/repo \
  --type question \
  --priority normal \
  --subject "Your question here" \
  --message "Detailed message body"
```

### 3. Start Background Monitoring

```bash
.aea/scripts/aea-monitor.sh start
```

## Message Types

| Type | Description | Auto-Response |
|------|-------------|---------------|
| `question` | Technical questions | ✅ Yes |
| `update` | Status updates | ✅ Acknowledges if requested |
| `issue` | Bug reports | ⚠️ Depends on priority |
| `handoff` | Integration handoffs | ❌ Requires approval |
| `request` | Feature requests | ✅ Responds with plan |

## Files

- **agent-config.yaml**: Response policies and configuration
- **docs/aea-rules.md**: Complete protocol documentation
- **prompts/check-messages.md**: Auto-check prompt template
- **scripts/aea-check.sh**: Message checking script
- **scripts/aea-send.sh**: Message sending script
- **scripts/aea-monitor.sh**: Background monitoring daemon
- **agent.log**: Processing audit trail
- **.processed/**: Tracks processed messages

## Configuration

Edit `.aea/agent-config.yaml` to customize:

- Agent ID and capabilities
- Response policies per message type
- Auto-safe vs. approval-required operations
- Monitoring intervals

## Documentation

See `docs/aea-rules.md` for complete protocol specification and examples.

## Integration

This repository is integrated with:

- `other-repo`: Redis connection pooling and batch operations

Check `.aea/agent.log` for recent activity.
EOF

log_success "Created README.md"

# ==============================================================================
# 5. Create check-messages.md prompt
# ==============================================================================

log_info "Creating prompts/check-messages.md..."

cat > .aea/prompts/check-messages.md << 'EOF'
# AEA Inter-Agent Communication Check

Check for new inter-agent messages and process them autonomously according to agent-config.yaml policy.

## Instructions

You are the autonomous agent `claude-$(basename $(pwd))`.

**Task:** Check and process AEA messages

**Steps:**

1. **Discover messages:**
   ```bash
   ls -1t .aea/message-*.json 2>/dev/null
   ```

2. **Check which are unprocessed:**
   ```bash
   for msg in .aea/message-*.json; do
       if [ -f "$msg" ] && [ ! -f ".aea/.processed/$(basename $msg)" ]; then
           echo "📬 Unprocessed: $(basename $msg)"
       fi
   done
   ```

3. **For each unprocessed message:**
   - Read the message JSON
   - Extract: `message_type`, `priority`, `requires_response`, `from.agent_id`
   - Load policy from `.aea/agent-config.yaml`
   - Apply response policy

4. **Auto-safe actions** (no approval needed):
   - Read files
   - Search codebase
   - Analyze code
   - Answer technical questions
   - Generate documentation
   - Create response messages

5. **Require approval** (wait for user):
   - Code changes
   - Configuration modifications
   - Deployment actions
   - Security-related changes

6. **For each processed message:**
   - Mark as processed: `touch .aea/.processed/$(basename $msg)`
   - Log action to `.aea/agent.log`
   - If response needed, create: `.aea/message-{timestamp}-from-claude-$(basename $(pwd)).json` in target repo

7. **Report summary:**
   - Total messages found
   - Messages processed
   - Responses sent
   - Any requiring approval

## Response Policy Summary

(Load from `.aea/agent-config.yaml` for complete policies)

| Message Type | Priority | Action |
|--------------|----------|--------|
| `question` | any | ✅ Auto-respond |
| `update` | normal | ✅ Auto-acknowledge |
| `update` | high/urgent | ✅ Summarize for user |
| `issue` | low/medium | ✅ Auto-analyze |
| `issue` | high/urgent | ❌ Request approval |
| `handoff` | any | ❌ Request approval |
| `request` | any | ✅ Respond with plan |

## Important

- **Be autonomous** for safe operations
- **Request approval** for risky operations
- **Always log** actions to `.aea/agent.log`
- **Use absolute paths** in all file operations
- **Follow AEA protocol** from `.aea/docs/aea-rules.md`
EOF

log_success "Created check-messages.md"

# ==============================================================================
# 6. Create aea-check.sh script
# ==============================================================================

log_info "Creating scripts/aea-check.sh..."

cat > .aea/scripts/aea-check.sh << 'EOF'
#!/usr/bin/env bash
#
# AEA Message Checker
# Discovers and lists unprocessed inter-agent messages
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEA_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$AEA_DIR")"

cd "$PROJECT_ROOT"

# Ensure .processed directory exists
mkdir -p .aea/.processed

# Find all message files
MESSAGES=($(ls -1t .aea/message-*.json 2>/dev/null || true))

if [ ${#MESSAGES[@]} -eq 0 ]; then
    echo "✅ No messages found"
    exit 0
fi

# Check for unprocessed messages
UNPROCESSED=()
for msg in "${MESSAGES[@]}"; do
    basename_msg="$(basename "$msg")"
    if [ ! -f ".aea/.processed/$basename_msg" ]; then
        UNPROCESSED+=("$msg")
    fi
done

if [ ${#UNPROCESSED[@]} -eq 0 ]; then
    echo "✅ All ${#MESSAGES[@]} message(s) processed"
    exit 0
fi

# Report unprocessed messages
echo "📬 Found ${#UNPROCESSED[@]} unprocessed message(s):"
echo ""

for msg in "${UNPROCESSED[@]}"; do
    echo "  📄 $(basename "$msg")"

    # Extract key info using jq if available
    if command -v jq &> /dev/null; then
        msg_type=$(jq -r '.message_type // "unknown"' "$msg" 2>/dev/null || echo "unknown")
        priority=$(jq -r '.priority // "normal"' "$msg" 2>/dev/null || echo "normal")
        from=$(jq -r '.from.agent_id // "unknown"' "$msg" 2>/dev/null || echo "unknown")
        subject=$(jq -r '.message.subject // "No subject"' "$msg" 2>/dev/null || echo "No subject")

        echo "     Type: $msg_type | Priority: $priority | From: $from"
        echo "     Subject: $subject"
    fi
    echo ""
done

# Prompt Claude to process
echo "💡 Trigger processing with: /aea"
echo "   Or read manually: cat $msg"

exit 1  # Exit with error to indicate unprocessed messages exist
EOF

chmod +x .aea/scripts/aea-check.sh

log_success "Created aea-check.sh"

# ==============================================================================
# 7. Copy new scripts (registry, send, auto-processor)
# ==============================================================================

log_info "Copying AEA scripts..."

# Copy aea-registry.sh
if [ -f "$AEA_SOURCE_DIR/scripts/aea-registry.sh" ]; then
    cp "$AEA_SOURCE_DIR/scripts/aea-registry.sh" .aea/scripts/
    chmod +x .aea/scripts/aea-registry.sh
    log_success "Copied aea-registry.sh"
else
    log_warning "aea-registry.sh not found in source, skipping"
fi

# Copy aea-send.sh (new version with registry support)
if [ -f "$AEA_SOURCE_DIR/scripts/aea-send.sh" ]; then
    cp "$AEA_SOURCE_DIR/scripts/aea-send.sh" .aea/scripts/
    chmod +x .aea/scripts/aea-send.sh
    log_success "Copied aea-send.sh"
else
    log_warning "aea-send.sh not found, creating fallback version..."
    cat > .aea/scripts/aea-send.sh << 'EOF'
#!/usr/bin/env bash
#
# AEA Message Sender
# Creates and sends inter-agent messages
#
# Usage:
#   aea-send.sh --to claude-target --to-path /path --type question --subject "..." --message "..."
#

set -e

# Default values
MESSAGE_TYPE="question"
PRIORITY="normal"
REQUIRES_RESPONSE="true"
TO_AGENT=""
TO_PATH=""
SUBJECT=""
MESSAGE=""
CONTEXT="{}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --to)
            TO_AGENT="$2"
            shift 2
            ;;
        --to-path)
            TO_PATH="$2"
            shift 2
            ;;
        --type)
            MESSAGE_TYPE="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --subject)
            SUBJECT="$2"
            shift 2
            ;;
        --message)
            MESSAGE="$2"
            shift 2
            ;;
        --requires-response)
            REQUIRES_RESPONSE="$2"
            shift 2
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$TO_AGENT" ] || [ -z "$TO_PATH" ] || [ -z "$SUBJECT" ] || [ -z "$MESSAGE" ]; then
    echo "Error: Missing required parameters"
    echo ""
    echo "Usage:"
    echo "  $0 --to <agent_id> --to-path <path> --subject <subject> --message <message> [options]"
    echo ""
    echo "Required:"
    echo "  --to              Target agent ID"
    echo "  --to-path         Target repository path"
    echo "  --subject         Message subject"
    echo "  --message         Message body"
    echo ""
    echo "Optional:"
    echo "  --type            Message type (default: question)"
    echo "  --priority        Priority: low|normal|high|urgent (default: normal)"
    echo "  --requires-response  true|false (default: true)"
    echo "  --context         JSON context object (default: {})"
    exit 1
fi

# Validate target path exists
if [ ! -d "$TO_PATH" ]; then
    echo "Error: Target path does not exist: $TO_PATH"
    exit 1
fi

if [ ! -d "$TO_PATH/.aea" ]; then
    echo "Error: Target path does not have .aea directory: $TO_PATH/.aea"
    exit 1
fi

# Get current repo info
CURRENT_DIR="$(pwd)"
FROM_AGENT="claude-$(basename "$CURRENT_DIR")"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
MESSAGE_ID="$(uuidgen 2>/dev/null || echo "msg-$TIMESTAMP-$$")"

# Create message file
MESSAGE_FILE="$TO_PATH/.aea/message-$TIMESTAMP-from-$FROM_AGENT.json"

cat > "$MESSAGE_FILE" << EOFMSG
{
  "protocol_version": "1.0",
  "message_id": "$MESSAGE_ID",
  "message_type": "$MESSAGE_TYPE",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "priority": "$PRIORITY",
  "requires_response": $REQUIRES_RESPONSE,
  "from": {
    "agent_id": "$FROM_AGENT",
    "repo_path": "$CURRENT_DIR",
    "user": "$USER"
  },
  "to": {
    "agent_id": "$TO_AGENT",
    "repo_path": "$TO_PATH"
  },
  "message": {
    "subject": "$SUBJECT",
    "body": "$MESSAGE",
    "context": $CONTEXT
  },
  "metadata": {
    "conversation_id": "$MESSAGE_ID",
    "tags": []
  }
}
EOFMSG

echo "✅ Message sent: $MESSAGE_FILE"
echo ""
echo "   From: $FROM_AGENT"
echo "   To: $TO_AGENT"
echo "   Type: $MESSAGE_TYPE"
echo "   Priority: $PRIORITY"
echo "   Subject: $SUBJECT"
echo ""
echo "The target agent will process this message on their next check."
EOF

chmod +x .aea/scripts/aea-send.sh

log_success "Created aea-send.sh"
fi

# Copy aea-auto-processor.sh (autonomous message processor)
if [ -f "$AEA_SOURCE_DIR/scripts/aea-auto-processor.sh" ]; then
    cp "$AEA_SOURCE_DIR/scripts/aea-auto-processor.sh" .aea/scripts/
    chmod +x .aea/scripts/aea-auto-processor.sh
    log_success "Copied aea-auto-processor.sh"
else
    log_warning "aea-auto-processor.sh not found in source, autonomous processing not available"
fi

# ==============================================================================
# 7b. Initialize registry and auto-register current repo
# ==============================================================================

log_info "Setting up agent registry..."

# Initialize registry if aea-registry.sh exists
if [ -f ".aea/scripts/aea-registry.sh" ]; then
    # Initialize registry
    bash .aea/scripts/aea-registry.sh init 2>/dev/null || true

    # Auto-register current repo
    log_info "Auto-registering current repository..."
    bash .aea/scripts/aea-registry.sh register-current 2>/dev/null || {
        log_warning "Could not auto-register repository"
        log_info "You can manually register with: bash .aea/scripts/aea-registry.sh register-current"
    }
else
    log_warning "aea-registry.sh not available, skipping registry setup"
fi

# ==============================================================================
# 8. Create aea-monitor.sh background daemon
# ==============================================================================

log_info "Creating scripts/aea-monitor.sh..."

cat > .aea/scripts/aea-monitor.sh << 'EOF'
#!/usr/bin/env bash
#
# AEA Background Monitor
# Periodically checks for new messages and logs to agent.log
#
# Usage:
#   aea-monitor.sh start   # Start monitoring in background
#   aea-monitor.sh stop    # Stop monitoring
#   aea-monitor.sh status  # Check if running
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AEA_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$AEA_DIR")"
PIDFILE="$AEA_DIR/monitor.pid"
LOGFILE="$AEA_DIR/agent.log"
CHECK_INTERVAL=60  # seconds

cd "$PROJECT_ROOT"

start_monitor() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "❌ Monitor already running (PID: $PID)"
            exit 1
        else
            rm "$PIDFILE"
        fi
    fi

    echo "🚀 Starting AEA monitor (checking every ${CHECK_INTERVAL}s)..."

    nohup bash -c "
        while true; do
            timestamp=\$(date -u +%Y-%m-%dT%H:%M:%SZ)

            # Check for unprocessed messages
            unprocessed=\$(for msg in .aea/message-*.json 2>/dev/null; do
                [ -f \"\$msg\" ] || continue
                basename_msg=\$(basename \"\$msg\")
                if [ ! -f \".aea/.processed/\$basename_msg\" ]; then
                    echo \"\$basename_msg\"
                fi
            done)

            if [ -n \"\$unprocessed\" ]; then
                echo \"[\$timestamp] 📬 Unprocessed messages detected:\" >> \"$LOGFILE\"
                echo \"\$unprocessed\" | while read msg; do
                    echo \"[\$timestamp]    - \$msg\" >> \"$LOGFILE\"
                done
            fi

            sleep $CHECK_INTERVAL
        done
    " > /dev/null 2>&1 &

    echo $! > "$PIDFILE"
    echo "✅ Monitor started (PID: $(cat "$PIDFILE"))"
    echo "📝 Logs: $LOGFILE"
}

stop_monitor() {
    if [ ! -f "$PIDFILE" ]; then
        echo "❌ Monitor not running"
        exit 1
    fi

    PID=$(cat "$PIDFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID"
        rm "$PIDFILE"
        echo "✅ Monitor stopped (PID: $PID)"
    else
        rm "$PIDFILE"
        echo "❌ Monitor not running (stale PID file removed)"
    fi
}

status_monitor() {
    if [ ! -f "$PIDFILE" ]; then
        echo "❌ Monitor not running"
        exit 1
    fi

    PID=$(cat "$PIDFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "✅ Monitor running (PID: $PID)"
        echo "📝 Logs: $LOGFILE"
        echo "🔄 Check interval: ${CHECK_INTERVAL}s"
        exit 0
    else
        rm "$PIDFILE"
        echo "❌ Monitor not running (stale PID file removed)"
        exit 1
    fi
}

case "${1:-}" in
    start)
        start_monitor
        ;;
    stop)
        stop_monitor
        ;;
    status)
        status_monitor
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
EOF

chmod +x .aea/scripts/aea-monitor.sh

log_success "Created aea-monitor.sh"

# ==============================================================================
# 9. Create initial agent.log
# ==============================================================================

log_info "Creating agent.log..."

cat > .aea/agent.log << EOF
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] AEA communication system initialized
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Agent ID: claude-$(basename "$INSTALL_DIR")
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Repository: $INSTALL_DIR
[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Ready to process inter-agent messages
EOF

log_success "Created agent.log"

# ==============================================================================
# 10. Create or update .claude/commands/aea.md
# ==============================================================================

log_info "Creating .claude/commands/aea.md..."

mkdir -p .claude/commands

cat > .claude/commands/aea.md << 'EOF'
# AEA Inter-Agent Communication Check

Check for new inter-agent messages and process them autonomously according to agent-config.yaml policy.

## Instructions

You are the autonomous agent `claude-$(basename $(pwd))` (Redis Orderbook Module Developer).

**Task:** Check and process AEA messages

**Steps:**

1. **Discover messages:**
   ```bash
   ls -1t .aea/message-*.json 2>/dev/null
   ```

2. **Check which are unprocessed:**
   ```bash
   for msg in .aea/message-*.json; do
       if [ -f "$msg" ] && [ ! -f ".aea/.processed/$(basename $msg)" ]; then
           echo "📬 Unprocessed: $(basename $msg)"
       fi
   done
   ```

3. **For each unprocessed message:**
   - Read the message JSON
   - Extract: `message_type`, `priority`, `requires_response`, `from.agent_id`
   - Load policy from `.aea/agent-config.yaml`
   - Apply response policy:

**Response Policies (from agent-config.yaml):**

| Message Type | Priority | Action |
|--------------|----------|--------|
| `question` | any | ✅ **Auto-respond**: Search codebase → Answer → Send response |
| `update` | normal | ✅ **Auto-acknowledge**: Read → Acknowledge if `requires_response: true` |
| `update` | high/urgent | ✅ **Summarize**: Read → Inform user with key points |
| `issue` | low/medium | ✅ **Auto-analyze**: Analyze → Suggest fix → Send response |
| `issue` | high/urgent | ❌ **Notify user**: Request approval before acting |
| `handoff` | any | ⚠️ **Review**: Summarize → Request user approval |
| `request` | any | ⚠️ **Evaluate**: Analyze → Respond with plan |

4. **Auto-safe actions** (no approval needed):
   - Read files
   - Search codebase
   - Analyze code
   - Answer technical questions
   - Generate documentation
   - Create response messages

5. **Require approval** (wait for user):
   - Code changes
   - Configuration modifications
   - Deployment actions
   - Security-related changes

6. **For each processed message:**
   - Mark as processed: `touch .aea/.processed/$(basename $msg)`
   - Log action to `.aea/agent.log`
   - If response needed, create: `.aea/message-{timestamp}-from-claude-$(basename $(pwd)).json` in target repo

7. **Report summary:**
   - Total messages found
   - Messages processed
   - Responses sent
   - Any requiring approval

## Example Processing

**Question message:**
```json
{
  "message_type": "question",
  "from": {"agent_id": "claude-agent-1"},
  "message": {
    "subject": "Batch size for 50k updates/sec?",
    "question": "What batch_size should we use?"
  }
}
```

**Your action:**
1. Search CLAUDE.md for performance guidance
2. Review batch configuration docs
3. Generate technical answer with code references
4. Create response message in the sender's .aea/ directory
5. Mark original as processed

**Issue message (high priority):**
```json
{
  "message_type": "issue",
  "priority": "high",
  "message": {
    "issue_description": "Memory leak in batch processing"
  }
}
```

**Your action:**
1. Inform user: "🚨 High priority issue reported by claude-agent-1"
2. Summarize issue
3. Ask: "Should I analyze and propose a fix?"
4. Wait for approval

## Important

- **Be autonomous** for safe operations
- **Request approval** for risky operations
- **Always log** actions to `.aea/agent.log`
- **Use absolute paths** in all file operations
- **Follow AEA protocol** from `.aea/docs/aea-rules.md`
EOF

log_success "Created .claude/commands/aea.md"

# ==============================================================================
# 10b. Add AEA Hooks to .claude/settings.json
# ==============================================================================

log_info "Configuring automatic AEA message checking via hooks..."

SETTINGS_FILE=".claude/settings.json"
TEMP_FILE=".claude/settings.json.tmp.$$"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_warning "jq is not installed - skipping automatic hook setup"
    log_info "Install jq (apt-get install jq or brew install jq) and re-run to enable automatic checking"
    log_info "You can manually add hooks to .claude/settings.json (see HOOK_IMPLEMENTATION_PLAN.md)"
else
    if [ ! -f "$SETTINGS_FILE" ]; then
        # File doesn't exist - create new one with our hooks
        log_info "Creating .claude/settings.json with AEA hooks..."
        cat > "$SETTINGS_FILE" << 'EOFSETTINGS'
{
  "hooks": {
    "SessionStart": {
      "command": "bash .aea/scripts/aea-auto-processor.sh",
      "description": "Auto-process AEA messages on session start",
      "enabled": true
    },
    "Stop": {
      "command": "bash .aea/scripts/aea-auto-processor.sh",
      "description": "Auto-process AEA messages after task completion",
      "enabled": true
    }
  }
}
EOFSETTINGS
        log_success "Created .claude/settings.json with AEA hooks"
    else
        # File exists - merge intelligently
        log_info ".claude/settings.json exists, checking for AEA hooks..."

        # Validate existing JSON
        if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
            log_error "Existing .claude/settings.json is not valid JSON"
            log_warning "Please fix the JSON manually, then re-run installation"
            log_info "Skipping hook installation..."
        else
            # Check if hooks section exists
            if ! jq -e '.hooks' "$SETTINGS_FILE" >/dev/null 2>&1; then
                # No hooks section - add entire hooks object
                log_info "Adding hooks section to existing settings..."
                jq '. + {
                  "hooks": {
                    "SessionStart": {
                      "command": "bash .aea/scripts/aea-auto-processor.sh",
                      "description": "Auto-process AEA messages on session start",
                      "enabled": true
                    },
                    "Stop": {
                      "command": "bash .aea/scripts/aea-auto-processor.sh",
                      "description": "Auto-process AEA messages after task completion",
                      "enabled": true
                    }
                  }
                }' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
                log_success "Added AEA hooks to .claude/settings.json"
            else
                # Hooks section exists - add individual hooks if missing
                HOOKS_ADDED=0

                # Check SessionStart
                if jq -e '.hooks.SessionStart.command | contains("aea")' "$SETTINGS_FILE" >/dev/null 2>&1; then
                    log_info "SessionStart hook already configured"
                else
                    log_info "Adding SessionStart hook..."
                    jq '.hooks.SessionStart = {
                      "command": "bash .aea/scripts/aea-auto-processor.sh",
                      "description": "Auto-process AEA messages on session start",
                      "enabled": true
                    }' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
                    HOOKS_ADDED=$((HOOKS_ADDED + 1))
                fi

                # Check Stop
                if jq -e '.hooks.Stop.command | contains("aea")' "$SETTINGS_FILE" >/dev/null 2>&1; then
                    log_info "Stop hook already configured"
                else
                    log_info "Adding Stop hook..."
                    jq '.hooks.Stop = {
                      "command": "bash .aea/scripts/aea-auto-processor.sh",
                      "description": "Auto-process AEA messages after task completion",
                      "enabled": true
                    }' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
                    HOOKS_ADDED=$((HOOKS_ADDED + 1))
                fi

                if [ $HOOKS_ADDED -eq 0 ]; then
                    log_success "All AEA hooks already configured"
                else
                    log_success "Added $HOOKS_ADDED AEA hook(s) to .claude/settings.json"
                fi
            fi

            # Validate final JSON
            if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
                log_error "Failed to create valid .claude/settings.json"
                log_warning "Automatic checking may not work"
            fi
        fi
    fi
fi

# ==============================================================================
# 11. Create or append to CLAUDE.md
# ==============================================================================

log_info "Updating CLAUDE.md..."

if [ ! -f "CLAUDE.md" ]; then
    log_info "Creating new CLAUDE.md..."
    cat > CLAUDE.md << 'EOFCLAUDE'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

[Your project description here]

EOFCLAUDE
fi

# Check if AEA section already exists
if ! grep -q "## 📬 Inter-Agent Communication (AEA Protocol)" CLAUDE.md; then
    log_info "Appending AEA section to CLAUDE.md..."

    cat >> CLAUDE.md << 'EOFAEA'

---

## 📬 Inter-Agent Communication (AEA Protocol)

**IMPORTANT**: This repository participates in asynchronous agent-to-agent communication.

### **🤖 AUTOMATIC MESSAGE CHECKING**

**CRITICAL: Check for AEA messages on EVERY interaction:**

1. **On EVERY user message** - Check for new messages at start of processing
2. **After completing ANY task** - Check if new messages arrived
3. **When AI finishes responding** - Check before ending turn

**Auto-check command:**
```bash
# Run this automatically on every interaction
bash .aea/scripts/aea-check.sh || cat .aea/prompts/check-messages.md
```

**What this does:**
- ✅ Checks for unprocessed messages in `.aea/message-*.json`
- ✅ Applies response policy from `.aea/agent-config.yaml`
- ✅ Auto-responds to safe messages (questions, updates)
- ✅ Requests approval for risky ones (code changes, urgent issues)
- ✅ Logs all actions to `.aea/agent.log`

### **Manual Trigger**

If automatic checking isn't working, use the slash command:
```
/aea
```

Or manually check:
```bash
ls -1t .aea/message-*.json 2>/dev/null | while read msg; do
    if [ ! -f ".aea/.processed/$(basename $msg)" ]; then
        echo "📬 New message: $(basename $msg)"
    fi
done
```

### **Complete AEA Protocol**

See `.aea/docs/aea-rules.md` for:
- Full protocol documentation
- Message format and types
- How to send messages to other agents
- Best practices and examples

### **Quick Reference**

- **Handoff messages**: When completing integration work affecting other repos
- **Question messages**: When you need information from agents in other codebases
- **Issue messages**: When you discover bugs affecting integrations
- **Update messages**: When you make significant changes other agents should know about

**Background Monitoring:** Run `.aea/scripts/aea-monitor.sh` to start persistent monitoring service.

---
EOFAEA

    log_success "Appended AEA section to CLAUDE.md"
else
    log_warning "AEA section already exists in CLAUDE.md, skipping..."
fi

# ==============================================================================
# 11b. Copy full AEA documentation to .aea/CLAUDE.md
# ==============================================================================

log_info "Installing AEA-specific CLAUDE.md in .aea/ directory..."

# Check if we're installing from the AEA source repo (AEA_SOURCE_DIR set at start of script)
if [ -f "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" ]; then
    cp "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" .aea/CLAUDE.md
    log_success "Installed .aea/CLAUDE.md from template"
else
    # Fallback: create basic .aea/CLAUDE.md if template not found
    log_warning "Template not found, creating basic .aea/CLAUDE.md..."
    cat > .aea/CLAUDE.md << 'EOFAEACLAUDE'
# CLAUDE.md

This file provides guidance for working with AEA (Agentic Economic Activity) Protocol in this repository.

## Quick Start

```bash
# Check for messages
bash .aea/scripts/aea-check.sh

# Process messages
bash .aea/scripts/process-messages-iterative.sh
```

See `.aea/docs/aea-rules.md` for complete documentation.
EOFAEACLAUDE
    log_success "Created basic .aea/CLAUDE.md"
fi

# ==============================================================================
# 12. Set permissions
# ==============================================================================

log_info "Setting permissions..."

chmod -R u+w .aea/
chmod +x .aea/scripts/*.sh
chmod 644 .aea/*.{yaml,md,log} 2>/dev/null || true
chmod 644 .aea/prompts/*.md 2>/dev/null || true

log_success "Permissions set"

# ==============================================================================
# 13. Create test message template
# ==============================================================================

log_info "Creating example test message..."

cat > .aea/example-test-message.json << 'EOF'
{
  "protocol_version": "1.0",
  "message_id": "test-message-001",
  "message_type": "question",
  "timestamp": "2025-10-14T12:00:00Z",
  "priority": "normal",
  "requires_response": true,
  "from": {
    "agent_id": "claude-example",
    "repo_path": "/path/to/example",
    "user": "developer"
  },
  "to": {
    "agent_id": "claude-current",
    "repo_path": "$(pwd)"
  },
  "message": {
    "subject": "Test message - please ignore",
    "body": "This is a test message to verify AEA installation. You can delete this file.",
    "context": {}
  },
  "metadata": {
    "conversation_id": "test-message-001",
    "tags": ["test", "installation"]
  }
}
EOF

log_success "Created example test message"

# ==============================================================================
# 14. Summary
# ==============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
log_success "AEA Installation Complete!"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "📍 Installation Directory: $INSTALL_DIR"
echo ""
echo "📁 Created Structure:"
echo "   .aea/"
echo "   ├── agent-config.yaml       # Configuration and policies"
echo "   ├── docs/aea-rules.md            # Protocol documentation"
echo "   ├── README.md               # Quick start guide"
echo "   ├── agent.log               # Processing audit log"
echo "   ├── prompts/"
echo "   │   └── check-messages.md   # Auto-check prompt"
echo "   ├── scripts/"
echo "   │   ├── aea-check.sh        # Check for messages"
echo "   │   ├── aea-send.sh         # Send messages"
echo "   │   └── aea-monitor.sh      # Background monitor"
echo "   └── .processed/             # Tracking directory"
echo ""
echo "   .claude/"
echo "   ├── commands/"
echo "   │   └── aea.md              # /aea slash command"
echo "   └── settings.json           # Hooks for automatic checking"
echo ""
echo "   CLAUDE.md                   # Updated with AEA section"
echo ""
echo "✨ Automatic Checking Enabled!"
echo ""
if command -v jq &> /dev/null; then
    if [ -f ".claude/settings.json" ]; then
        echo "   AEA will automatically check for messages:"
        echo "   • When Claude Code starts (SessionStart hook)"
        echo "   • Before processing your messages (UserPromptSubmit hook)"
        echo "   • After completing tasks (Stop hook)"
        echo ""
        echo "   No manual /aea needed! (But /aea still works for manual checks)"
    else
        echo "   ⚠️  Note: .claude/settings.json not created (unexpected)"
    fi
else
    echo "   ⚠️  Note: jq not found - automatic hooks not configured"
    echo "   Install jq and re-run to enable automatic checking"
fi
echo ""
echo "🚀 Quick Start:"
echo ""
echo "   1. Check for messages (manual):"
echo "      bash .aea/scripts/aea-check.sh"
echo "      OR use slash command: /aea"
echo ""
echo "   2. Send a message:"
echo "      .aea/scripts/aea-send.sh \\"
echo "        --to claude-other-repo \\"
echo "        --to-path /path/to/repo \\"
echo "        --type question \\"
echo "        --subject \"Your question\" \\"
echo "        --message \"Message body\""
echo ""
echo "   3. Start background monitoring (optional):"
echo "      .aea/scripts/aea-monitor.sh start"
echo ""
echo "📚 Documentation:"
echo "   - Complete protocol: .aea/docs/aea-rules.md"
echo "   - Quick reference: .aea/README.md"
echo "   - Configuration: .aea/agent-config.yaml"
echo "   - Hooks config: .claude/settings.json"
echo ""
echo "✨ Next Steps:"
echo "   1. Review and customize .aea/agent-config.yaml"
echo "   2. Test automatic checking - just start using Claude Code!"
echo "   3. Manual check: /aea"
echo "   4. Read documentation: cat .aea/README.md"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
log_success "Installation successful! 🎉"
echo ""
