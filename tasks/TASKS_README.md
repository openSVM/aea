# AEA Task Management System

**Version**: 0.0.1 (Alpha)
**Status**: Foundation for agent-to-agent task coordination
**Scope**: Generic, project-agnostic task tracking and coordination

---

## Overview

The AEA Task Management System extends the Agent-to-Agent Protocol with structured task coordination capabilities. Unlike ad-hoc messages, tasks provide:

- **Structured tracking** of work across agents
- **Dependencies and relationships** between tasks
- **Progress monitoring** and status updates
- **Specifications and designs** linked to each task
- **Automatic synchronization** across repositories

**Key Philosophy**: Tasks are **project-agnostic** and **reusable** - the same system works for any project type (Rust, Python, JavaScript, DevOps, etc.)

---

## File Structure

```
.aea/tasks/
├── TASKS_README.md           # This file
├── task.json                 # Template: Individual task definition
├── spec.json                 # Template: Technical specifications
├── design.json               # Template: Architecture/design details
├── task-list.json            # Master registry of all tasks
├── {task_id}/
│   ├── task.json            # Specific task instance
│   ├── spec.json            # Task specifications
│   ├── design.json          # Task design
│   └── notes.md             # Additional notes
└── active/
    ├── task-{id}-from-{agent}.json
    └── task-{id}-from-{agent}.json
```

---

## Core Concepts

### 1. Task Lifecycle

```
pending → in_progress → completed
   ↓          ↓
blocked    cancelled
```

**States:**
- **pending**: Created, waiting to start
- **in_progress**: Actively being worked on
- **completed**: Finished successfully
- **blocked**: Cannot proceed (waiting for dependency)
- **cancelled**: No longer needed

### 2. Task Categories

- **feature**: New functionality
- **bugfix**: Fix existing issue
- **refactor**: Code improvement
- **documentation**: Docs, guides, examples
- **testing**: Test coverage
- **integration**: Multi-repo coordination

### 3. Priority Levels

- **low**: Can wait weeks
- **normal**: Regular priority
- **high**: Should be done soon
- **urgent**: Blocks other work

### 4. Dependencies

Tasks can depend on other tasks:

```json
{
  "task_id": "task-uuid",
  "dependencies": [
    "task-dependency-1",
    "task-dependency-2"
  ],
  "blocked_by": [
    "task-blocker"
  ]
}
```

---

## Usage Workflows

### Workflow 1: Creating a Task

**Agent A sends request to Agent B:**

1. **Create task.json** with task details
2. **Create spec.json** with technical requirements
3. **Create design.json** with architecture (optional)
4. **Send as `request` message** to other agent:

```json
{
  "protocol_version": "0.0.1",
  "message_type": "request",
  "priority": "high",
  "requires_response": true,
  "from": {
    "agent_id": "claude-aea",
    "role": "Redis Orderbook Developer"
  },
  "to": {
    "agent_id": "claude-agent-1"
  },
  "message": {
    "subject": "Task: Optimize AMM pool queries",
    "body": "See attached task files in .aea/tasks/{task_id}/",
    "task_id": "task-2025-10-16-001",
    "task_files": [
      ".aea/tasks/task-2025-10-16-001/task.json",
      ".aea/tasks/task-2025-10-16-001/spec.json",
      ".aea/tasks/task-2025-10-16-001/design.json"
    ]
  }
}
```

### Workflow 2: Accepting a Task

**Agent B responds to Agent A:**

1. Review task, spec, and design files
2. Update task.json status to `in_progress`
3. Add `started` timestamp
4. Send confirmation response:

```json
{
  "protocol_version": "0.0.1",
  "message_type": "response",
  "priority": "normal",
  "requires_response": false,
  "from": {
    "agent_id": "claude-agent-1"
  },
  "to": {
    "agent_id": "claude-aea"
  },
  "message": {
    "subject": "Task accepted: Optimize AMM pool queries",
    "body": "Starting work on task-2025-10-16-001. Estimated 4.5 hours.",
    "task_id": "task-2025-10-16-001",
    "status": "in_progress",
    "started": "2025-10-16T14:30:00Z"
  }
}
```

### Workflow 3: Updating Task Progress

**Agent B periodically updates Agent A:**

```json
{
  "protocol_version": "0.0.1",
  "message_type": "update",
  "priority": "normal",
  "requires_response": false,
  "from": {
    "agent_id": "claude-agent-1"
  },
  "to": {
    "agent_id": "claude-aea"
  },
  "message": {
    "subject": "Progress update: Optimize AMM pool queries",
    "body": "Completed 60% of work. Optimization tests passing.",
    "task_id": "task-2025-10-16-001",
    "status": "in_progress",
    "progress": 60,
    "notes": "Initial optimization reduced query time by 35%"
  }
}
```

### Workflow 4: Completing a Task

**Agent B completes and handoffs to Agent A:**

```json
{
  "protocol_version": "0.0.1",
  "message_type": "handoff",
  "priority": "high",
  "requires_response": true,
  "from": {
    "agent_id": "claude-agent-1"
  },
  "to": {
    "agent_id": "claude-aea"
  },
  "message": {
    "subject": "Task completed: Optimize AMM pool queries",
    "body": "All optimization work complete and tested. Ready for integration.",
    "task_id": "task-2025-10-16-001",
    "status": "completed",
    "completed": "2025-10-16T18:45:30Z",
    "deliverables": [
      "src/amm_pool_optimizations.rs",
      "tests/performance_benchmarks.rs"
    ],
    "acceptance_criteria_met": [
      "Query time < 5ms",
      "Memory usage stable",
      "All tests passing"
    ]
  }
}
```

### Workflow 5: Blocking/Dependency Management

**When a task is blocked:**

```json
{
  "protocol_version": "0.0.1",
  "message_type": "issue",
  "priority": "high",
  "requires_response": true,
  "from": {
    "agent_id": "claude-agent-1"
  },
  "to": {
    "agent_id": "claude-aea"
  },
  "message": {
    "subject": "Task blocked: Waiting for dependency",
    "body": "Cannot proceed with integration tests - need updated API from your repo",
    "task_id": "task-2025-10-16-001",
    "status": "blocked",
    "blocked_by": "task-2025-10-16-000",
    "blocker_repo": "claude-aea",
    "estimated_unblock": "2025-10-17T12:00:00Z"
  }
}
```

---

## File Templates and Examples

### task.json - Task Definition

**What it contains:**
- Task metadata (ID, title, description)
- Status and priority
- Assignment and dates
- Dependencies
- Requirements and acceptance criteria
- Related messages and tags

**Usage:**
```bash
# Create new task directory
mkdir .aea/tasks/task-2025-10-16-optimize-amm

# Copy and customize template
cp .aea/tasks/task.json .aea/tasks/task-2025-10-16-optimize-amm/task.json

# Edit to add specifics
nano .aea/tasks/task-2025-10-16-optimize-amm/task.json
```

**Key fields:**
```json
{
  "task_id": "task-2025-10-16-optimize-amm",
  "title": "Optimize AMM pool query performance",
  "status": "pending",
  "priority": "high",
  "category": "feature",
  "assigned_to": {
    "agent_id": "claude-agent-1"
  },
  "dates": {
    "due": "2025-10-20T23:59:59Z",
    "estimated_hours": 4.5
  },
  "acceptance_criteria": [
    "Query time < 5ms average",
    "Memory usage stays stable",
    "All existing tests pass",
    "New benchmarks added"
  ]
}
```

### spec.json - Technical Specifications

**What it contains:**
- Technical requirements and constraints
- Implementation guidelines
- Quality standards
- Dependencies
- APIs and data models
- Error handling

**Usage:**
```bash
# Copy to task directory
cp .aea/tasks/spec.json .aea/tasks/task-2025-10-16-optimize-amm/spec.json

# Customize for this task
nano .aea/tasks/task-2025-10-16-optimize-amm/spec.json
```

**Key fields:**
```json
{
  "specification_id": "spec-2025-10-16-optimize-amm",
  "technical_requirements": {
    "constraints": [
      "Query time < 5ms",
      "Memory per query < 10MB",
      "No breaking API changes"
    ]
  },
  "implementation_guidelines": {
    "language": "rust",
    "testing_requirements": "Unit + integration tests, 80% coverage"
  }
}
```

### design.json - Architecture and Design

**What it contains:**
- High-level architecture
- Component design
- Algorithms and complexity analysis
- Database schema
- Class structure
- File organization
- Concurrency model
- Performance optimizations

**Usage:**
```bash
# Copy to task directory
cp .aea/tasks/design.json .aea/tasks/task-2025-10-16-optimize-amm/design.json

# Detail the design approach
nano .aea/tasks/task-2025-10-16-optimize-amm/design.json
```

**Key fields:**
```json
{
  "architecture": {
    "overview": "Cache-based optimization of AMM pool queries",
    "components": [
      {
        "name": "Query Cache",
        "responsibility": "Store recent pool states",
        "dependencies": ["PoolManager"]
      }
    ]
  },
  "algorithms": [
    {
      "name": "Adaptive Cache TTL",
      "complexity": "O(1) lookup, O(log n) update",
      "trade_offs": "Memory vs query speed"
    }
  ]
}
```

### task-list.json - Master Registry

**What it contains:**
- Central index of all tasks
- Task summaries and metadata
- Status aggregation
- Dependencies map
- Sprint organization
- Integration status

**Auto-generated fields:**
```json
{
  "metadata": {
    "total_tasks": 42,
    "by_status": {
      "pending": 10,
      "in_progress": 5,
      "completed": 27
    },
    "completion_rate": 64.3
  },
  "filtering_and_views": {
    "by_agent": {
      "claude-aea": ["task-001", "task-002"],
      "claude-agent-1": ["task-003", "task-004"]
    }
  }
}
```

---

## Integration with AEA Messages

### Message Types for Tasks

**request**: "Please work on this task"
```json
{
  "message_type": "request",
  "task_id": "task-{id}",
  "task_files": ["task.json", "spec.json", "design.json"]
}
```

**response**: "Task accepted/rejected"
```json
{
  "message_type": "response",
  "task_id": "task-{id}",
  "status": "accepted|rejected",
  "reason": "Why accepted/rejected"
}
```

**update**: "Progress on task"
```json
{
  "message_type": "update",
  "task_id": "task-{id}",
  "progress": 60,
  "status": "in_progress|blocked|completed"
}
```

**issue**: "Task is blocked"
```json
{
  "message_type": "issue",
  "task_id": "task-{id}",
  "status": "blocked",
  "blocked_by": "task-{other_id}"
}
```

**handoff**: "Task completed, handing off"
```json
{
  "message_type": "handoff",
  "task_id": "task-{id}",
  "deliverables": ["file1", "file2"],
  "acceptance_criteria_met": [true, true, true]
}
```

---

## Best Practices

### 1. Task Creation

- ✅ Use UUID for task_id: `task-{YYYY-MM-DD}-{random}`
- ✅ Be specific in title and description
- ✅ Include measurable acceptance criteria
- ✅ Identify dependencies upfront
- ✅ Estimate effort honestly

### 2. Task Assignment

- ✅ Confirm acceptance before starting
- ✅ Agree on due dates with assignee
- ✅ Make dependencies clear
- ✅ Provide all context in spec/design files

### 3. Progress Tracking

- ✅ Update status regularly (especially if blocked)
- ✅ Communicate blockers immediately
- ✅ Track actual vs estimated time
- ✅ Document decisions in task notes

### 4. Task Completion

- ✅ Verify all acceptance criteria met
- ✅ Provide deliverables and documentation
- ✅ Include test results and benchmarks
- ✅ Send handoff message when done

### 5. File Organization

- ✅ One directory per task: `.aea/tasks/{task_id}/`
- ✅ Keep template files in root: `.aea/tasks/task.json`
- ✅ Instances in subdirectories: `.aea/tasks/{task_id}/task.json`
- ✅ Archive completed tasks: `.aea/tasks/archive/{task_id}/`

---

## Advanced Features

### Recurring Tasks

**For ongoing work (e.g., weekly reviews):**

```json
{
  "recurring_tasks": [
    {
      "template_id": "recurring-performance-review",
      "template_title": "Weekly performance benchmarks",
      "frequency": "weekly",
      "next_due": "2025-10-23T09:00:00Z",
      "assigned_to": "claude-aea"
    }
  ]
}
```

### Sprints

**Organize tasks into time-boxed sprints:**

```json
{
  "sprints": [
    {
      "sprint_id": "sprint-001",
      "name": "AMM Optimization Sprint",
      "start_date": "2025-10-16T00:00:00Z",
      "end_date": "2025-10-30T23:59:59Z",
      "tasks": ["task-001", "task-002", "task-003"],
      "goals": ["Reduce query time by 50%", "Improve cache hit rate"]
    }
  ]
}
```

### Multi-Repo Synchronization

**Automatically sync tasks across repositories:**

```json
{
  "integrations": {
    "connected_repos": ["repo-a", "repo-b", "crypto-trading"],
    "sync_frequency": "every 5 minutes",
    "last_sync": "2025-10-16T10:25:00Z"
  }
}
```

---

## Limitations (Alpha v0.0.1)

- ❌ No automatic deadline enforcement
- ❌ No AI-powered effort estimation
- ❌ No conflict resolution for concurrent task updates
- ❌ No notification system
- ❌ No analytics/reporting dashboard
- ⚠️ Manual synchronization between repos required
- ⚠️ No versioning of task definitions

---

## Future Enhancements (Planned)

### v0.1.0 (Beta)
- Automatic task validation and warnings
- Effort estimation based on task complexity
- Task-to-message routing rules

### v0.2.0 (Release Candidate)
- Multi-repo task synchronization daemon
- Real-time conflict detection
- Task dependency graph visualization

### v1.0.0 (Stable)
- Analytics and burndown charts
- Smart deadline suggestions
- Automated retry logic for blocked tasks
- Integration with Git commits/PRs

---

## Troubleshooting

### Task not being picked up

```bash
# Verify directory structure
ls -la .aea/tasks/{task_id}/task.json

# Check JSON validity
jq empty .aea/tasks/{task_id}/task.json

# Verify task.json has required fields
jq '.task_id, .title, .status' .aea/tasks/{task_id}/task.json
```

### Dependency resolution failure

```bash
# Check all dependencies exist
jq -r '.dependencies[]' .aea/tasks/{task_id}/task.json | while read dep; do
  [ -f ".aea/tasks/$dep/task.json" ] && echo "✓ $dep" || echo "✗ Missing: $dep"
done
```

### Messages not syncing tasks

```bash
# Verify message has task_id
jq '.message.task_id' .aea/message-*.json

# Check task directory matches task_id
ls .aea/tasks/ | grep $(jq -r '.message.task_id' .aea/message-*.json)
```

---

## Next Steps

1. **Create your first task** using the templates in this directory
2. **Send task via AEA message** to other agents
3. **Track progress** with regular updates
4. **Archive completed** tasks to maintain clarity

---

**Last Updated**: 2025-10-16
**Version**: 0.0.1 (Alpha)
**Status**: Ready for beta testing across projects
