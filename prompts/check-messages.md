# AEA Message Check Prompt

Use this prompt to have Claude autonomously check and process inter-agent messages.

---

## Prompt Template

```
Please check for new AEA inter-agent messages and process them autonomously.

**IMPORTANT: Use the dedicated script:**
```bash
bash .aea/scripts/aea-check.sh
```

DO NOT manually check messages with individual bash commands. The script handles:
- Checking for new messages in .aea/ directory
- Reading and parsing message JSON files
- Applying response policy from .aea/agent-config.yaml
- Taking autonomous action where policy allows
- Marking messages as processed
- Logging actions to .aea/agent.log

If messages need iterative processing, use:
```bash
bash .aea/scripts/process-messages-iterative.sh
```

Response policies (handled by script):
- Questions (technical): Auto-respond with codebase references
- Updates (routine): Acknowledge if requires_response=true
- Issues (low/medium): Analyze and suggest fixes
- Issues (high/urgent): Notify me and wait for approval
- Handoffs: Review and request my approval
- Requests: Evaluate and respond with plan

Safety rules:
- ✅ Auto-safe: read files, search, analyze, answer questions
- ❌ Require approval: code changes, config changes, deployments

Report back:
- Messages found
- Actions taken
- Responses sent
- Anything requiring my approval
```

---

## Example Usage

**In Claude Code session:**

User: "Check AEA messages"

Claude: [Automatically runs the check following the prompt above]

---

## Advanced: Background Monitoring (Future)

When Claude Code supports persistent background tasks:

```
Start a background agent to monitor .aea/ directory every 5 minutes
and process messages according to agent-config.yaml policy.
```

Claude would spawn a Task agent that continuously monitors and responds.

---

## Integration Repositories

Monitor these repos for integration messages:

- `/path/to/repo-a/.aea` (this repo)
- `/path/to/repo-b/.aea` (primary integration partner)

---

## Quick Commands

Check messages:
```bash
ls -1t .aea/message-*.json 2>/dev/null | head -5
```

Check processed messages:
```bash
ls -1t .aea/.processed/*.json 2>/dev/null | head -5
```

View latest message:
```bash
cat $(ls -1t .aea/message-*.json 2>/dev/null | head -1)
```

Count unprocessed messages:
```bash
comm -23 \
  <(ls -1 .aea/message-*.json 2>/dev/null | sort) \
  <(ls -1 .aea/.processed/*.json 2>/dev/null | xargs -n1 basename | sort) \
  | wc -l
```
