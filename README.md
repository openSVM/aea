# AEA - Agentic Economic Activity Protocol

**Version 0.1.0** | **Status: Beta** | [Documentation](docs/) | [FAQ](docs/FAQ.md) | [Troubleshooting](docs/TROUBLESHOOTING.md) | [Architecture](docs/ARCHITECTURE.md) | [Examples](docs/EXAMPLES.md)

Complete autonomous agent communication system for Claude Code with automatic message processing and background monitoring.

---

## 🚀 **Installation**

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/openSVM/aea/main/install.sh | bash
```

**That's it!** The installer automatically:
- ✅ Downloads all required files from GitHub
- ✅ Creates `.aea/` directory structure
- ✅ Sets up Claude Code integration
- ✅ Configures automatic message checking

**Note**: This requires `bash`. If you only have `sh`, use the manual method below.

### Manual Install (For POSIX sh compatibility)

```bash
# Clone the repository
git clone https://github.com/openSVM/aea
cd aea

# Run the local installer
bash scripts/install-aea.sh /path/to/your/project
```

📖 **[Read the full installation guide →](INSTALL_GUIDE.md)**

### What Gets Installed

The installation creates:
- `.aea/` - Complete AEA system with scripts and configuration
- `.claude/settings.json` - Hooks for automatic message processing
- `.claude/commands/aea.md` - `/aea` slash command
- `~/.config/aea/agents.yaml` - Agent registry (auto-initialized)
- Updates `CLAUDE.md` with AEA integration instructions

### Requirements

- **bash** 4.0+
- **jq** - For JSON processing (install: `apt-get install jq` or `brew install jq`)
- **Claude Code** - This protocol is designed for Claude Code agents

### Post-Installation

After installation, your repository is:
1. ✅ Registered in the agent registry (`~/.config/aea/agents.yaml`)
2. ✅ Ready to send messages to other agents
3. ✅ Automatically processing incoming messages via hooks
4. ✅ Configured with the `/aea` slash command

To register other repositories for messaging:
```bash
bash .aea/scripts/aea-registry.sh register agent-name /path/to/repo "Description"
```

---

## 🎯 **System Overview**

This system enables **fully autonomous inter-agent communication** with:

✅ **Automatic checking** on every user message / AI response / task completion
✅ **Configuration-driven policies** for autonomous decision-making
✅ **Background monitoring** service for continuous operation
✅ **PID management** with health checks and graceful failover
✅ **Multi-project support** via centralized configuration
✨ **GitHub Issues integration** - automatically checks relevant issues based on your work context

---

## 🚀 **Quick Start**

### **1. Manual Message Check**

```bash
/aea
```

Or from command line:
```bash
bash .aea/scripts/aea-check.sh
```

### **2. Start Background Monitor**

```bash
bash .aea/scripts/aea-monitor.sh start
```

**What this does:**
- ✅ Auto-registers current directory to `~/.config/aea/projects.yaml`
- ✅ Checks for existing monitor (PID healthcheck)
- ✅ Starts new background service if needed
- ✅ Monitors every 5 minutes for new messages

### **3. Check Monitor Status**

```bash
bash .aea/scripts/aea-monitor.sh status
```

### **4. Stop Background Monitor**

```bash
bash .aea/scripts/aea-monitor.sh stop
```

---

## 📚 **Complete Workflow Example**

### End-to-End: Two Agents Communicating

This example shows the complete autonomous flow between two repositories.

#### **Step 1: Setup Two Repositories**

```bash
# Install AEA in backend repo
cd ~/projects/backend
bash /path/to/aea/scripts/install-aea.sh
# ✅ Auto-registers as "claude-backend"

# Install AEA in frontend repo
cd ~/projects/frontend
bash /path/to/aea/scripts/install-aea.sh
# ✅ Auto-registers as "claude-frontend"
```

#### **Step 2: Verify Registry**

```bash
# From either repo, check the registry
bash .aea/scripts/aea-registry.sh list

# Output:
# Agent: claude-backend
#   Path: /home/user/projects/backend
#   Enabled: true
#
# Agent: claude-frontend
#   Path: /home/user/projects/frontend
#   Enabled: true
```

#### **Step 3: Send a Question**

From backend, ask frontend about API endpoints:

```bash
cd ~/projects/backend

bash .aea/scripts/aea-send.sh \
  --to claude-frontend \
  --type question \
  --subject "API endpoints" \
  --message "What API endpoints consume the user authentication service?" \
  --priority normal
```

**Output:**
```
✅ Message delivered!
From: claude-backend
To:   claude-frontend
Message file: /home/user/projects/frontend/.aea/message-....json
```

#### **Step 4: Autonomous Processing (Automatic!)**

The frontend repo's hooks automatically:

1. **Detect** the message (SessionStart or Stop hook fires)
2. **Validate** JSON structure
3. **Classify** as simple question
4. **Extract** search terms: "endpoints consume user authentication service"
5. **Search** codebase for matching files
6. **Generate** response with findings
7. **Send** response back to backend
8. **Mark** original message as processed

**All without human intervention!** ⚡

#### **Step 5: Check the Response**

Back in backend repo:

```bash
cd ~/projects/backend

# List responses
ls .aea/message-*-from-claude-frontend.json

# Read the response
cat .aea/message-*-from-claude-frontend.json | jq -r '.message.body'
```

**Example Response:**
```
Auto-search results for: endpoints consume user authentication service

Files matching 'authentication':
./src/api/auth.ts
./src/api/user-service.ts

Files containing 'authentication service':
./src/api/auth.ts
./src/api/routes/login.ts

---
This response was automatically generated by searching the codebase.
If you need more detailed analysis, please ask again with more context.
```

#### **What Just Happened?**

✅ **Cross-repo messaging** - Message automatically delivered via registry
✅ **Autonomous detection** - Hooks fired without manual trigger
✅ **Smart classification** - Identified as simple, auto-processable query
✅ **Automatic processing** - Searched and responded without asking
✅ **Response delivery** - Answer sent back automatically

**No human typed anything except the initial question!**

#### **For Complex Queries**

If you ask something complex, like:

```bash
bash .aea/scripts/aea-send.sh \
  --to claude-frontend \
  --type request \
  --subject "Refactoring request" \
  --message "Please refactor the authentication module to use OAuth2"
```

The auto-processor will:
1. Classify as "request" (code changes)
2. **Escalate** to Claude with message:
   ```
   ⚠️ Message requires review: message-....json
      Type: request | Priority: normal
      From: claude-backend
      Subject: Refactoring request
      Use /aea to process this message
   ```

**Safe escalation for risky operations!** ✅

---

## 📁 **File Structure**

```
.aea/
├── README.md                    # This file
├── agent-config.yaml            # Response policies and agent configuration
├── agent-launcher.md            # Usage documentation
├── docs/aea-rules.md                 # Complete AEA protocol specification
├── PROTOCOL.md                  # Technical protocol details
├── agent.log                    # Agent activity log
│
├── prompts/
│   └── check-messages.md        # Prompt template for message checking
│
├── scripts/
│   ├── aea-check.sh            # Manual message check script
│   └── aea-monitor.sh          # Background monitoring daemon
│
├── message-*.json               # Incoming messages
└── .processed/
    └── message-*.json           # Processed message markers
```

---

## 🤖 **How Automatic Checking Works**

AEA uses **two methods** for automatic checking:

### **Method 1: Claude Code Hooks (Recommended)**

After installation, AEA configures hooks in `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": {
      "command": "bash .aea/scripts/aea-check.sh",
      "description": "Check for new AEA messages on session start",
      "enabled": true
    },
    "UserPromptSubmit": {
      "command": "bash .aea/scripts/aea-check.sh",
      "description": "Check for AEA messages before processing user prompt",
      "enabled": true
    },
    "Stop": {
      "command": "bash .aea/scripts/aea-check.sh",
      "description": "Check for AEA messages after task completion",
      "enabled": true
    }
  }
}
```

**How it works:**
- ✅ **SessionStart**: Checks for messages when Claude Code starts
- ✅ **UserPromptSubmit**: Checks before processing every user message
- ✅ **Stop**: Checks after completing tasks
- ✅ Completely automatic - no manual `/aea` needed!
- ✅ Hook output visible to Claude - messages are processed automatically

**To disable automatic checking**, edit `.claude/settings.json`:
```json
{
  "hooks": {
    "SessionStart": { "enabled": false },
    "UserPromptSubmit": { "enabled": false },
    "Stop": { "enabled": false }
  }
}
```

### **Method 2: CLAUDE.md Instructions (Fallback)**

The `CLAUDE.md` file includes:

```markdown
### **🤖 AUTOMATIC MESSAGE CHECKING**

**CRITICAL: Check for AEA messages on EVERY interaction:**

1. **On EVERY user message** - Check for new messages at start of processing
2. **After completing ANY task** - Check if new messages arrived
3. **When AI finishes responding** - Check before ending turn
```

This method relies on Claude following CLAUDE.md guidance. Hooks (Method 1) are more reliable.

### **Processing Flow**

```
User Message
    ↓
Hook fires: UserPromptSubmit
    ↓
Automatic check: bash .aea/scripts/aea-check.sh
    ↓
Messages found? → Yes → Claude sees output and processes
                → No  → Continue normal operation
    ↓
Process user request
    ↓
Hook fires: Stop → Check again
    ↓
Respond to user
```

---

## 📋 **Response Policies**

Defined in `agent-config.yaml`:

| Message Type | Priority | Action | Approval Needed? |
|--------------|----------|--------|-----------------|
| **question** | any | Auto-respond with technical answer | ❌ No |
| **update** | normal | Auto-acknowledge if needed | ❌ No |
| **update** | high/urgent | Summarize and inform user | ❌ No |
| **issue** | low/medium | Auto-analyze and suggest fix | ❌ No |
| **issue** | high/urgent | Notify user and wait | ✅ Yes |
| **handoff** | any | Review and request approval | ✅ Yes |
| **request** | any | Evaluate and respond with plan | ⚠️ Depends |

### **Auto-Safe Operations** (No Approval)

- ✅ Read files
- ✅ Search codebase
- ✅ Analyze code
- ✅ Answer technical questions
- ✅ Generate documentation
- ✅ Create response messages

### **Require Approval** (User Permission)

- ❌ Code changes
- ❌ Configuration modifications
- ❌ Deployment actions
- ❌ Security-related changes

---

## 🔧 **Background Monitor Details**

### **Architecture**

```
~/.config/aea/projects.yaml  ← Central configuration
         ↓
   aea-monitor.sh (daemon)
         ↓
   Checks every 5 minutes
         ↓
   For each registered project:
     1. Check .aea/message-*.json
     2. Find unprocessed messages
     3. Log to .aea/agent.log
     4. (Future) Trigger Claude via API
```

### **PID Management Logic**

When you run `aea-monitor.sh start`:

```python
# Pseudo-code
if current_dir not in projects.yaml:
    add_current_dir_to_yaml()

existing_pid = get_pid_from_yaml(current_dir)

if existing_pid exists:
    health_status = send_healthcheck(existing_pid)

    if health_status == "OK":
        print("Existing monitor is healthy")
        shutdown_self()  # Don't start duplicate
    else:
        kill(existing_pid, SIGTERM)  # Graceful shutdown
        wait_or_force_kill()
        start_new_monitor()
else:
    start_new_monitor()

# Save our PID to yaml
update_yaml(current_dir, our_pid)
```

### **Health Check Protocol**

1. **Monitor receives SIGUSR1** (health check signal)
2. **If process alive** → Returns OK
3. **If process dead/hanging** → Returns ERROR
4. **Caller takes action** based on response

### **Configuration File**

Location: `~/.config/aea/projects.yaml`

```yaml
version: "1.0"
check_interval_default: 300  # 5 minutes

projects:
  - name: "this-repo"
    path: "/path/to/this-repo"
    enabled: true
    check_interval: 300
    job_pid: 12345
    agent_id: "claude-aea"
    last_check: "2025-10-14T14:30:00Z"

  - name: "other-repo"
    path: "/path/to/other-repo"
    enabled: true
    check_interval: 300
    job_pid: 12346
    agent_id: "claude-agent-1"
    last_check: "2025-10-14T14:30:00Z"
```

### **Monitor Logs**

- **Daemon logs:** `~/.config/aea/monitor.log`
- **Project logs:** `.aea/agent.log` (per project)

---

## 📬 **Message Processing Examples**

### **Example 1: Technical Question (Auto-Respond)**

**Incoming:** `.aea/message-20251014T143000Z-from-claude-agent-1.json`

```json
{
  "message_type": "question",
  "priority": "normal",
  "requires_response": true,
  "from": {"agent_id": "claude-agent-1"},
  "message": {
    "subject": "Batch size for 50k updates/sec?",
    "question": "What's the optimal batch_size?"
  }
}
```

**Claude's Autonomous Action:**

1. ✅ Reads message (automatic via CLAUDE.md instruction)
2. ✅ Determines: `question` + `normal` → Auto-respond (no approval)
3. ✅ Searches `CLAUDE.md:450-470` for performance data
4. ✅ Generates technical answer with code references
5. ✅ Creates response: `/path/to/other-repo/.aea/message-{timestamp}-from-claude-aea.json`
6. ✅ Marks original as processed: `.aea/.processed/message-20251014T143000Z-from-claude-agent-1.json`
7. ✅ Logs action to `.aea/agent.log`

**User sees:** "✅ Processed 1 message: answered technical question from claude-agent-1"

### **Example 2: High Priority Issue (Request Approval)**

**Incoming:** `.aea/message-20251014T150000Z-from-claude-agent-1.json`

```json
{
  "message_type": "issue",
  "priority": "high",
  "from": {"agent_id": "claude-agent-1"},
  "message": {
    "issue_description": "Memory leak in batch processing",
    "severity": "high"
  }
}
```

**Claude's Autonomous Action:**

1. ✅ Reads message
2. ✅ Determines: `issue` + `high` → Require approval
3. ✅ Notifies user:

```
🚨 High priority issue reported by claude-agent-1

Issue: Memory leak in batch processing
Severity: high

Should I:
1. Analyze and propose a fix?
2. Forward to you for investigation?
3. Ignore (mark as processed)?
```

4. ⏳ Waits for user response
5. ✅ After approval: Searches codebase, analyzes, sends response

---

## 🔄 **Integration with Other Repos**

### **This Repository**

- **Agent ID:** `claude-aea`
- **Role:** Redis Orderbook Module Developer
- **Monitors:** `/path/to/this-repo/.aea/`
- **Can auto-respond about:**
  - Redis commands
  - Performance tuning
  - Integration help
  - API documentation
  - Build issues

### **Partner Repo (other-repo)**

- **Agent ID:** `claude-agent-1`
- **Role:** Data Pipeline Integration Engineer
- **Monitors:** `/path/to/other-repo/.aea/`
- **Integration topics:**
  - OrderbookSaver usage
  - Batch configuration
  - Performance optimization
  - Error troubleshooting

### **Communication Flow**

```
other-repo agent          repo-a agent
      ↓                       ↓
  Has question          Auto-checks .aea/
      ↓                       ↓
Creates message         Finds message
      ↓                       ↓
Saves to:              Reads message
repo-a/.aea/                  ↓
      ↓                Applies policy
      ↓                       ↓
      ←────────────────  Sends response
      ↓
Receives answer
```

---

## 🎯 **Commands Reference**

### **Manual Check**

```bash
# Via slash command (in Claude)
/aea

# Via script
bash .aea/scripts/aea-check.sh

# Check what would be processed
ls -1t .aea/message-*.json | while read msg; do
    [ -f ".aea/.processed/$(basename $msg)" ] || echo "Unprocessed: $msg"
done
```

### **Background Monitor**

```bash
# Start monitoring
bash .aea/scripts/aea-monitor.sh start

# Check status
bash .aea/scripts/aea-monitor.sh status

# Stop monitoring
bash .aea/scripts/aea-monitor.sh stop

# View logs
tail -f ~/.config/aea/monitor.log
tail -f .aea/agent.log
```

### **Configuration**

```bash
# View projects
cat ~/.config/aea/projects.yaml

# View agent config
cat .aea/agent-config.yaml

# View processing log
cat .aea/agent.log
```

---

## 🐛 **Troubleshooting**

### **Installation Issues**

#### "jq: command not found"
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Or download from: https://stedolan.github.io/jq/download/
```

#### Auto-processor not installed
```bash
# Verify auto-processor exists
ls .aea/scripts/aea-auto-processor.sh

# If missing, re-install from source with latest version
bash /path/to/aea/scripts/install-aea.sh
```

---

### **Message Delivery Issues**

#### Messages not being delivered to other agents
```bash
# 1. Check agent registry
bash .aea/scripts/aea-registry.sh list

# 2. Verify destination agent exists
bash .aea/scripts/aea-registry.sh get-path target-agent-name

# 3. Check destination has .aea/ directory
ls /path/to/destination/.aea/

# 4. Manually register if needed
bash .aea/scripts/aea-registry.sh register agent-name /path/to/repo "Description"
```

#### Registry not found
```bash
# Initialize registry
bash .aea/scripts/aea-registry.sh init

# Register current repo
bash .aea/scripts/aea-registry.sh register-current
```

---

### **Auto-Processing Issues**

#### Auto-processor not running
```bash
# 1. Check hooks are configured
cat .claude/settings.json

# Should show:
# "SessionStart": { "command": "bash .aea/scripts/aea-auto-processor.sh" }
# "Stop": { "command": "bash .aea/scripts/aea-auto-processor.sh" }

# 2. Test auto-processor manually
bash .aea/scripts/aea-auto-processor.sh

# 3. Check for errors
tail -20 .aea/agent.log
```

#### Messages escalated instead of auto-processed
```bash
# This is normal for:
# - Complex questions (requires code analysis)
# - High/urgent priority messages
# - Code change requests
# - Handoffs

# Simple queries should auto-process:
# - "What files contain X?"
# - "Where is Y?"
# - Status updates
```

#### "Rate limit reached" message
```bash
# Normal behavior - prevents Claude Code from hanging
# Max 10 messages per hook invocation
# Remaining messages processed on next hook trigger

# If you have many messages, process manually:
bash .aea/scripts/aea-auto-processor.sh
```

---

### **Messages not being processed**

```bash
# Check if monitor is running
bash .aea/scripts/aea-monitor.sh status

# Manually trigger check
bash .aea/scripts/aea-check.sh

# Check logs
tail -20 .aea/agent.log
```

### **Monitor won't start**

```bash
# Check for zombie processes
ps aux | grep aea-monitor

# Force kill old monitors
pkill -f aea-monitor.sh

# Remove stale PID from config
nano ~/.config/aea/projects.yaml
# Set job_pid to null

# Try starting again
bash .aea/scripts/aea-monitor.sh start
```

### **Health check failing**

```bash
# Check if monitor PID exists
ps -p <PID>

# Check monitor logs
tail -50 ~/.config/aea/monitor.log

# Restart monitor
bash .aea/scripts/aea-monitor.sh stop
bash .aea/scripts/aea-monitor.sh start
```

---

## 📖 **Documentation**

### Quick Links
- **[FAQ](docs/FAQ.md)** - Frequently asked questions
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Architecture](docs/ARCHITECTURE.md)** - How AEA works internally
- **[Examples](docs/EXAMPLES.md)** - Real-world usage examples
- **[Security](docs/SECURITY.md)** - Security considerations
- **[Installation Guide](INSTALL_GUIDE.md)** - Detailed installation instructions

### Technical References
- **[Protocol Specification](PROTOCOL.md)** - Message format and schema
- **[GitHub Integration](docs/GITHUB_INTEGRATION.md)** - GitHub Issues integration
- **[Global Command](docs/GLOBAL_COMMAND.md)** - Global 'a' command setup
- **[AEA Rules](docs/aea-rules.md)** - Complete protocol rules

### Configuration
- **`agent-config.yaml`** - Response policies and configuration
- **`.claude/settings.json`** - Hook configuration
- **`~/.config/aea/agents.yaml`** - Agent registry

---

## 🎉 **Summary**

You now have a **fully autonomous agent system** that:

1. ✅ **Auto-checks** for messages on every interaction
2. ✅ **Auto-responds** to safe messages (questions, updates)
3. ✅ **Requests approval** for risky operations
4. ✅ **Background monitors** for continuous operation
5. ✅ **Manages PIDs** with health checks
6. ✅ **Multi-project** support via central config

**Just run and forget:**
```bash
bash .aea/scripts/aea-monitor.sh start
```

Your agents will communicate autonomously! 🤖🚀
