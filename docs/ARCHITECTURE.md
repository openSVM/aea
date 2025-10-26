# AEA Protocol - Architecture Documentation

**Version**: 0.1.0
**Last Updated**: 2025-10-25

Complete technical architecture of the AEA (Agentic Economic Activity) Protocol.

---

## 📋 Table of Contents

1. [System Overview](#system-overview)
2. [Core Components](#core-components)
3. [Message Flow](#message-flow)
4. [File Structure](#file-structure)
5. [Script Architecture](#script-architecture)
6. [Hook System](#hook-system)
7. [Registry System](#registry-system)
8. [Message Processing Pipeline](#message-processing-pipeline)
9. [Monitoring System](#monitoring-system)
10. [Design Decisions](#design-decisions)

---

## System Overview

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Claude Code Environment                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                      User Interaction                       │ │
│  │  (SessionStart, UserPromptSubmit, Stop)                    │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                         │
│                         ▼                                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Hook System                             │ │
│  │  .claude/settings.json → Triggers AEA scripts             │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                         │
└─────────────────────────┼─────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AEA Core System                             │
│                                                                  │
│  ┌────────────┐     ┌────────────┐     ┌────────────┐          │
│  │  Message   │────▶│  Message   │────▶│  Message   │          │
│  │  Checker   │     │ Validator  │     │ Processor  │          │
│  └────────────┘     └────────────┘     └────────────┘          │
│         │                  │                   │                 │
│         │                  │                   │                 │
│         ▼                  ▼                   ▼                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │            Message Storage (.aea/)                  │        │
│  │  • message-*.json     (incoming messages)          │        │
│  │  • .processed/        (tracking markers)           │        │
│  │  • agent.log          (audit trail)                │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                  │
│  ┌─────────────────────────────────────────────────────┐        │
│  │         Agent Registry (~/.config/aea/)             │        │
│  │  • agents.yaml        (global agent directory)     │        │
│  └─────────────────────────────────────────────────────┘        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Background Monitor (Optional)                   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Monitor Loop (60s interval)                               ││
│  │  1. Check for new messages                                 ││
│  │  2. Check GitHub issues (if enabled)                       ││
│  │  3. Trigger processing if needed                           ││
│  │  4. Sleep                                                   ││
│  └─────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **File-Based**: All messages are JSON files, no databases required
2. **Asynchronous**: Agents communicate via file writes, no direct connections
3. **Autonomous**: Claude can process messages without user intervention
4. **Auditable**: All actions logged to `agent.log`
5. **Decentralized**: No central server, agents communicate peer-to-peer

---

## Core Components

### 1. Message System

**Purpose**: Handle message lifecycle from creation to processing.

**Components**:
- **Message Creator** (`aea-send.sh`): Creates outbound messages
- **Message Validator** (`aea-validate-message.sh`): Ensures protocol compliance
- **Message Checker** (`aea-check.sh`): Detects new messages
- **Message Processor** (`process-messages-iterative.sh`): Handles inbound messages

### 2. Hook System

**Purpose**: Automatically trigger message checks at key points.

**Hooks**:
```json
{
  "hooks": {
    "SessionStart": {
      "command": "bash .aea/scripts/aea-auto-processor.sh",
      "description": "Auto-process AEA messages on session start",
      "enabled": true
    },
    "UserPromptSubmit": "bash .aea/scripts/aea-check.sh",
    "Stop": {
      "command": "bash .aea/scripts/aea-auto-processor.sh",
      "description": "Auto-process AEA messages after task completion",
      "enabled": true
    }
  }
}
```

**Trigger Points**:
- **SessionStart**: When Claude Code starts
- **UserPromptSubmit**: Before processing user messages
- **Stop**: After completing tasks

### 3. Registry System

**Purpose**: Maintain a directory of known agents for message routing.

**Location**: `~/.config/aea/agents.yaml`

**Structure**:
```yaml
agents:
  agent-name:
    path: /absolute/path/to/repo
    enabled: true
    description: "Human-readable description"
    registered_at: "2025-10-25T10:00:00Z"
```

### 4. Monitoring System

**Purpose**: Background process for continuous message checking.

**Features**:
- PID-based process management
- Configurable check interval
- Health checks and auto-restart
- Graceful shutdown

### 5. Policy Engine

**Purpose**: Determine how to handle incoming messages.

**Configuration** (`.aea/agent-config.yaml`):
```yaml
policies:
  auto_respond:
    enabled: true
    message_types: [question, request, update]
    max_priority: normal
    require_approval: [handoff, issue]
```

---

## Message Flow

### Sending a Message

```
┌──────────┐
│  User    │
│  calls   │
│ aea-send │
└────┬─────┘
     │
     ▼
┌─────────────────────┐
│ 1. Validate params  │
│    - to, type, etc  │
└────┬────────────────┘
     │
     ▼
┌─────────────────────┐
│ 2. Lookup recipient │
│    in registry      │
└────┬────────────────┘
     │
     ▼
┌─────────────────────┐
│ 3. Create message   │
│    JSON with        │
│    protocol v0.1.0  │
└────┬────────────────┘
     │
     ▼
┌─────────────────────┐
│ 4. Validate message │
│    against schema   │
└────┬────────────────┘
     │
     ▼
┌─────────────────────┐
│ 5. Write to         │
│    recipient's      │
│    .aea/ directory  │
└────┬────────────────┘
     │
     ▼
┌─────────────────────┐
│ 6. Log action       │
└─────────────────────┘
```

### Receiving and Processing

```
┌──────────────┐
│ Hook trigger │
│ or monitor   │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ 1. aea-check.sh      │
│    Scan .aea/ for    │
│    message-*.json    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ 2. Filter processed  │
│    Check .processed/ │
│    directory         │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ 3. Display summary   │
│    to user/log       │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ 4. User processes    │
│    (manual or auto)  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ 5. Policy engine     │
│    decides action    │
└──────┬───────────────┘
       │
       ├─(auto)─▶┌─────────────────┐
       │         │ Auto-respond     │
       │         │ Create response  │
       │         └─────────────────┘
       │
       └─(manual)▶┌─────────────────┐
                  │ Ask user         │
                  │ Wait for input   │
                  └─────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ 6. Mark as      │
                  │    processed    │
                  │    (touch file) │
                  └─────────────────┘
```

---

## File Structure

### Installed Directory Layout

```
project-root/
│
├── .aea/                              # AEA installation directory
│   ├── aea.sh                         # Main operational script
│   ├── agent-config.yaml              # Configuration & policies
│   ├── agent.log                      # Processing audit log
│   ├── CLAUDE.md                      # Instructions for Claude
│   ├── PROTOCOL.md                    # Protocol specification
│   ├── README.md                      # Quick reference
│   │
│   ├── message-*.json                 # Incoming messages
│   ├── example-test-message.json      # Sample message
│   │
│   ├── .processed/                    # Processed message markers
│   │   └── message-*.json             # Empty marker files
│   │
│   ├── docs/                          # Documentation
│   │   ├── aea-rules.md
│   │   ├── EXAMPLES.md
│   │   ├── INSTALLATION.md
│   │   └── ...
│   │
│   ├── prompts/                       # Prompt templates
│   │   └── check-messages.md
│   │
│   └── scripts/                       # Executable scripts
│       ├── aea-check.sh               # Check for messages
│       ├── aea-send.sh                # Send messages
│       ├── aea-monitor.sh             # Background monitor
│       ├── aea-registry.sh            # Agent registry
│       ├── aea-validate-message.sh    # Message validation
│       ├── aea-auto-processor.sh      # Automatic processing
│       ├── process-messages-iterative.sh
│       └── ...
│
├── .claude/
│   ├── commands/
│   │   └── aea.md                     # /aea slash command
│   └── settings.json                  # Hooks configuration
│
└── CLAUDE.md                          # Updated with AEA section
```

### Global Registry Structure

```
~/.config/aea/
├── agents.yaml                         # Global agent registry
└── monitor-*.pid                       # Monitor PID files (per repo)
```

---

## Script Architecture

### Message Lifecycle Scripts

#### 1. `aea-send.sh` - Message Creation

**Purpose**: Create and send messages to other agents.

**Flow**:
```bash
1. Parse command-line arguments (--to, --type, --subject, etc.)
2. Validate required parameters
3. Lookup recipient in registry (~/.config/aea/agents.yaml)
4. Generate message ID (UUID or timestamp-based)
5. Create JSON structure per protocol v0.1.0
6. Validate message structure
7. Write to recipient's .aea/ directory
8. Log action to sender's agent.log
9. Display confirmation
```

**Key Features**:
- Registry-based routing
- Template-based message creation
- Validation before sending
- In-reply-to support for threading

#### 2. `aea-check.sh` - Message Detection

**Purpose**: Scan for unprocessed messages.

**Flow**:
```bash
1. Scan .aea/ for message-*.json files
2. For each message:
   a. Extract basename
   b. Check if .processed/{basename} exists
   c. If not, add to unprocessed list
3. If GitHub integration enabled:
   a. Call aea-issues.sh
   b. Aggregate GitHub issues
4. Display summary:
   a. Count of unprocessed messages
   b. Message details (type, priority, from, subject)
   c. Next steps
5. Log check to agent.log
```

**Key Features**:
- Fast scanning with glob patterns
- Efficient duplicate detection
- Optional GitHub integration
- User-friendly output

#### 3. `process-messages-iterative.sh` - Message Processing

**Purpose**: Process messages one by one with context compaction.

**Flow**:
```bash
1. Find unprocessed messages
2. For each message:
   a. Display message content
   b. Check policy engine
   c. If auto-processable:
      - Create processing instruction
      - Generate response (Claude)
      - Send response (if needed)
   d. If manual approval needed:
      - Display to user
      - Wait for user action
   e. Mark as processed (touch .processed/{basename})
3. Log all actions
4. Continue to next message
```

**Key Features**:
- Iterative processing (one at a time)
- Policy-driven automation
- Context compaction between messages
- Audit trail

#### 4. `aea-auto-processor.sh` - Automatic Orchestration

**Purpose**: Hook-triggered automatic processing.

**Flow**:
```bash
1. Check for unprocessed messages
2. If none, exit silently
3. If messages exist:
   a. Check policies
   b. Process auto-processable messages
   c. Notify user of manual-approval messages
4. Log hook execution
```

**Key Features**:
- Silent when no messages
- Non-blocking (runs quickly)
- Policy-aware
- Hook-optimized

### Utility Scripts

#### `aea-registry.sh` - Agent Management

**Commands**:
- `register` - Add agent to registry
- `unregister` - Remove agent
- `list` - Show all agents
- `lookup` - Find agent by name
- `update` - Modify agent details

**Registry Operations**:
```bash
# Register
aea-registry.sh register agent-name /path/to/repo "Description"

# Lookup
agent_path=$(aea-registry.sh lookup agent-name)

# List
aea-registry.sh list
```

#### `aea-validate-message.sh` - Schema Validation

**Validates**:
- Required fields (protocol_version, message_id, etc.)
- Field types (strings, objects, arrays)
- Protocol version compatibility
- Message structure

**Usage**:
```bash
aea-validate-message.sh message-file.json
# Exit code 0 = valid, 1 = invalid
```

#### `aea-monitor.sh` - Background Process Management

**Commands**:
- `start` - Start background monitor
- `stop` - Stop monitor gracefully
- `restart` - Restart monitor
- `status` - Check if running

**PID Management**:
```bash
# Store PID
echo $$ > .aea/monitor.pid

# Check if running
kill -0 $(cat .aea/monitor.pid) 2>/dev/null

# Stop gracefully
kill $(cat .aea/monitor.pid)
```

---

## Hook System

### Hook Integration

Claude Code hooks execute bash commands at specific lifecycle events.

**Configuration**: `.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart": {
      "command": "bash .aea/scripts/aea-auto-processor.sh",
      "description": "Auto-process AEA messages on session start",
      "enabled": true
    },
    "UserPromptSubmit": "bash .aea/scripts/aea-check.sh",
    "Stop": {
      "command": "bash .aea/scripts/aea-auto-processor.sh",
      "description": "Auto-process AEA messages after task completion",
      "enabled": true
    }
  }
}
```

### Hook Execution Flow

```
User Action              Hook Trigger                AEA Script
───────────              ────────────                ──────────

Claude Code             SessionStart          aea-auto-processor.sh
starts                  ────────────▶         • Check messages
                                              • Auto-process if possible
                                              • Silent if none

User types              UserPromptSubmit      aea-check.sh
message                 ────────────▶         • Scan for messages
                                              • Display summary
                                              • Non-blocking

User completes          Stop                  aea-auto-processor.sh
task                    ────────────▶         • Process any new messages
                                              • Send responses
                                              • Log completion
```

### Hook Design Principles

1. **Fast**: Hooks must complete quickly (<500ms typical)
2. **Silent**: No output unless there's something important
3. **Non-blocking**: Don't prevent Claude from working
4. **Idempotent**: Safe to run multiple times
5. **Error-tolerant**: Failures shouldn't break Claude

---

## Registry System

### Registry Architecture

**Central Registry**: `~/.config/aea/agents.yaml`

**Purpose**:
- Map agent names to repository paths
- Enable cross-repository messaging
- Track agent metadata

**Structure**:
```yaml
agents:
  frontend-app:
    path: /home/user/projects/frontend
    enabled: true
    description: "React frontend application"
    registered_at: "2025-10-25T10:00:00Z"

  backend-api:
    path: /home/user/projects/backend
    enabled: true
    description: "Node.js API server"
    registered_at: "2025-10-25T10:01:00Z"
```

### Registry Operations

**Lookup**:
```bash
# Find agent path
lookup_agent() {
    local agent_id="$1"
    yq eval ".agents.${agent_id}.path" ~/.config/aea/agents.yaml
}
```

**Register**:
```bash
# Add new agent
register_agent() {
    local agent_id="$1"
    local path="$2"
    local description="$3"

    yq eval ".agents.${agent_id} = {
        \"path\": \"${path}\",
        \"enabled\": true,
        \"description\": \"${description}\",
        \"registered_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" -i ~/.config/aea/agents.yaml
}
```

---

## Message Processing Pipeline

### Policy Engine

**Decision Tree**:

```
Message Received
    │
    ▼
┌──────────────────┐
│ Extract metadata │
│ - type           │
│ - priority       │
│ - from           │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Check policy     │
│ auto_respond     │
└────────┬─────────┘
         │
    ┌────┴────┐
    │ Enabled?│
    └────┬────┘
         │
    ┌────┴────────────┐
    │                 │
   NO                YES
    │                 │
    ▼                 ▼
┌──────────┐    ┌──────────────┐
│ Notify   │    │ Check type   │
│ user     │    │ allowed?     │
└──────────┘    └──────┬───────┘
                       │
                  ┌────┴────┐
                  │ Allowed?│
                  └────┬────┘
                       │
                  ┌────┴─────────┐
                  │              │
                 NO             YES
                  │              │
                  ▼              ▼
            ┌──────────┐   ┌──────────────┐
            │ Notify   │   │ Check        │
            │ user     │   │ priority     │
            └──────────┘   └──────┬───────┘
                                  │
                             ┌────┴────┐
                             │ ≤ max?  │
                             └────┬────┘
                                  │
                             ┌────┴──────────┐
                             │               │
                            NO              YES
                             │               │
                             ▼               ▼
                       ┌──────────┐    ┌──────────────┐
                       │ Notify   │    │ Auto-process │
                       │ user     │    │ message      │
                       └──────────┘    └──────────────┘
```

### Processing States

Messages go through these states:

1. **Unprocessed**: Message exists, not in `.processed/`
2. **Detected**: Found by `aea-check.sh`
3. **Evaluating**: Policy engine determining action
4. **Processing**: Claude actively handling message
5. **Processed**: Marked in `.processed/`, action taken

---

## Monitoring System

### Monitor Architecture

**Background Process**: `aea-monitor.sh`

**Components**:
1. **PID Manager**: Track process lifecycle
2. **Health Checker**: Detect crashes, auto-restart
3. **Interval Loop**: Periodic message checking
4. **Logger**: Audit all monitor actions

### Monitor Loop

```bash
while true; do
    # 1. Check for new messages
    bash .aea/scripts/aea-check.sh >> monitor.log 2>&1

    # 2. Check GitHub issues (if enabled)
    if is_github_enabled; then
        bash .aea/scripts/aea-issues.sh >> monitor.log 2>&1
    fi

    # 3. Auto-process if needed
    if has_auto_processable_messages; then
        bash .aea/scripts/aea-auto-processor.sh >> monitor.log 2>&1
    fi

    # 4. Sleep until next interval
    sleep $CHECK_INTERVAL_SECONDS
done
```

### PID Management

```bash
# Start monitor
aea-monitor.sh start
    → Fork background process
    → Save PID to .aea/monitor.pid
    → Redirect output to .aea/monitor.log

# Check status
aea-monitor.sh status
    → Read .aea/monitor.pid
    → Check if process exists (kill -0 $PID)
    → Display status

# Stop monitor
aea-monitor.sh stop
    → Read .aea/monitor.pid
    → Send SIGTERM (graceful)
    → Wait for exit
    → Remove PID file
```

---

## Design Decisions

### Why File-Based?

**Advantages**:
- ✅ No network infrastructure needed
- ✅ Works offline
- ✅ Simple debugging (just read files)
- ✅ Easy backup (standard filesystem tools)
- ✅ Atomic operations (filesystem guarantees)
- ✅ No authentication complexity

**Tradeoffs**:
- ⚠️ Requires shared filesystem or NFS
- ⚠️ Not suitable for internet-scale communication
- ⚠️ File system performance limits throughput

### Why JSON for Messages?

**Advantages**:
- ✅ Human-readable
- ✅ Easy to debug
- ✅ Wide tool support (jq, etc.)
- ✅ Schema validation possible
- ✅ Claude can generate/parse easily

**Tradeoffs**:
- ⚠️ Larger than binary formats
- ⚠️ No built-in encryption

### Why Hooks Instead of Polling?

**Advantages**:
- ✅ Immediate detection (no polling delay)
- ✅ Lower resource usage (event-driven)
- ✅ Better user experience (automatic)

**Tradeoffs**:
- ⚠️ Requires Claude Code support
- ⚠️ Hook failures can be silent

### Why Centralized Registry?

**Advantages**:
- ✅ Single source of truth
- ✅ Easy management
- ✅ Supports discovery

**Tradeoffs**:
- ⚠️ Single point of failure
- ⚠️ Manual registration required

**Future**: Could support distributed discovery.

---

## Performance Considerations

### Bottlenecks

1. **File I/O**: Reading/writing JSON files
2. **jq Processing**: JSON parsing and validation
3. **Hook Latency**: Time to execute check scripts

### Optimizations

1. **Processed Tracking**: Use `.processed/` to skip already-handled messages
2. **Glob Patterns**: Fast file matching instead of `find`
3. **Single jq Invocation**: Extract multiple fields at once
4. **Minimal Logging**: Only log important events
5. **Background Monitor**: Separate process for continuous checking

### Scalability Limits

**Tested**:
- 100+ messages in queue ✅
- 5+ concurrent agents ✅
- 60-second check interval ✅

**Theoretical Limits**:
- ~1000 messages before filesystem slowdown
- ~50 agents before registry gets unwieldy
- ~10 messages/second throughput

**Future Improvements**:
- Message archiving
- Index files for fast lookup
- Binary message format option

---

## Future Architecture Enhancements

### Planned Improvements

1. **Message Encryption**
   - End-to-end encrypted message bodies
   - Key exchange via registry

2. **Distributed Registry**
   - DHT-based agent discovery
   - No central registry file

3. **Message Queue**
   - Priority queue for message processing
   - Fair scheduling

4. **Webhook Support**
   - HTTP callbacks for message events
   - Integration with external systems

5. **Multi-Hop Routing**
   - Messages relay through intermediaries
   - Network-of-agents topology

---

## Reference Implementation

For working examples, see:
- [Installation Script](../scripts/install-aea.sh) - How components are installed
- [Message Sender](../scripts/aea-send.sh) - Message creation
- [Message Checker](../scripts/aea-check.sh) - Message detection
- [Protocol Spec](../PROTOCOL.md) - Message format

---

**Last Updated**: 2025-10-25 | **Version**: 0.1.0 | [View Source](https://github.com/openSVM/aea)
