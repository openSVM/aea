# AEA Protocol - Testing & Verification Guide

**How to test that AEA is working correctly**

This guide provides step-by-step tests to verify your AEA installation and functionality.

---

## 📋 Table of Contents

1. [Quick Health Check](#quick-health-check)
2. [Installation Verification](#installation-verification)
3. [Test Scenario 1: Send & Receive](#test-scenario-1-send--receive)
4. [Test Scenario 2: Auto-Processing](#test-scenario-2-auto-processing)
5. [Test Scenario 3: Hook Integration](#test-scenario-3-hook-integration)
6. [Test Scenario 4: Registry](#test-scenario-4-registry)
7. [Test Scenario 5: Message Validation](#test-scenario-5-message-validation)
8. [Automated Test Suite](#automated-test-suite)
9. [Troubleshooting Failed Tests](#troubleshooting-failed-tests)

---

## Quick Health Check

Run this 30-second health check:

```bash
# 1. Check AEA is installed
test -d .aea && echo "✅ AEA directory exists" || echo "❌ AEA not installed"

# 2. Check jq is available
which jq >/dev/null && echo "✅ jq is installed" || echo "❌ jq not found"

# 3. Check scripts are executable
test -x .aea/scripts/aea-check.sh && echo "✅ Scripts executable" || echo "❌ Scripts not executable"

# 4. Check registry exists
test -f ~/.config/aea/agents.yaml && echo "✅ Registry exists" || echo "❌ Registry not found"

# 5. Check hooks configured
grep -q "aea" .claude/settings.json 2>/dev/null && echo "✅ Hooks configured" || echo "⚠️ Hooks not found"
```

**Expected output:**
```
✅ AEA directory exists
✅ jq is installed
✅ Scripts executable
✅ Registry exists
✅ Hooks configured
```

If any fail, see [Troubleshooting](#troubleshooting-failed-tests).

---

## Installation Verification

### Test 1: Directory Structure

```bash
# Check all required files exist
echo "Checking directory structure..."

FILES=(
    ".aea/aea.sh"
    ".aea/agent-config.yaml"
    ".aea/CLAUDE.md"
    ".aea/PROTOCOL.md"
    ".aea/scripts/aea-check.sh"
    ".aea/scripts/aea-send.sh"
    ".aea/scripts/aea-registry.sh"
    ".aea/.processed"
)

for file in "${FILES[@]}"; do
    if [ -e "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file MISSING"
    fi
done
```

**Expected:** All ✅

### Test 2: Configuration

```bash
# Check agent-config.yaml is valid
echo "Testing configuration..."

# Extract agent ID
AGENT_ID=$(grep "^  id:" .aea/agent-config.yaml | sed 's/.*"\(.*\)".*/\1/')
echo "Agent ID: $AGENT_ID"

# Check policies exist
grep -q "policies:" .aea/agent-config.yaml && echo "✅ Policies configured" || echo "❌ Policies missing"

# Check auto_respond setting
grep -q "auto_respond:" .aea/agent-config.yaml && echo "✅ Auto-respond configured" || echo "❌ Auto-respond missing"
```

**Expected output:**
```
Agent ID: claude-your-repo-name
✅ Policies configured
✅ Auto-respond configured
```

### Test 3: Registry Access

```bash
# Test registry read/write
echo "Testing registry..."

# List agents
bash .aea/scripts/aea-registry.sh list

# Test adding/removing
bash .aea/scripts/aea-registry.sh register test-agent /tmp/test "Test" && echo "✅ Can write to registry" || echo "❌ Cannot write"
bash .aea/scripts/aea-registry.sh unregister test-agent && echo "✅ Can modify registry" || echo "❌ Cannot modify"
```

**Expected:** Successfully register and unregister test agent

---

## Test Scenario 1: Send & Receive

**Goal:** Verify basic message sending and receiving

### Setup

```bash
# Create two test directories
mkdir -p /tmp/aea-test-sender
mkdir -p /tmp/aea-test-receiver

# Install AEA in both
cd /tmp/aea-test-sender
bash /path/to/aea/scripts/install-aea.sh

cd /tmp/aea-test-receiver
bash /path/to/aea/scripts/install-aea.sh
```

### Step 1: Register Agents

```bash
# From sender, register receiver
cd /tmp/aea-test-sender
bash .aea/scripts/aea-registry.sh register receiver /tmp/aea-test-receiver "Test Receiver"

# From receiver, register sender
cd /tmp/aea-test-receiver
bash .aea/scripts/aea-registry.sh register sender /tmp/aea-test-sender "Test Sender"
```

**Verify:**
```bash
bash .aea/scripts/aea-registry.sh list | grep -q "receiver" && echo "✅ Receiver registered"
```

### Step 2: Send Test Message

```bash
cd /tmp/aea-test-sender

bash .aea/scripts/aea-send.sh \
  --to receiver \
  --type question \
  --priority normal \
  --subject "Test Message" \
  --message "This is a test. Please acknowledge."
```

**Expected output:**
```
✅ Message sent: .aea/message-TIMESTAMP-from-sender.json
```

**Verify message created:**
```bash
ls -la /tmp/aea-test-receiver/.aea/message-*.json
```

**Expected:** Should show 1 message file

### Step 3: Receive Message

```bash
cd /tmp/aea-test-receiver

bash .aea/scripts/aea-check.sh
```

**Expected output:**
```
📬 Found 1 unprocessed message(s):

  • message-TIMESTAMP-from-sender.json
    Type: question | Priority: normal | From: sender
    Subject: Test Message
```

### Step 4: Validate Message

```bash
bash .aea/scripts/aea-validate-message.sh .aea/message-*.json
```

**Expected:** No errors (exit code 0)

### Step 5: Mark as Processed

```bash
MESSAGE_FILE=$(ls .aea/message-*.json | head -1)
BASENAME=$(basename "$MESSAGE_FILE")
touch .aea/.processed/$BASENAME
```

**Verify:**
```bash
bash .aea/scripts/aea-check.sh
```

**Expected output:**
```
✅ No unprocessed messages
```

### ✅ Test Pass Criteria

- [x] Message file created in receiver directory
- [x] Message appears in check output
- [x] Message validates successfully
- [x] After marking processed, doesn't appear in check

---

## Test Scenario 2: Auto-Processing

**Goal:** Verify automatic message processing based on policies

### Step 1: Configure Auto-Respond

```bash
cd /tmp/aea-test-receiver

# Edit .aea/agent-config.yaml
cat >> .aea/agent-config.yaml << 'EOF'

policies:
  auto_respond:
    enabled: true
    message_types: [question, update]
    max_priority: normal
EOF
```

### Step 2: Send Auto-Processable Message

```bash
cd /tmp/aea-test-sender

bash .aea/scripts/aea-send.sh \
  --to receiver \
  --type question \
  --priority normal \
  --subject "Auto-process test" \
  --message "What is 2+2?"
```

### Step 3: Check Policy Decision

```bash
cd /tmp/aea-test-receiver

# This would normally be done by Claude, but we can test the detection
MESSAGE=$(ls .aea/message-*-from-sender.json | tail -1)

# Extract message details
TYPE=$(jq -r '.message_type' "$MESSAGE")
PRIORITY=$(jq -r '.routing.priority' "$MESSAGE")

echo "Type: $TYPE"
echo "Priority: $PRIORITY"

# Check if auto-processable
if [ "$TYPE" = "question" ] && [ "$PRIORITY" = "normal" ]; then
    echo "✅ Message should be auto-processed"
else
    echo "❌ Message should require approval"
fi
```

**Expected:**
```
Type: question
Priority: normal
✅ Message should be auto-processed
```

### Step 4: Send Non-Auto-Processable Message

```bash
cd /tmp/aea-test-sender

bash .aea/scripts/aea-send.sh \
  --to receiver \
  --type handoff \
  --priority high \
  --subject "Requires approval" \
  --message "Complex handoff requiring review"
```

**Verify:**
```bash
cd /tmp/aea-test-receiver
MESSAGE=$(ls .aea/message-*-from-sender.json | tail -1)
TYPE=$(jq -r '.message_type' "$MESSAGE")

if [ "$TYPE" = "handoff" ]; then
    echo "✅ Handoff type requires user approval (correct)"
else
    echo "❌ Unexpected type"
fi
```

### ✅ Test Pass Criteria

- [x] Question with normal priority identified as auto-processable
- [x] Handoff identified as requiring approval
- [x] Policy configuration loaded correctly

---

## Test Scenario 3: Hook Integration

**Goal:** Verify Claude Code hooks trigger correctly

### Step 1: Check Hook Configuration

```bash
cat .claude/settings.json | jq '.hooks'
```

**Expected output:**
```json
{
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
```

### Step 2: Test Hook Scripts Run

```bash
# Manually run each hook script
echo "Testing SessionStart hook..."
bash .aea/scripts/aea-auto-processor.sh 2>&1 | head -5

echo "Testing UserPromptSubmit hook..."
bash .aea/scripts/aea-check.sh 2>&1 | head -5

echo "Testing Stop hook..."
bash .aea/scripts/aea-auto-processor.sh 2>&1 | head -5
```

**Expected:** All scripts run without errors

### Step 3: Verify Log Entries

```bash
# Check that hook executions are logged
tail -20 .aea/agent.log | grep -i "check\|process"
```

**Expected:** See log entries from recent checks/processing

### ✅ Test Pass Criteria

- [x] Hooks configured in .claude/settings.json
- [x] Hook scripts exist and are executable
- [x] Scripts run without errors
- [x] Actions logged to agent.log

---

## Test Scenario 4: Registry

**Goal:** Verify agent registry functions correctly

### Test 1: Register Agent

```bash
bash .aea/scripts/aea-registry.sh register \
  test-repo \
  /tmp/test \
  "Test Repository"
```

**Verify:**
```bash
bash .aea/scripts/aea-registry.sh lookup test-repo
```

**Expected output:**
```
/tmp/test
```

### Test 2: List All Agents

```bash
bash .aea/scripts/aea-registry.sh list
```

**Expected:** Shows all registered agents including test-repo

### Test 3: Update Agent

```bash
bash .aea/scripts/aea-registry.sh register \
  test-repo \
  /tmp/test-updated \
  "Updated Description"
```

**Verify:**
```bash
bash .aea/scripts/aea-registry.sh lookup test-repo
```

**Expected:**
```
/tmp/test-updated
```

### Test 4: Unregister Agent

```bash
bash .aea/scripts/aea-registry.sh unregister test-repo
```

**Verify:**
```bash
bash .aea/scripts/aea-registry.sh lookup test-repo
```

**Expected:** Empty output or "not found"

### ✅ Test Pass Criteria

- [x] Can register new agent
- [x] Lookup returns correct path
- [x] Can update existing agent
- [x] Can unregister agent
- [x] Registry persists across commands

---

## Test Scenario 5: Message Validation

**Goal:** Verify message validation catches errors

### Test 1: Valid Message

```bash
cat > /tmp/valid-message.json << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_id": "test-123",
  "message_type": "question",
  "timestamp": "2025-10-25T12:00:00Z",
  "sender": {
    "agent_id": "test-sender"
  },
  "recipient": {
    "agent_id": "test-receiver"
  },
  "routing": {
    "priority": "normal",
    "requires_response": true
  },
  "content": {
    "subject": "Test",
    "body": "Test message"
  },
  "metadata": {
    "tags": ["test"]
  }
}
EOF

bash .aea/scripts/aea-validate-message.sh /tmp/valid-message.json
echo "Exit code: $?"
```

**Expected:** Exit code 0 (success)

### Test 2: Missing Required Field

```bash
cat > /tmp/invalid-message.json << 'EOF'
{
  "protocol_version": "0.1.0",
  "message_type": "question"
}
EOF

bash .aea/scripts/aea-validate-message.sh /tmp/invalid-message.json
```

**Expected:** Error message about missing `.message_id`

### Test 3: Invalid JSON

```bash
echo "{ invalid json" > /tmp/bad-json.json
bash .aea/scripts/aea-validate-message.sh /tmp/bad-json.json
```

**Expected:** JSON parse error

### Test 4: Wrong Protocol Version

```bash
cat > /tmp/wrong-version.json << 'EOF'
{
  "protocol_version": "99.99.99",
  "message_id": "test",
  "message_type": "question",
  "timestamp": "2025-10-25T12:00:00Z",
  "sender": {"agent_id": "test"},
  "recipient": {"agent_id": "test"},
  "routing": {"priority": "normal"},
  "content": {"subject": "test", "body": "test"}
}
EOF

bash .aea/scripts/aea-validate-message.sh /tmp/wrong-version.json
```

**Expected:** Warning about version mismatch (but may still validate)

### ✅ Test Pass Criteria

- [x] Valid message passes validation
- [x] Missing required field caught
- [x] Invalid JSON caught
- [x] Version mismatch detected

---

## Automated Test Suite

AEA includes an automated test suite for protocol features:

```bash
# Run all tests
bash .aea/aea.sh test

# Run specific test category
bash .aea/aea.sh test request-response
bash .aea/aea.sh test adaptive-retry
bash .aea/aea.sh test webhooks
bash .aea/aea.sh test partial-messages
bash .aea/aea.sh test multi-hop
```

**Expected output:**
```
╔════════════════════════════════════════╗
║   AEA v2.2 Feature Test Suite         ║
╚════════════════════════════════════════╝

═══ Test 1: Request/Response Correlation ═══
✓ 1.1: Register request
✓ 1.2: Match response to request
✓ 1.3: Prevent duplicate processing
✓ 1.4: Timeout detection

...

Tests Passed: 17/17

✓ All tests passed!
```

### Test Coverage

The automated suite tests:
- ✅ Request/Response correlation
- ✅ Adaptive retry backoff
- ✅ Webhook integration
- ✅ Partial message processing
- ✅ Multi-hop messaging

---

## Troubleshooting Failed Tests

### "AEA directory not found"

**Problem:** AEA not installed

**Solution:**
```bash
bash /path/to/aea/scripts/install-aea.sh
```

### "jq: command not found"

**Problem:** jq not installed

**Solution:**
```bash
# Debian/Ubuntu
sudo apt-get install jq

# macOS
brew install jq
```

### "Registry not found"

**Problem:** Registry not initialized

**Solution:**
```bash
mkdir -p ~/.config/aea
cat > ~/.config/aea/agents.yaml << 'EOF'
agents: {}
EOF
```

### "Message validation fails"

**Problem:** Message doesn't conform to protocol v0.1.0

**Solution:**
Check [PROTOCOL.md](../PROTOCOL.md) for correct schema. Common issues:
- Using `from` instead of `sender`
- Using `to` instead of `recipient`
- Missing `routing` object
- Using `message` instead of `content`

### "Hooks not triggering"

**Problem:** Claude Code not executing hooks

**Solution:**
1. Check `.claude/settings.json` exists and has hooks
2. Restart Claude Code session
3. Test hook scripts manually:
   ```bash
   bash .aea/scripts/aea-check.sh
   ```

---

## Cleanup After Testing

```bash
# Remove test directories
rm -rf /tmp/aea-test-sender /tmp/aea-test-receiver

# Remove test messages
rm -f /tmp/valid-message.json /tmp/invalid-message.json /tmp/bad-json.json /tmp/wrong-version.json

# Unregister test agents
bash .aea/scripts/aea-registry.sh unregister receiver
bash .aea/scripts/aea-registry.sh unregister sender
bash .aea/scripts/aea-registry.sh unregister test-repo
```

---

## Continuous Testing

Consider adding to CI/CD:

```yaml
# GitHub Actions example
name: Test AEA
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Install AEA
        run: bash scripts/install-aea.sh
      - name: Run test suite
        run: bash .aea/aea.sh test
```

---

## Summary Checklist

After running all tests, you should have verified:

- [ ] Installation complete with all files
- [ ] Configuration valid
- [ ] Registry read/write works
- [ ] Can send messages
- [ ] Can receive messages
- [ ] Message validation works
- [ ] Hooks configured
- [ ] Auto-processing policies work
- [ ] Automated test suite passes (17/17)

**If all checkboxes checked → AEA is fully operational!** ✅

---

## Further Reading

- **[Troubleshooting](TROUBLESHOOTING.md)** - Detailed problem solving
- **[FAQ](FAQ.md)** - Common questions
- **[Agent Guide](AGENT_GUIDE.md)** - How to use AEA as an agent
- **[Examples](EXAMPLES.md)** - Real-world scenarios

---

## 💬 Found an Issue?

If tests are failing or you've found a bug:

**[🐛 Report Bug](https://github.com/openSVM/aea/issues/new?template=bug_report.md)** - Use our bug report template

**[❓ Ask Question](https://github.com/openSVM/aea/issues/new?template=question.md)** - Get help with testing

**[📖 FAQ](FAQ.md)** - Check frequently asked questions first
