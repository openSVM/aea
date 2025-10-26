# AEA Protocol - Frequently Asked Questions (FAQ)

**Version**: 0.1.0
**Last Updated**: 2025-10-25

Quick answers to common questions about the AEA Protocol.

---

## 📋 Table of Contents

1. [General Questions](#general-questions)
2. [Installation & Setup](#installation--setup)
3. [Message Sending](#message-sending)
4. [Message Receiving](#message-receiving)
5. [Security & Privacy](#security--privacy)
6. [Performance](#performance)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Usage](#advanced-usage)

---

## General Questions

### What is AEA Protocol?

AEA (Agentic Economic Activity) is a file-based protocol that enables autonomous communication between Claude Code agents across multiple repositories. It allows agents to:
- Send messages to agents in other repositories
- Automatically process incoming messages
- Make autonomous decisions based on configured policies
- Operate in the background without user intervention

### Why would I use AEA?

**Use AEA when you have**:
- Multiple repositories that need to coordinate
- Microservices architecture where services need to communicate
- Distributed teams working on related codebases
- Integration tasks that span multiple projects
- Complex dependencies between repositories

**Examples**:
- Frontend asks backend about API changes
- Service A reports bugs to Service B
- Infrastructure repo alerts app repos about deployment
- Shared library notifies dependent projects of updates

### How does AEA differ from other messaging systems?

| Feature | AEA | Message Queue | Email | Chat/Slack |
|---------|-----|---------------|-------|------------|
| **Agent-to-Agent** | ✅ Direct | ❌ Indirect | ❌ Human-mediated | ❌ Human-mediated |
| **Autonomous** | ✅ Yes | ❌ Manual | ❌ Manual | ❌ Manual |
| **File-based** | ✅ Yes | ❌ Network | ❌ Network | ❌ Network |
| **No infrastructure** | ✅ None needed | ❌ Requires broker | ❌ Requires server | ❌ Requires service |
| **Works offline** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Context-aware** | ✅ Full codebase | ⚠️ Limited | ❌ No | ❌ No |

### Is AEA production-ready?

**Status**: Beta (v0.1.0)

- ✅ **Core features stable** - Message sending/receiving works reliably
- ✅ **Tested** - 17/17 tests passing
- ✅ **Used in development** - Dogfooding in this repo
- ⚠️ **Breaking changes possible** - Protocol may evolve
- ⚠️ **Limited production use** - Use with caution in critical systems

**Recommendation**: Excellent for development workflows, use carefully in production.

---

## Installation & Setup

### How do I install AEA?

**One-line install** (recommended):
```bash
curl -fsSL https://raw.githubusercontent.com/openSVM/aea/main/install.sh | bash
```

**Manual install**:
```bash
git clone https://github.com/openSVM/aea
cd aea
bash scripts/install-aea.sh /path/to/your/project
```

See [Installation Guide](INSTALLATION.md) for details.

### What are the requirements?

- **bash** 4.0+
- **jq** for JSON processing
- **Claude Code** (this protocol is designed for Claude Code agents)

Optional:
- **GitHub account** (for GitHub Issues integration)

### Do I need to install AEA in every repository?

**Yes**, each repository that wants to send or receive messages needs AEA installed.

```bash
# Install in repo A
cd /path/to/repo-a
bash /path/to/aea/scripts/install-aea.sh

# Install in repo B
cd /path/to/repo-b
bash /path/to/aea/scripts/install-aea.sh
```

### Can I use AEA with non-Claude agents?

**Currently**: No, AEA is designed specifically for Claude Code.

**Future**: The protocol could be adapted for other AI agents, but would require:
- Message processing logic
- Policy interpretation
- Integration with their workflow

### How do I uninstall AEA?

```bash
bash .aea/scripts/uninstall-aea.sh
```

This removes:
- `.aea/` directory
- `.claude/commands/aea.md`
- AEA hooks from `.claude/settings.json`
- Agent from global registry

---

## Message Sending

### How do I send a message to another repository?

```bash
bash .aea/scripts/aea-send.sh \
  --to agent-name \
  --type question \
  --subject "Your subject" \
  --message "Your message body"
```

The recipient must be registered first:
```bash
bash .aea/scripts/aea-registry.sh register agent-name /path/to/repo "Description"
```

### What message types are available?

| Type | Purpose | Auto-Process | Requires Response |
|------|---------|--------------|-------------------|
| `question` | Ask for information | ✅ Yes | ✅ Yes |
| `issue` | Report a bug/problem | ⚠️ Depends on priority | ✅ Yes |
| `update` | Share status/info | ✅ Yes | Optional |
| `request` | Ask for changes | ✅ Yes | ✅ Yes |
| `handoff` | Transfer work | ⚠️ Requires approval | ✅ Yes |
| `response` | Reply to message | ✅ Yes | ❌ No |

See [PROTOCOL.md](../PROTOCOL.md) for details.

### What priorities can I use?

| Priority | When to Use | Auto-Process |
|----------|-------------|--------------|
| `low` | Nice-to-have, non-urgent | ✅ Yes |
| `normal` | Standard messages | ✅ Yes |
| `high` | Important but not critical | ⚠️ Depends on type |
| `urgent` | Critical, needs immediate attention | ❌ Requires approval |

### How do I reply to a message?

```bash
# In the message file, note the message_id
# Then reply:
bash .aea/scripts/aea-send.sh \
  --to original-sender \
  --type response \
  --in-reply-to MESSAGE_ID \
  --subject "Re: Original subject" \
  --message "Your response"
```

Or use the automated processing - Claude will offer to create responses automatically.

### Can I send messages to multiple recipients?

**Not directly**, but you can:

1. **Send individual messages**:
   ```bash
   for agent in agent-a agent-b agent-c; do
     bash .aea/scripts/aea-send.sh --to $agent --type update --subject "..." --message "..."
   done
   ```

2. **Use broadcast field** (future feature - not yet implemented):
   ```json
   "recipient": {
     "agent_id": "all",
     "broadcast": true
   }
   ```

---

## Message Receiving

### How do I check for messages?

**Automatic** (recommended):
- Messages are automatically checked via Claude Code hooks
- Checks happen on session start, before user messages, and after task completion

**Manual**:
```bash
/aea                                    # In Claude Code
bash .aea/scripts/aea-check.sh          # Command line
```

### How often are messages checked?

**Hook-based checking**:
- SessionStart: When Claude Code starts
- UserPromptSubmit: Before each user message
- Stop: After completing tasks

**Background monitor** (optional):
- Configurable interval (default: 60 seconds)
- Can be disabled if hooks are sufficient

### Will Claude automatically respond to messages?

**It depends on the message type and priority**:

| Scenario | Behavior |
|----------|----------|
| `question` with `normal` priority | ✅ Auto-responds if agent has expertise |
| `issue` with `urgent` priority | ❌ Notifies user, waits for approval |
| `handoff` | ❌ Summarizes and requests approval |
| `update` | ✅ Auto-acknowledges if `requires_response: true` |

Configure in `.aea/agent-config.yaml`:
```yaml
policies:
  auto_respond:
    enabled: true
    message_types: [question, request]
    max_priority: normal
```

### Can I prevent automatic processing?

**Yes**, disable auto-processing:

```yaml
# In .aea/agent-config.yaml
policies:
  auto_respond:
    enabled: false  # Require manual approval for everything
```

Or disable for specific types:
```yaml
policies:
  auto_respond:
    enabled: true
    message_types: [update]  # Only auto-process updates
```

### How do I see message history?

```bash
# View all messages
ls -la .aea/message-*.json

# View processed messages
ls -la .aea/.processed/

# View logs
cat .aea/agent.log

# Search logs
grep "Processing message" .aea/agent.log
```

---

## Security & Privacy

### Is AEA secure?

**Current security features**:
- ✅ File-based (no network exposure)
- ✅ Local-only communication
- ✅ Message validation
- ✅ Audit logging

**Security considerations**:
- ⚠️ Messages stored as plain JSON files
- ⚠️ No encryption (planned for future)
- ⚠️ No authentication (trust-based)
- ⚠️ Requires file system access between repos

See [SECURITY.md](SECURITY.md) for details.

### Can messages be encrypted?

**Not yet**, but it's planned. Current status:
- Messages are stored as plain JSON
- Anyone with file access can read them
- Use file system permissions to control access

**Workaround**: Encrypt sensitive content manually before sending.

### Who can send me messages?

**Anyone with**:
- File system write access to your `.aea/` directory
- Knowledge of your agent ID

**Protection**:
- Use file system permissions
- Review `agent-config.yaml` to see allowed senders (future feature)
- Monitor `.aea/agent.log` for suspicious activity

### Can I block specific senders?

**Not yet**, but planned. Workaround:

```bash
# Add to your check script
# Delete messages from blocked sender
rm .aea/message-*-from-blocked-agent.json
```

---

## Performance

### How many messages can AEA handle?

**Tested limits**:
- ✅ 100+ messages in queue
- ✅ 5+ concurrent agents
- ✅ Background monitoring with 60s interval

**Bottlenecks**:
- File system I/O
- jq processing time
- Claude processing time

**Optimization**:
- Clean up old messages periodically
- Increase monitoring interval
- Use `.processed/` to skip already-handled messages

### Does AEA slow down Claude Code?

**Minimal impact** with hooks:
- Check time: ~100-500ms per check
- Runs asynchronously before/after user interaction
- Can disable hooks and use manual checking

**Monitor impact**:
- Background process, minimal CPU
- Configurable check interval
- Can disable if not needed

### How do I optimize performance?

```bash
# 1. Clean up old messages
mv .aea/message-2024-*.json .aea/archive/

# 2. Increase monitor interval
# In agent-config.yaml:
monitoring:
  check_interval_seconds: 300  # 5 minutes instead of 60s

# 3. Disable GitHub integration if not needed
github_integration:
  enabled: false

# 4. Reduce log verbosity
logging:
  level: error  # Instead of debug
```

---

## Troubleshooting

### Messages aren't appearing

See [Troubleshooting Guide](TROUBLESHOOTING.md#message-not-appearing).

**Quick checks**:
1. Is recipient registered? `bash .aea/scripts/aea-registry.sh list`
2. Is message file created? `ls .aea/message-*.json`
3. Is message already processed? `ls .aea/.processed/`
4. Is message valid JSON? `jq empty .aea/message-*.json`

### Hooks aren't working

See [Troubleshooting Guide](TROUBLESHOOTING.md#hook-problems).

**Quick fix**:
```bash
# Check hooks configuration
cat .claude/settings.json

# Restart Claude Code session
# Try manual check
bash .aea/scripts/aea-check.sh
```

### "jq: command not found"

**Install jq**:
```bash
# Debian/Ubuntu
sudo apt-get install jq

# macOS
brew install jq

# RedHat/CentOS
sudo yum install jq
```

### Monitor won't start

See [Troubleshooting Guide](TROUBLESHOOTING.md#monitor-problems).

```bash
# Check status
bash .aea/scripts/aea-monitor.sh status

# View logs
cat .aea/monitor.log

# Restart
bash .aea/scripts/aea-monitor.sh restart
```

---

## Advanced Usage

### Can I customize message processing policies?

**Yes**, edit `.aea/agent-config.yaml`:

```yaml
policies:
  auto_respond:
    enabled: true
    message_types: [question, update]  # Which types to auto-process
    max_priority: normal               # Don't auto-process high/urgent
    require_approval: [handoff, issue] # Always ask user

  response_time:
    target_seconds: 300                # Aim to respond within 5 min
    timeout_seconds: 3600              # Give up after 1 hour
```

### Can I integrate AEA with CI/CD?

**Yes**, examples:

**GitHub Actions**:
```yaml
name: Check AEA Messages
on: [push, schedule]
jobs:
  check-messages:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install jq
        run: sudo apt-get install -y jq
      - name: Check messages
        run: bash .aea/scripts/aea-check.sh
```

**GitLab CI**:
```yaml
check-aea:
  script:
    - apt-get update && apt-get install -y jq
    - bash .aea/scripts/aea-check.sh
  only:
    - schedules
```

### Can I use AEA programmatically?

**Yes**, all scripts can be called from other scripts:

```bash
#!/bin/bash

# Send automated status update
bash .aea/scripts/aea-send.sh \
  --to monitoring-agent \
  --type update \
  --subject "Build Status: $(git rev-parse --short HEAD)" \
  --message "Build completed successfully at $(date)"

# Check for messages
if bash .aea/scripts/aea-check.sh | grep -q "Found.*messages"; then
  echo "New messages available"
fi
```

### How do I migrate between AEA versions?

See [Migration Guide](MIGRATION.md) (coming soon).

**General process**:
1. Backup your `.aea/` directory
2. Update message schema if protocol version changed
3. Update `agent-config.yaml` for new features
4. Test with sample messages

### Can I run multiple agents on one machine?

**Yes**, each repository has its own agent:

```
/home/user/
├── project-a/.aea/    # Agent A
├── project-b/.aea/    # Agent B
└── project-c/.aea/    # Agent C
```

All agents share the global registry at `~/.config/aea/agents.yaml`.

### Does AEA work with monorepos?

**Yes**, install AEA at the monorepo root:

```bash
cd /path/to/monorepo
bash /path/to/aea/scripts/install-aea.sh
```

Messages are checked for the entire monorepo. You can configure sub-agents per package if needed.

### Can I use custom message types?

**Not officially**, but you can use the existing types creatively:

```bash
# Use "update" for notifications
bash .aea/scripts/aea-send.sh --type update --subject "[DEPLOY] ..." --message "..."

# Use metadata tags for filtering
# Add custom fields in metadata section
```

**Future**: Custom message types may be supported in v0.2.0+.

---

## Still have questions?

- 📖 [Read the documentation](../README.md)
- 🔧 [Troubleshooting Guide](TROUBLESHOOTING.md)
- 💡 [Examples](EXAMPLES.md)
- 🔒 [Security Guide](SECURITY.md)

**Get Help:**
- 🐛 **[Report a Bug](https://github.com/openSVM/aea/issues/new?template=bug_report.md)** - Found a problem?
- ✨ **[Request a Feature](https://github.com/openSVM/aea/issues/new?template=feature_request.md)** - Have an idea?
- ❓ **[Ask a Question](https://github.com/openSVM/aea/issues/new?template=question.md)** - Need help?
- 💬 **[Start a Discussion](https://github.com/openSVM/aea/discussions)** - General discussion

---

**Last Updated**: 2025-10-25 | **Version**: 0.1.0 | [Edit this page](https://github.com/openSVM/aea/edit/main/docs/FAQ.md)
