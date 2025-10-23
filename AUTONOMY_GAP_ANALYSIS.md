# AEA Autonomy Gap Analysis

**Date**: 2025-10-22
**Current Version**: v0.1.0
**Status**: Hybrid Autonomous (Detection only)

---

## Executive Summary

**Current State**: AEA has **automatic detection** via Claude Code hooks, but requires **Claude/human involvement** for processing and execution.

**Autonomy Level**: ~30% (Detection automated, processing/execution manual)

**Key Gaps**:
1. 🔴 **No cross-repo message delivery** (CRITICAL - blocks actual communication)
2. 🔴 **No autonomous action executor** (CRITICAL - requires human approval for everything)
3. 🔴 **No agent registry/discovery** (CRITICAL - can't route messages)
4. 🟡 **No autonomous response generation** (HIGH - limits automation)
5. 🟡 **No state/conversation threading** (HIGH - no context memory)
6. 🟡 **No error handling/retry** (HIGH - silent failures)

**Achievable**: **Hybrid Autonomous** (~80% autonomy) with Phases 1-3 implementation
**Time Estimate**: 1-2 days focused work

---

## What "Fully Autonomous" Means

An autonomous agent should:

| Capability | Current | Needed |
|------------|---------|--------|
| 1. Detect messages | ✅ Auto (hooks) | ✅ Done |
| 2. Process without human intervention | ❌ Manual | ✅ Bash auto-processor |
| 3. Execute safe actions autonomously | ❌ Requires approval | ✅ Policy-based execution |
| 4. Send responses automatically | ❌ Manual/Claude | ✅ Auto-send on safe actions |
| 5. Maintain state across sessions | ❌ No memory | ⚠️ Conversation threading |
| 6. Handle errors and retry | ❌ Silent fail | ⚠️ Retry logic |
| 7. Coordinate with multiple agents | ❌ One-to-one only | ⚠️ Broadcast/groups |
| 8. Learn from interactions | ❌ Static policies | ⚠️ Learning system |

✅ = Available
⚠️ = Partial/Medium priority
❌ = Missing/Critical

---

## Critical Missing Pieces (Ranked)

### 🔴 CRITICAL #1: Cross-Repo Message Delivery

**Current Problem**:
```
Agent A (repo-1) creates message → Saves to repo-1/.aea/message-*.json
Agent B (repo-2) ← ??? MESSAGE NEVER ARRIVES ???
```

**Why Critical**: Without delivery, agents can create messages but never communicate. Protocol is non-functional.

**Solutions**:
- **Option A**: Shared filesystem (symlinks/bind mounts between repos)
- **Option B**: Git-based (commit/push messages, other agent pulls)
- **Option C**: Central broker service (~/.aea-broker/ watches all repos)
- **Option D**: SSH/rsync between remote repos

**Recommended**: Option C (broker) - most flexible, works for local and remote

**Implementation**:
1. Create `~/.config/aea/agents.yaml` registry:
   ```yaml
   agents:
     claude-repo-1:
       path: /home/user/project1
     claude-repo-2:
       path: /home/user/project2
   ```

2. Update `aea-send.sh` to copy to destination:
   ```bash
   dest_path=$(get_agent_path_from_registry "$to_agent")
   cp "$message_file" "$dest_path/.aea/"
   ```

**Time**: 2-4 hours

---

### 🔴 CRITICAL #2: Autonomous Action Executor

**Current Problem**:
```
Hook detects message → Shows to Claude → Claude asks user → User approves → Execute
                                           ↑
                                   BLOCKS AUTONOMY
```

**Why Critical**: Every action requires human approval, defeating autonomy goal.

**Solution**: Bash-based auto-processor that executes safe actions

**Implementation**:
```bash
# scripts/aea-auto-processor.sh (NEW FILE)

#!/bin/bash
# Auto-process safe messages, escalate risky ones

for msg in .aea/message-*.json; do
    [ -f ".aea/.processed/$(basename $msg)" ] && continue

    type=$(jq -r '.message_type' "$msg")
    priority=$(jq -r '.priority' "$msg")

    case "$type:$priority" in
        question:*)
            # Auto-process: search and respond
            auto_respond_to_query "$msg"
            ;;
        update:normal|update:low)
            # Auto-acknowledge
            auto_acknowledge "$msg"
            ;;
        *)
            # Escalate to Claude
            echo "⚠️ Message requires review: $(basename $msg)"
            ;;
    esac
done
```

**Hook config**:
```json
{
  "hooks": {
    "UserPromptSubmit": {
      "command": "bash .aea/scripts/aea-auto-processor.sh"
    }
  }
}
```

**Time**: 4-6 hours

---

### 🔴 CRITICAL #3: Agent Registry/Discovery

**Current Problem**: No way to know where other agents live

**Why Critical**: Can't route messages without knowing destination paths

**Solution**: Central registry at `~/.config/aea/agents.yaml`

**Implementation**:
```yaml
# ~/.config/aea/agents.yaml
agents:
  claude-repo-1:
    path: /home/user/projects/backend
    enabled: true
  claude-repo-2:
    path: /home/user/projects/frontend
    enabled: true
  claude-remote:
    host: server.example.com
    path: /opt/projects/api
    method: ssh
    enabled: true
```

**Helper script**:
```bash
# scripts/aea-registry.sh
get_agent_path() {
    agent_id=$1
    yq eval ".agents.$agent_id.path" ~/.config/aea/agents.yaml
}

register_agent() {
    agent_id=$1
    repo_path=$2
    # Add to registry...
}
```

**Time**: 2-3 hours

---

### 🟡 HIGH #4: Response Generation Logic

**Current**: Claude manually writes responses

**Needed**: Template-based auto-responses

**Example**:
```bash
auto_respond_to_query() {
    msg=$1
    query=$(jq -r '.message.body' "$msg")

    # Search codebase
    results=$(grep -r "$query" . --include="*.py" | head -20)

    # Format response
    create_response \
        --to "$(jq -r '.from.agent_id' "$msg")" \
        --type response \
        --subject "Re: $query" \
        --body "Found files:\n$results"
}
```

**Time**: 3-4 hours

---

### 🟡 HIGH #5: State Management

**Current**: No conversation memory

**Needed**: Conversation threading

**Implementation**:
```bash
# .aea/conversations/{correlation_id}/
#   ├── thread.json        # Conversation metadata
#   ├── message-001.json   # Original message
#   ├── message-002.json   # Response
#   └── context.json       # State/context
```

**Time**: 4-6 hours

---

### 🟡 HIGH #6: Error Handling & Retry

**Current**: Silent failures

**Needed**: Retry queue

**Implementation**:
```bash
# .aea/retry/
#   ├── message-001.json.retry    # Failed message
#   └── retry-log.json            # Retry attempts
```

**Time**: 2-3 hours

---

## Implementation Phases

### Phase 1: Message Delivery (FOUNDATION)
**Goal**: Messages actually travel between repos
**Time**: 4-6 hours
**Deliverables**:
- `~/.config/aea/agents.yaml` registry
- Updated `aea-send.sh` with cross-repo delivery
- Registry helper scripts

### Phase 2: Autonomous Execution (CORE)
**Goal**: Simple messages processed automatically
**Time**: 6-8 hours
**Deliverables**:
- `aea-auto-processor.sh` with policy engine
- Auto-responders for common queries
- Hook integration

### Phase 3: Smart Escalation (HYBRID)
**Goal**: Claude only when needed
**Time**: 3-4 hours
**Deliverables**:
- Message complexity classifier
- Routing logic (bash vs Claude)
- Success/failure tracking

### Phase 4: State & Threading (ADVANCED)
**Goal**: Multi-turn conversations
**Time**: 6-8 hours
**Deliverables**:
- Conversation threading
- State persistence
- Context loading

**Total Time**: 19-26 hours (~2-3 days)

---

## Minimum Viable Autonomous AEA

**What's needed for basic autonomy?**

✅ Phases 1-3 only (13-18 hours):
1. Message delivery across repos
2. Auto-respond to simple queries
3. Smart escalation to Claude

**This enables**:
```
Agent A: "What files handle authentication?"
    ↓
Agent B (bash script):
    1. grep -r "auth" → finds files
    2. Formats results
    3. Creates response message
    4. Sends to Agent A
    5. Marks processed
    ↓
Agent A receives answer
NO HUMAN INTERVENTION ✅
```

---

## The Hard Truth

### What's Achievable Within Claude Code:

✅ **Automatic detection** (done via hooks)
✅ **Simple query responses** (bash grep/format)
✅ **Policy-based routing** (bash decision logic)
✅ **Cross-repo delivery** (file operations)
✅ **~80% autonomy** for simple operations

### What Requires External Service:

❌ **Complex code analysis** (needs LLM)
❌ **Natural language understanding** (needs AI)
❌ **Code generation** (needs AI)
❌ **True learning** (needs ML)
❌ **100% autonomy**

---

## Architectural Comparison

### Current: "Assisted Autonomous"
```
Hook → Detect → Show Claude → Claude processes → Ask user → Execute
                              ↑_________________ MANUAL _____________↑
```

### After Phases 1-3: "Hybrid Autonomous"
```
Hook → Detect → Policy check
                      ├─ Simple? → Bash executes → Done ✅
                      └─ Complex? → Escalate to Claude → Approve → Execute
                                   ↑____________ MANUAL ____________↑
```

### True Full Autonomy (Requires External Service):
```
Service monitors all repos → AI processes → Executes → Done ✅
                             ↑____________ FULLY AUTO ____________↑
```

---

## Recommendation

**Implement Hybrid Autonomous (Phases 1-3)**

**Why**:
- Provides 80% of autonomy benefits
- Works within Claude Code architecture
- Reasonable implementation effort (2-3 days)
- Safe and controllable
- No external infrastructure needed

**Benefits**:
- Questions answered automatically
- Updates acknowledged automatically
- Status requests handled automatically
- Complex tasks still use Claude (safety)

**Trade-offs**:
- Not 100% autonomous
- Bash-only intelligence (limited)
- Complex operations need Claude

**ROI**: High - Major autonomy improvement for minimal complexity

---

## Next Steps

1. **Decide on approach**: Hybrid (Phases 1-3) vs Full External Service?
2. **If Hybrid**: Implement Phase 1 (Message Delivery) first
3. **Test cross-repo messaging**: Verify delivery works
4. **Implement Phase 2**: Auto-processor for simple queries
5. **Test autonomy**: Send question, verify auto-response
6. **Implement Phase 3**: Smart escalation
7. **Document**: Update README with new capabilities

---

## Questions to Answer

1. **Local vs distributed repos?** (Affects delivery mechanism)
2. **Acceptable latency?** (Affects polling frequency)
3. **Security requirements?** (Affects message encryption/signing)
4. **Scale expectations?** (How many agents? How many messages/day?)
5. **Complexity of queries?** (Determines bash vs AI threshold)

---

**Status**: Analysis complete, awaiting implementation decision
