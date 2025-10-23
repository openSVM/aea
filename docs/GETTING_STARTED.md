# AEA - Getting Started Guide

## 🚀 Installation

### Option 1: One-Line Install (Current Directory)
```bash
bash <(curl -fsSL https://your-url/install-aea.sh)
```

### Option 2: Install to Specific Directory
```bash
curl -fsSL https://your-url/install-aea.sh -o install-aea.sh
chmod +x install-aea.sh
./install-aea.sh ~/my/project
```

### Option 3: From Local Repository
```bash
# Install in current directory
bash /path/to/repo-a/.aea/scripts/install-aea.sh

# Install in another directory
bash /path/to/repo-a/.aea/scripts/install-aea.sh ~/other/project
```

## ✅ Verify Installation

```bash
# Check directory structure
tree -L 3 .aea/ .claude/

# Test message checking
bash .aea/scripts/aea-check.sh

# View configuration
cat .aea/agent-config.yaml
```

## 📚 Quick Reference

### Core Concept

AEA enables Claude agents in different repositories to:
- 🤖 **Communicate asynchronously** via JSON message files
- 🔄 **Auto-process** safe operations (questions, analysis, documentation)
- ⚠️ **Request approval** for risky operations (code changes, deployments)
- 📝 **Log everything** for audit trails

### Message Types

| Type | Description | Auto-Response |
|------|-------------|---------------|
| **question** | Technical questions | ✅ Auto-responds |
| **update** | Status updates | ✅ Acknowledges |
| **issue** (low/med) | Bug reports | ✅ Analyzes & suggests fix |
| **issue** (high/urgent) | Critical bugs | ❌ Requires approval |
| **handoff** | Integration work | ❌ Requires approval |
| **request** | Feature requests | ✅ Responds with plan |

### Priority Levels

- **low**: Non-urgent, informational
- **normal**: Standard priority (default)
- **high**: Important, needs attention
- **urgent**: Critical, immediate action needed

## 🎯 Common Workflows

### 1. Check for Messages

**In Claude:**
```
/aea
```

**In Terminal:**
```bash
bash .aea/scripts/aea-check.sh
```

### 2. Send a Message

**Simple Question:**
```bash
.aea/scripts/aea-send.sh \
  --to claude-other-repo \
  --to-path /path/to/repo \
  --type question \
  --subject "How to optimize X?" \
  --message "Detailed question here..."
```

**Urgent Issue:**
```bash
.aea/scripts/aea-send.sh \
  --to claude-aea \
  --to-path /path/to/repo-a \
  --type issue \
  --priority urgent \
  --subject "🚨 Memory leak in production" \
  --message "Critical issue details..."
```

**Status Update:**
```bash
.aea/scripts/aea-send.sh \
  --to claude-agent-1 \
  --to-path /path/to/repo-b \
  --type update \
  --priority normal \
  --requires-response false \
  --subject "Deployed v2.1.0" \
  --message "Successfully deployed to staging..."
```

### 3. Background Monitoring

**Start Monitor:**
```bash
.aea/scripts/aea-monitor.sh start
```

**Check Status:**
```bash
.aea/scripts/aea-monitor.sh status
```

**Stop Monitor:**
```bash
.aea/scripts/aea-monitor.sh stop
```

## 🧪 Testing

### Create Test Scenarios

```bash
# Create all test scenarios
bash .aea/scripts/create-test-scenarios.sh all

# Create specific scenario
bash .aea/scripts/create-test-scenarios.sh urgent-issue
bash .aea/scripts/create-test-scenarios.sh simple-question
bash .aea/scripts/create-test-scenarios.sh handoff
```

### Test Auto-Response Flow

1. **Create simple question:**
   ```bash
   bash .aea/scripts/create-test-scenarios.sh simple-question
   ```

2. **Trigger processing:**
   ```
   /aea
   ```

3. **Expected:** Claude automatically:
   - Searches codebase for answer
   - Generates technical response
   - Creates response message
   - Marks original as processed

### Test Approval Flow

1. **Create urgent issue:**
   ```bash
   bash .aea/scripts/create-test-scenarios.sh urgent-issue
   ```

2. **Trigger processing:**
   ```
   /aea
   ```

3. **Expected:** Claude:
   - Reads urgent issue
   - Notifies you with summary
   - Asks: "Should I analyze and propose a fix?"
   - Waits for your approval

## 📖 Understanding Response Policies

Edit `.aea/agent-config.yaml` to customize behavior:

```yaml
response_policy:
  question:
    auto_respond: true          # ✅ Auto-process
    approval_required: false
    actions:
      - search_codebase
      - analyze_code
      - provide_answer
      - send_response

  issue:
    urgent:
      auto_respond: false        # ❌ Ask first
      approval_required: true
      actions:
        - analyze_issue
        - notify_user
        - wait_for_approval
```

## 🔍 Monitoring & Debugging

### View Logs

```bash
# Tail logs in real-time
tail -f .aea/agent.log

# View recent activity
tail -50 .aea/agent.log

# Search logs
grep "message_type" .aea/agent.log
```

### Check Processed Messages

```bash
# List all processed messages
ls -1 .aea/.processed/

# Check if specific message was processed
ls -1 .aea/.processed/message-20251014T*.json
```

### Debug Message Processing

```bash
# List all messages
ls -1 .aea/message-*.json

# Read specific message
cat .aea/message-20251014T135220Z-from-claude-test-urgent.json | jq

# Check message details
jq '.message_type, .priority, .from.agent_id' .aea/message-*.json
```

## 🔧 Configuration

### Agent Identity

Edit `.aea/agent-config.yaml`:

```yaml
agent:
  id: "claude-myrepo"                    # Change this
  name: "My Project Agent"
  description: "Custom description"
  capabilities:
    - code_analysis
    - documentation
    - testing
    - your_custom_capability
```

### Response Policies

Customize how messages are handled:

```yaml
response_policy:
  question:
    auto_respond: true                    # Change to false to require approval
  issue:
    high:
      auto_respond: false                # Change to true to auto-process
      approval_required: true            # Change to false to skip approval
```

### Monitoring

```yaml
monitoring:
  enabled: true
  log_file: ".aea/agent.log"
  check_interval: 60                    # Change to 30 for more frequent checks
```

## 📁 File Organization

```
.aea/
├── agent-config.yaml          # Your configuration
├── aea-rules.md               # Protocol specification
├── README.md                  # Quick reference
├── agent.log                  # Activity log
├── prompts/
│   └── check-messages.md      # Auto-check prompt
├── scripts/
│   ├── aea-check.sh           # Check for messages
│   ├── aea-send.sh            # Send messages
│   ├── aea-monitor.sh         # Background monitor
│   ├── create-test-scenarios.sh # Test message creator
│   └── install-aea.sh         # Installer
├── message-*.json             # Incoming messages
└── .processed/
    └── message-*.json         # Processed markers

.claude/
└── commands/
    └── aea.md                 # /aea slash command

CLAUDE.md                      # Project instructions (includes AEA section)
```

## 🚦 Best Practices

### 1. Message Subjects

✅ **Good:**
```
"How to configure connection pool for 10k updates/sec?"
"🚨 URGENT: Memory leak in production"
"Deployed v2.1.0 to staging - tests passing"
```

❌ **Bad:**
```
"Question"
"Problem"
"Update"
```

### 2. Include Context

✅ **Good:**
```json
"context": {
  "current_throughput": "10k updates/sec",
  "target_throughput": "50k updates/sec",
  "batch_size": 100
}
```

❌ **Bad:**
```json
"context": {}
```

### 3. Set Appropriate Priority

- Use **urgent** only for production issues
- Use **high** for important but not critical
- Use **normal** for standard questions/updates
- Use **low** for informational FYIs

### 4. Require Response When Needed

```bash
# When you need acknowledgment
--requires-response true

# For informational updates
--requires-response false
```

## 🔗 Integration Examples

### Integration with repo-b

```bash
# From repo-b, ask repo-a about performance
.aea/scripts/aea-send.sh \
  --to claude-aea \
  --to-path /path/to/repo-a \
  --type question \
  --subject "Recommended pool_size for 10k updates/sec?" \
  --message "What connection pool size should we use?"

# From repo-a, notify repo-b of changes
.aea/scripts/aea-send.sh \
  --to claude-repo-b \
  --to-path /path/to/repo-b \
  --type update \
  --subject "Added batch API support" \
  --message "New ORDERBOOKMAP.BATCH.INSERT command available..."
```

### Cross-Repository Workflow

1. **repo-b** implements client-side batch logic
2. Sends **handoff** message to **repo-a**
3. **repo-a** agent reads message
4. Notifies user: "Integration ready, should I implement server-side?"
5. User approves
6. **repo-a** implements server-side batch API
7. Sends **update** message back to **repo-b**
8. **repo-b** agent auto-acknowledges
9. User tests end-to-end integration

## 🆘 Troubleshooting

### Messages Not Being Detected

```bash
# Check if messages exist
ls -1 .aea/message-*.json

# Verify .aea directory structure
tree .aea/

# Check permissions
ls -la .aea/scripts/

# Run check script manually
bash -x .aea/scripts/aea-check.sh
```

### Scripts Not Executable

```bash
chmod +x .aea/scripts/*.sh
```

### /aea Command Not Working

```bash
# Verify slash command file exists
cat .claude/commands/aea.md

# Restart Claude Code if needed
```

### Background Monitor Not Starting

```bash
# Check if already running
.aea/scripts/aea-monitor.sh status

# Stop old instance
.aea/scripts/aea-monitor.sh stop

# Start fresh
.aea/scripts/aea-monitor.sh start

# Check logs
tail -f .aea/agent.log
```

## 📚 Further Reading

- **Complete Protocol**: `.aea/aea-rules.md`
- **Quick Reference**: `.aea/README.md`
- **Configuration**: `.aea/agent-config.yaml`
- **Examples**: `.aea/scripts/create-test-scenarios.sh`
- **Installer**: `.aea/INSTALLER_README.md`

## 💡 Tips

1. **Check messages regularly** - Add to your workflow
2. **Use descriptive subjects** - Makes scanning easier
3. **Include context** - Helps agents auto-process
4. **Tag related messages** - Use `conversation_id`
5. **Clean up old messages** - Archive after 30 days
6. **Monitor logs** - Watch `.aea/agent.log`
7. **Test scenarios** - Use test scripts before production

## 🎉 Ready to Go!

You're all set! Start by:

1. Creating a test scenario:
   ```bash
   bash .aea/scripts/create-test-scenarios.sh simple-question
   ```

2. Triggering Claude to process it:
   ```
   /aea
   ```

3. Watching the magic happen! ✨

Happy collaborating! 🤖🤝🤖
