# Agentic Economic Activity (AEA) Protocol Rules

**Add these rules to your Claude Code, Cursor, Cline, or Roo Cody configuration to enable inter-agent messaging.**

---

## 🔔 **AUTOMATIC CHECK PROTOCOL - RUN ON EVERY INTERACTION**

### **PRIMARY METHOD (Automatic)**

**On EVERY user interaction, IMMEDIATELY run:**

```bash
# This MUST be the FIRST command in every session/interaction
bash .aea/scripts/aea-check.sh || cat .aea/prompts/check-messages.md
```

**If messages need processing:**
```bash
# Use the iterative processor for handling multiple messages
bash .aea/scripts/process-messages-iterative.sh
```

### **MANUAL FALLBACK METHOD**

If automatic checking isn't available:

1. **Check for the `.aea/` directory**
   ```bash
   ls -la .aea/ 2>/dev/null
   ```

2. **Look for unprocessed message files**
   ```bash
   ls -1t .aea/message-*.json 2>/dev/null | while read msg; do
       if [ ! -f ".aea/.processed/$(basename $msg)" ]; then
           echo "📬 New message: $(basename $msg)"
           cat "$msg" | jq '.'
       fi
   done
   ```

3. **Process based on message type and priority**

## 📋 **MESSAGE PROCESSING RULES**

### **Auto-Process Without Approval**
- ✅ `question` (any priority) → Search codebase → Answer → Send response
- ✅ `update` (normal priority) → Read → Acknowledge if `requires_response: true`
- ✅ `update` (high/urgent) → Summarize key points to user
- ✅ `issue` (low/medium) → Analyze → Suggest fix → Send response

### **Require User Approval**
- ❌ `issue` (high/urgent) → Notify user → Wait for approval before acting
- ❌ `handoff` (any priority) → Review with user → Get approval
- ❌ `request` (any priority) → Evaluate → Present plan → Get approval
- ❌ Any message requiring code changes → Always get approval first

---

## 📤 **SENDING MESSAGES TO OTHER AGENTS**

**When to send messages:**

- ✅ Completing integration work across repositories
- ✅ Handing off responsibility to another codebase
- ✅ Asking questions about dependencies
- ✅ Reporting bugs that affect other repos
- ✅ Sharing important updates or changes

**How to send a message:**

1. **Create `.aea/` directory in target repository**
   ```bash
   mkdir -p /path/to/other/repo/.aea/
   ```

2. **Generate timestamp**
   ```bash
   date -u +"%Y%m%dT%H%M%SZ"
   # Example: 20251013T163529Z
   ```

3. **Create message file**
   ```bash
   # Naming: message-{TIMESTAMP}-from-{YOUR_ID}.json
   cat > /path/to/other/repo/.aea/message-20251013T163529Z-from-claude-yourrepo.json
   ```

4. **Use standard JSON structure** (see below)

---

## 📋 **MESSAGE JSON STRUCTURE**

```json
{
  "protocol_version": "1.0",
  "message_type": "handoff|question|issue|update|request|response",
  "timestamp": "2025-10-13T16:35:29Z",

  "from": {
    "agent_id": "claude-your-repo-name",
    "agent_type": "claude-sonnet-4.5",
    "role": "Your role description",
    "context": "/absolute/path/to/your/repo",
    "expertise": ["skill1", "skill2"]
  },

  "to": {
    "agent_id": "claude-target-repo|any-claude-instance",
    "role": "Expected recipient role",
    "context": "/absolute/path/to/target/repo"
  },

  "priority": "low|normal|high|urgent",
  "requires_response": true|false,
  "in_reply_to": "message-TIMESTAMP-from-SENDER.json",

  "message": {
    "subject": "Brief subject line",
    "summary": "One paragraph summary",
    "body": {
      "what_was_built": "Detailed description",
      "how_to_use": "Step-by-step instructions",
      "next_steps": "What needs to happen next",
      "files_created": ["file1.cpp", "file2.hpp"],
      "documentation": ["/path/to/doc1.md"]
    }
  },

  "metadata": {
    "code_written": "500 lines",
    "session_time": "5 hours",
    "status": "complete|in-progress|blocked"
  }
}
```

---

## 🎯 **MESSAGE TYPES QUICK REFERENCE**

| Type | When to Use | Required Fields | Auto-Process |
|------|-------------|-----------------|--------------|
| **handoff** | Transferring responsibility | `what_was_built`, `how_to_use`, `next_steps` | ❌ Requires approval |
| **question** | Need information/clarification | `question`, `context`, `requires_response: true` | ✅ Auto-respond |
| **issue** | Report bug or problem | `issue_description`, `severity`, `reproduction_steps` | ⚠️ Depends on priority |
| **update** | Share progress/status | `update_summary`, `changes_made` | ✅ Auto-acknowledge |
| **request** | Ask for work to be done | `request_details`, `why_needed` | ❌ Requires approval |
| **response** | Reply to previous message | `in_reply_to`, `response_to_what` | ✅ Auto-process |

## 📊 **COMPLETE PROCESSING POLICY TABLE**

| Message Type | Priority | Auto-Action | Description |
|-------------|----------|-------------|-------------|
| `question` | Any | ✅ Yes | Search code → Answer → Send response |
| `update` | Normal | ✅ Yes | Read → Acknowledge if needed |
| `update` | High/Urgent | ✅ Yes | Summarize key points to user |
| `issue` | Low/Medium | ✅ Yes | Analyze → Suggest fix → Respond |
| `issue` | High/Urgent | ❌ No | Notify user → Wait for approval |
| `handoff` | Any | ❌ No | Review → Request user approval |
| `request` | Any | ❌ No | Evaluate → Present plan to user |
| `response` | Any | ✅ Yes | Process → Update context |

---

## ✅ **REQUIRED ACTIONS**

### **CRITICAL: Every Interaction Start**

```bash
# THIS IS MANDATORY - Run at the beginning of EVERY user interaction:
bash .aea/scripts/aea-check.sh || cat .aea/prompts/check-messages.md
```

### **Processing Workflow**

1. **Automatic Check** (runs via script above)
   - Scans for unprocessed messages
   - Applies policy from agent-config.yaml
   - Auto-responds to safe messages
   - Flags risky messages for approval

2. **If Messages Found**
   ```bash
   # For multiple messages or interactive processing:
   bash .aea/scripts/process-messages-iterative.sh
   ```

3. **Mark as Processed**
   ```bash
   touch .aea/.processed/$(basename $message_file)
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed: $type from $sender" >> .aea/agent.log
   ```

### **Before Ending Session (if you did significant work)**

```
1. Consider if other repos need to know
2. Create handoff message if appropriate
3. Include all necessary context
4. Reference created files with absolute paths
```

### **When Creating Response Messages**

```bash
# Generate timestamp
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

# Create message in target repo
cat > /path/to/target/repo/.aea/message-${TIMESTAMP}-from-{YOUR_AGENT_ID}.json << 'EOF'
{
  "protocol_version": "1.0",
  "message_type": "response",
  "from": {"agent_id": "{YOUR_AGENT_ID}"},
  ...
}
EOF
```

---

## 🔍 **DETECTION CHECKLIST**

Add to your startup routine:

```python
# Pseudo-code for agent startup
def on_session_start():
    if directory_exists(".aea"):
        messages = list_files(".aea/message-*.json")

        if messages:
            print("📬 Inter-agent messages found:")
            for msg in messages:
                content = read_json(msg)
                print(f"  - From: {content['from']['agent_id']}")
                print(f"    Subject: {content['message']['subject']}")
                print(f"    Type: {content['message_type']}")

            print("\n🔍 Processing messages...")
            for msg in messages:
                process_message(msg)
```

---

## 💡 **EXAMPLES**

### **Example 1: Reading a Handoff Message**

When you start and find `.aea/message-20251013T163529Z-from-claude-module-dev.json`:

```markdown
**Response to user:**

"📬 Found inter-agent message from claude-module-dev (2025-10-13)

**Subject**: API Module Integration Complete - Production Ready

**Summary**: Complete integration of API module into this repository.
All code compiled (ApiHandler.cpp, 508 lines), tested, and ready for use.

**Key Points**:
- Files created: src/handlers/api_handler.{hpp,cpp}
- Endpoint: api-server-prod:8080
- Status: 100% complete, production-ready

**Next Steps**:
1. Review integration code (5-10 min)
2. Read HOW_IT_WORKS.md
3. Initialize ApiHandler in main.cpp
4. Wire up request handlers
5. Test with live traffic

Would you like me to proceed with the integration?"
```

### **Example 2: Sending a Question**

When you need to ask another agent something:

```bash
# Create message file
cat > /path/to/other-repo/.aea/message-$(date -u +%Y%m%dT%H%M%SZ)-from-claude-my-app.json << 'EOF'
{
  "protocol_version": "1.0",
  "message_type": "question",
  "requires_response": true,
  "timestamp": "2025-10-13T18:00:00Z",

  "from": {
    "agent_id": "claude-my-app",
    "context": "/path/to/my/app"
  },

  "to": {
    "agent_id": "claude-other-repo",
    "context": "/path/to/other-repo"
  },

  "message": {
    "subject": "Question about optimal batch_size",
    "question": "What's the recommended batch_size for 50,000 updates/sec throughput?",
    "context": "Currently using batch_size=100, interval=100ms. Seeing 200ms latency.",
    "current_config": {
      "batch_size": 100,
      "batch_interval": "100ms",
      "pool_size": 10
    }
  }
}
EOF
```

### **Example 3: Reporting an Issue**

When you find a bug that affects another repository:

```json
{
  "protocol_version": "1.0",
  "message_type": "issue",
  "priority": "high",
  "timestamp": "2025-10-13T19:00:00Z",

  "from": {
    "agent_id": "claude-my-app"
  },

  "to": {
    "agent_id": "claude-other-repo"
  },

  "message": {
    "subject": "Memory leak in executeBatch()",
    "issue_description": "Memory grows by 1MB/min during high load",
    "severity": "high",
    "reproduction_steps": [
      "1. Run application with 10,000 updates/sec",
      "2. Monitor with: watch -n 1 'ps aux | grep myapp'",
      "3. Observe memory growth over 1 hour"
    ],
    "suspected_cause": "Response objects not freed in loop",
    "proposed_fix": "Add cleanup after each request()"
  }
}
```

---

## 🚨 **CRITICAL RULES**

### **DO**

✅ **Check `.aea/` directory on EVERY session start**
✅ **Read and acknowledge ALL messages found**
✅ **Use absolute paths (never relative)**
✅ **Include comprehensive context in messages**
✅ **Inform user when sending/receiving messages**
✅ **Copy PROTOCOL.md to new `.aea/` directories**

### **DON'T**

❌ **Ignore the `.aea/` directory**
❌ **Skip reading messages to save time**
❌ **Assume messages don't apply to you**
❌ **Send messages without user awareness**
❌ **Include sensitive data (passwords, keys, PII)**
❌ **Use relative paths or vague references**

---

## 📚 **FULL PROTOCOL DOCUMENTATION**

For complete details, see: `.aea/PROTOCOL.md` in this repository

Topics covered:
- Complete JSON schema
- All message types with examples
- Discovery protocol
- Threading and multi-cast
- Status tracking
- Advanced features

---

## 🔄 **INTEGRATION CHECKLIST**

Add this to your agent configuration:

- [ ] Check for `.aea/` on every session start
- [ ] Read all `message-*.json` files if present
- [ ] Inform user about messages found
- [ ] Act on message content appropriately
- [ ] Create messages when doing cross-repo work
- [ ] Use standard JSON structure
- [ ] Include absolute paths
- [ ] Reference this protocol

---

## 🎓 **QUICK START FOR NEW AGENTS**

**First time seeing `.aea/` directory?**

1. Read `.aea/PROTOCOL.md` for full details
2. Check for message files: `ls .aea/message-*.json`
3. Read any messages found
4. Acknowledge to user
5. Follow instructions in message content
6. Create response if `requires_response: true`

**Need to send a message?**

1. Use template from "MESSAGE JSON STRUCTURE" above
2. Generate timestamp: `date -u +%Y%m%dT%H%M%SZ`
3. Create file: `message-{TIMESTAMP}-from-{YOUR_ID}.json`
4. Include all necessary context
5. Copy `.aea/PROTOCOL.md` if creating new `.aea/` directory

---

## 📞 **COMMON SCENARIOS**

### **Scenario 1: Starting work, found messages**

```
User: "Help me with X"
Agent:
  1. Check .aea/
  2. Found messages
  3. Read and summarize for user
  4. Ask if user wants to follow message instructions
```

### **Scenario 2: Completing integration work**

```
Agent completes major work across repos:
  1. Ask user: "Should I notify the other repository's agent?"
  2. If yes, create handoff message
  3. Include what was built, how to use, next steps
  4. Inform user message was sent
```

### **Scenario 3: Need info from another agent**

```
Agent blocked by missing information:
  1. Identify which repo has the info
  2. Create question message
  3. Set requires_response: true
  4. Inform user question was sent
  5. Continue with other work if possible
```

---

## ✅ **IMPLEMENTATION**

### **For Claude Code (.claude/claude.md or CLAUDE.md)**

Add this section:

```markdown
## Inter-Agent Communication (AEA Protocol)

**CRITICAL: On EVERY user interaction, IMMEDIATELY run:**
```bash
bash .aea/scripts/aea-check.sh || cat .aea/prompts/check-messages.md
```

This repository uses the AEA protocol for async agent-to-agent communication.

**Message Processing Rules:**
- Auto-process: questions, normal updates, low/medium issues
- Require approval: high/urgent issues, handoffs, requests, code changes

**For multiple messages:** Use `bash .aea/scripts/process-messages-iterative.sh`

See: `.aea/aea-rules.md` for complete protocol documentation.
```

### **For Cursor (.cursorrules)**

Add:

```
# Inter-Agent Communication
- ALWAYS run first: bash .aea/scripts/aea-check.sh
- Auto-process safe messages (questions, updates)
- Get approval for risky messages (handoffs, urgent issues)
- Use .aea/scripts/process-messages-iterative.sh for multiple messages
- See .aea/aea-rules.md for complete protocol
```

### **For Cline/Roo Cody**

Add to project rules:

```
MANDATORY: Run "bash .aea/scripts/aea-check.sh" at start of every interaction.
Auto-process questions and updates, get approval for handoffs and urgent issues.
Use .aea/scripts/process-messages-iterative.sh for batch processing.
Follow .aea/aea-rules.md protocol for all AEA communications.
```

---

## 🎯 **TL;DR - MINIMAL RULES**

**Absolute minimum to add to your agent rules:**

```
1. MANDATORY: Run "bash .aea/scripts/aea-check.sh" at start of EVERY interaction
2. Auto-process: questions, normal updates, low/medium issues
3. Get approval: high/urgent issues, handoffs, requests, code changes
4. For multiple messages: Use .aea/scripts/process-messages-iterative.sh
5. Mark processed: touch .aea/.processed/$(basename $message_file)
6. Log actions: echo "[timestamp] action" >> .aea/agent.log
7. When doing cross-repo work: Consider sending handoff message
8. Always use absolute paths in messages
```

### **The ONE Command You Must Remember:**

```bash
# Run this FIRST in EVERY interaction:
bash .aea/scripts/aea-check.sh || cat .aea/prompts/check-messages.md
```

---

**That's it! Copy these rules to your agent configuration to enable inter-agent communication.**

For questions or updates to this protocol: Create a message in the appropriate `.aea/` directory.
