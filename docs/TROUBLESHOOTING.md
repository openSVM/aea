# AEA Protocol - Troubleshooting Guide

**Version**: 0.1.0
**Last Updated**: 2025-10-25

Complete guide to diagnosing and fixing common AEA Protocol issues.

---

## 📋 Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Installation Issues](#installation-issues)
3. [Message Not Appearing](#message-not-appearing)
4. [Processing Failures](#processing-failures)
5. [Hook Problems](#hook-problems)
6. [Registry Issues](#registry-issues)
7. [Monitor Problems](#monitor-problems)
8. [GitHub Integration Issues](#github-integration-issues)
9. [Performance Issues](#performance-issues)
10. [Error Reference](#error-reference)

---

## Quick Diagnostics

Run these commands to quickly diagnose your AEA setup:

```bash
# Check if AEA is installed
ls -la .aea/

# Verify required tools
which jq bash
jq --version

# Test message check
bash .aea/scripts/aea-check.sh

# Check registry
bash .aea/scripts/aea-registry.sh list

# View recent logs
tail -20 .aea/agent.log

# Check monitor status
bash .aea/scripts/aea-monitor.sh status
```

---

## Installation Issues

### ❌ "No such file or directory: .aea"

**Problem**: AEA not installed in current directory.

**Solution**:
```bash
# Install AEA in current directory
bash /path/to/aea/scripts/install-aea.sh

# Or one-line install
curl -fsSL https://raw.githubusercontent.com/openSVM/aea/main/install.sh | bash
```

### ❌ "jq: command not found"

**Problem**: jq not installed.

**Solution**:
```bash
# Debian/Ubuntu
sudo apt-get update && sudo apt-get install -y jq

# macOS
brew install jq

# RedHat/CentOS
sudo yum install jq

# Alpine
apk add jq
```

### ❌ Permission denied when running scripts

**Problem**: Scripts not executable.

**Solution**:
```bash
chmod +x .aea/scripts/*.sh
```

### ❌ "Failed to create required directories"

**Problem**: No write permission in directory.

**Solution**:
```bash
# Check permissions
ls -la | grep .aea

# Fix ownership
sudo chown -R $USER:$USER .aea/

# Or run with appropriate permissions
sudo bash .aea/scripts/aea-check.sh
```

---

## Message Not Appearing

### ❌ Sent message not showing up

**Checklist**:

1. **Verify message was created**:
   ```bash
   # In recipient repo
   ls -la .aea/message-*.json
   ```

2. **Check if already processed**:
   ```bash
   ls -la .aea/.processed/
   ```

3. **Validate message format**:
   ```bash
   # Check JSON is valid
   jq empty .aea/message-*.json

   # Validate required fields
   bash .aea/scripts/aea-validate-message.sh .aea/message-*.json
   ```

4. **Check agent registry**:
   ```bash
   # Verify recipient is registered
   bash .aea/scripts/aea-registry.sh list
   ```

5. **Verify hooks are running**:
   ```bash
   cat .claude/settings.json
   # Should contain AEA hooks
   ```

### ❌ Messages not auto-checking

**Problem**: Hooks not configured or disabled.

**Solution**:
```bash
# Check hooks configuration
cat .claude/settings.json

# Reinstall hooks
bash .aea/scripts/install-aea.sh --hooks-only

# Or manually add to .claude/settings.json:
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

---

## Processing Failures

### ❌ "No unprocessed messages" but messages exist

**Problem**: Messages already marked as processed.

**Diagnosis**:
```bash
# List unprocessed messages
for msg in .aea/message-*.json; do
  basename=$(basename "$msg")
  if [ ! -f ".aea/.processed/$basename" ]; then
    echo "Unprocessed: $basename"
  fi
done
```

**Solution**:
```bash
# Clear processed markers to reprocess
rm .aea/.processed/message-*.json

# Or remove specific message marker
rm .aea/.processed/message-20251025T120000000Z-from-agent.json
```

### ❌ Message validation fails

**Problem**: Message doesn't conform to protocol v0.1.0.

**Common Issues**:

1. **Wrong protocol version**:
   ```json
   ❌ "protocol_version": "1.0"
   ✅ "protocol_version": "0.1.0"
   ```

2. **Wrong field names**:
   ```json
   ❌ "from": {...}
   ✅ "sender": {...}

   ❌ "to": {...}
   ✅ "recipient": {...}

   ❌ "priority": "high"
   ✅ "routing": {"priority": "high"}

   ❌ "message": {"subject": "..."}
   ✅ "content": {"subject": "..."}
   ```

3. **Missing required fields**:
   ```bash
   # Run validator to see what's missing
   bash .aea/scripts/aea-validate-message.sh .aea/message-*.json
   ```

**Solution**: Update message to v0.1.0 schema (see [PROTOCOL.md](../PROTOCOL.md))

### ❌ "Failed to parse JSON"

**Problem**: Invalid JSON syntax.

**Diagnosis**:
```bash
# Check JSON syntax
jq empty .aea/message-*.json
```

**Common Issues**:
- Missing commas
- Trailing commas (not allowed in JSON)
- Unescaped quotes in strings
- Missing closing brackets

**Solution**:
```bash
# Use jq to pretty-print and fix formatting
cat .aea/message-bad.json | jq '.' > .aea/message-fixed.json
```

---

## Hook Problems

### ❌ Hooks not triggering

**Problem**: Claude Code not executing AEA hooks.

**Diagnosis**:
```bash
# Check if hooks file exists
cat .claude/settings.json

# Check logs for hook execution
tail -f .aea/agent.log
```

**Solutions**:

1. **Restart Claude Code session**
2. **Verify hook syntax**:
   ```json
   {
     "hooks": {
       "UserPromptSubmit": "bash .aea/scripts/aea-check.sh"
     }
   }
   ```
3. **Check script paths are correct** (relative to project root)
4. **Ensure scripts are executable**: `chmod +x .aea/scripts/*.sh`

### ❌ Hook errors in Claude Code

**Problem**: Hook command fails.

**Diagnosis**:
```bash
# Manually run hook command to see error
bash .aea/scripts/aea-check.sh

# Check for script errors
bash -x .aea/scripts/aea-check.sh
```

**Solution**: Fix script errors, ensure dependencies (jq) are installed.

---

## Registry Issues

### ❌ "Agent not found in registry"

**Problem**: Destination agent not registered.

**Solution**:
```bash
# Register the agent
bash .aea/scripts/aea-registry.sh register agent-name /path/to/repo "Description"

# Verify registration
bash .aea/scripts/aea-registry.sh list
```

### ❌ "Registry file not found"

**Problem**: Agent registry not initialized.

**Solution**:
```bash
# Initialize registry
mkdir -p ~/.config/aea
cat > ~/.config/aea/agents.yaml << 'EOF'
agents: {}
EOF

# Or let AEA create it
bash .aea/scripts/aea-registry.sh list
```

### ❌ Registry corruption

**Problem**: Invalid YAML in registry file.

**Diagnosis**:
```bash
cat ~/.config/aea/agents.yaml
```

**Solution**:
```bash
# Backup corrupted registry
cp ~/.config/aea/agents.yaml ~/.config/aea/agents.yaml.bak

# Recreate registry
cat > ~/.config/aea/agents.yaml << 'EOF'
agents:
  agent-1:
    path: /path/to/repo1
    enabled: true
    description: "Description"
EOF

# Re-register all agents
bash .aea/scripts/aea-registry.sh register agent-name /path "Description"
```

---

## Monitor Problems

### ❌ Monitor won't start

**Problem**: Monitor script fails to start.

**Diagnosis**:
```bash
# Check monitor status
bash .aea/scripts/aea-monitor.sh status

# Check logs
cat .aea/monitor.log

# Try manual start
bash .aea/scripts/aea-monitor.sh start
```

**Common Issues**:

1. **Already running**:
   ```bash
   bash .aea/scripts/aea-monitor.sh stop
   bash .aea/scripts/aea-monitor.sh start
   ```

2. **No write permission**:
   ```bash
   chmod +w .aea/
   ```

3. **Script not executable**:
   ```bash
   chmod +x .aea/scripts/aea-monitor.sh
   ```

### ❌ Monitor stops unexpectedly

**Problem**: Background process dies.

**Diagnosis**:
```bash
# Check monitor log
tail -50 .aea/monitor.log

# Check system logs
journalctl -u aea-monitor  # If using systemd
```

**Solutions**:

1. **Increase check interval** (reduce CPU usage):
   ```yaml
   # In agent-config.yaml
   monitoring:
     check_interval_seconds: 300  # 5 minutes instead of 60
   ```

2. **Check for disk space**:
   ```bash
   df -h
   ```

3. **Restart monitor**:
   ```bash
   bash .aea/scripts/aea-monitor.sh restart
   ```

---

## GitHub Integration Issues

### ❌ GitHub issues not appearing

**Problem**: GitHub integration not configured.

**Solution**:
```yaml
# Add to .aea/agent-config.yaml:
github_integration:
  enabled: true
  repository: "owner/repo"
  labels:
    - bug
    - enhancement
  check_interval_minutes: 60
```

### ❌ "API rate limit exceeded"

**Problem**: Too many GitHub API requests.

**Solutions**:

1. **Increase check interval**:
   ```yaml
   github_integration:
     check_interval_minutes: 120  # Check every 2 hours
   ```

2. **Use GitHub token for higher limits**:
   ```yaml
   github_integration:
     token: "ghp_your_token_here"  # Optional, increases rate limit
   ```

3. **Filter by labels** to reduce requests:
   ```yaml
   github_integration:
     labels:
       - critical
       - blocking
   ```

---

## Performance Issues

### ❌ Slow message checking

**Problem**: Check takes too long.

**Diagnosis**:
```bash
time bash .aea/scripts/aea-check.sh
```

**Solutions**:

1. **Clean up old messages**:
   ```bash
   # Move old processed messages
   mkdir -p .aea/archive
   mv .aea/message-2025-01-*.json .aea/archive/
   ```

2. **Reduce GitHub check frequency**:
   ```yaml
   github_integration:
     check_interval_minutes: 120
   ```

3. **Optimize jq queries** (for developers)

### ❌ High CPU usage from monitor

**Problem**: Monitor using too much CPU.

**Solution**:
```yaml
# In agent-config.yaml
monitoring:
  check_interval_seconds: 300  # Check every 5 minutes
```

---

## Error Reference

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `jq: command not found` | jq not installed | Install jq: `apt-get install jq` or `brew install jq` |
| `No such file or directory: .aea` | AEA not installed | Run installation script |
| `Invalid JSON` | Malformed message | Validate with `jq empty file.json` |
| `Missing required field: .message_id` | Incomplete message | Add all required fields per PROTOCOL.md |
| `Agent not found in registry` | Agent not registered | Register with `aea-registry.sh register` |
| `Permission denied` | No execute permission | Run `chmod +x .aea/scripts/*.sh` |
| `Failed to create required directories` | No write permission | Fix permissions or run as appropriate user |
| `Protocol version mismatch` | Wrong version | Use `"protocol_version": "0.1.0"` |

### Script Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Missing dependency |
| 3 | Invalid configuration |
| 4 | File not found |
| 5 | Permission denied |

---

## Getting Help

If you can't resolve your issue:

1. **Check logs**:
   ```bash
   cat .aea/agent.log
   tail -50 .aea/monitor.log
   ```

2. **Run diagnostics**:
   ```bash
   bash .aea/scripts/aea-check.sh
   bash .aea/scripts/aea-validate-message.sh .aea/message-*.json
   ```

3. **Create GitHub issue**: https://github.com/openSVM/aea/issues
   - Include error messages
   - Include relevant logs
   - Include system info: `uname -a`, `jq --version`, `bash --version`

4. **Check documentation**:
   - [Installation Guide](INSTALLATION.md)
   - [Protocol Specification](../PROTOCOL.md)
   - [Examples](EXAMPLES.md)

---

## Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Run scripts with debug output
bash -x .aea/scripts/aea-check.sh

# Enable detailed logging in agent-config.yaml
logging:
  level: debug
  file: .aea/debug.log
```

---

## 💬 Still Need Help?

If you can't resolve your issue:

### 🐛 Report a Bug
**[Report Bug](https://github.com/openSVM/aea/issues/new?template=bug_report.md)** - Use our bug report template

### ❓ Ask a Question
**[Ask Question](https://github.com/openSVM/aea/issues/new?template=question.md)** - Get help from the community

### 💭 Discuss
**[Start Discussion](https://github.com/openSVM/aea/discussions)** - General questions and ideas

### 📖 More Resources
- **[FAQ](FAQ.md)** - Frequently asked questions
- **[Examples](EXAMPLES.md)** - Real-world usage scenarios
- **[Agent Guide](AGENT_GUIDE.md)** - Agent behavior guidelines

When reporting issues, please include:
- Error messages from logs (`.aea/agent.log`)
- Your environment (OS, bash version, jq version)
- Relevant configuration (`.aea/agent-config.yaml`)
- Steps to reproduce the problem
