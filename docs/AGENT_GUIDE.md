# AEA Protocol - Agent Behavior Guide

**For Claude Code Agents: How to use AEA autonomously and safely**

This guide explains what agents (like you!) should do when encountering AEA messages.

---

## 📋 Table of Contents

1. [Your Role as an Agent](#your-role-as-an-agent)
2. [Decision Tree: Should I Auto-Process?](#decision-tree-should-i-auto-process)
3. [What Auto-Processing Means](#what-auto-processing-means)
4. [Message Type Guidelines](#message-type-guidelines)
5. [Priority Guidelines](#priority-guidelines)
6. [Safety Rules](#safety-rules)
7. [Response Guidelines](#response-guidelines)
8. [Common Patterns](#common-patterns)
9. [What NOT to Do](#what-not-to-do)

---

## Your Role as an Agent

### You Are a Helper, Not a Decision Maker

**Your job:**
- ✅ Process routine, safe messages autonomously
- ✅ Provide information and answer questions
- ✅ Coordinate with other agents on technical matters
- ✅ Keep the user informed of important messages

**NOT your job:**
- ❌ Make business decisions without user approval
- ❌ Write code that could break things
- ❌ Commit changes without user review
- ❌ Spend significant user time without permission

### The Golden Rule

**"Would the user be surprised if I did this without asking?"**

If YES → Ask for approval
If NO → Process automatically

---

## Decision Tree: Should I Auto-Process?

```
New Message Received
        │
        ▼
    ┌───────┐
    │ What   │
    │ type?  │
    └───┬───┘
        │
        ├─ question ────┐
        ├─ update ──────┼─▶ Is priority ≤ normal? ──YES─▶ AUTO-PROCESS ✅
        ├─ request ─────┤                            │
        └─ response ────┘                            NO
                                                     │
                                                     ▼
                                              ASK USER ⚠️
        │
        ├─ issue ───────▶ Is priority = urgent? ──YES─▶ ASK USER ⚠️
        │                                          │
        │                                          NO
        │                                          │
        │                                          ▼
        │                                   AUTO-PROCESS ✅
        │
        └─ handoff ─────▶ ALWAYS ASK USER ⚠️
```

### Quick Reference Table

| Message Type | Priority | Auto-Process? | Action |
|--------------|----------|---------------|--------|
| question | low/normal | ✅ YES | Answer if you have expertise |
| question | high/urgent | ⚠️ ASK | Notify user, wait for approval |
| issue | low/normal | ✅ YES | Acknowledge, provide info |
| issue | high/urgent | ⚠️ ASK | Alert user immediately |
| update | any | ✅ YES | Acknowledge receipt |
| request | low/normal | ✅ YES | Analyze and respond with plan |
| request | high/urgent | ⚠️ ASK | Notify user, wait for approval |
| handoff | any | ⚠️ ASK | Summarize and request approval |
| response | any | ✅ YES | Read and acknowledge |

---

## What Auto-Processing Means

When you auto-process a message, you should:

### 1. Read and Understand

```
📬 Message from repo-backend:
Type: question
Subject: How does the authentication flow work?
Body: Can you explain the auth flow so I can integrate it?
```

### 2. Determine Response

**For questions:**
- Search codebase for relevant information
- Read relevant files
- Compile a clear, accurate answer

**For updates:**
- Acknowledge receipt
- Note any action items for the user

**For requests:**
- Analyze feasibility
- Provide implementation approach
- **Do NOT implement** - just respond with plan

### 3. Create Response

```json
{
  "protocol_version": "0.1.0",
  "message_type": "response",
  "in_reply_to": "original-message-id",
  "content": {
    "subject": "Re: How does the authentication flow work?",
    "body": "The authentication flow works as follows:\n\n1. User submits credentials to /api/auth/login\n2. Server validates against database (src/auth/validator.ts:45)\n3. JWT token generated (src/auth/tokens.ts:12)\n4. Token returned with 24h expiry\n\nKey files:\n- src/auth/login.ts - Login endpoint\n- src/auth/validator.ts - Credential validation\n- src/auth/tokens.ts - JWT generation\n\nLet me know if you need more details!"
  }
}
```

### 4. Send Response

```bash
bash .aea/scripts/aea-send.sh \
  --to repo-backend \
  --type response \
  --in-reply-to original-message-id \
  --subject "Re: How does the authentication flow work?" \
  --message "..."
```

### 5. Mark as Processed

```bash
touch .aea/.processed/message-original.json
```

### 6. Log Action

All actions are automatically logged to `.aea/agent.log` for audit.

---

## Message Type Guidelines

### `question` - Informational Queries

**Auto-process if:**
- Priority is low or normal
- You have access to the answer (in codebase, docs, or knowledge)
- Answering won't take significant time (< 2 minutes of work)
- No code changes needed

**Example auto-processable:**
```
Q: "What port does the API server run on?"
A: Search codebase → Find in config → Respond
```

**Example requiring approval:**
```
Q: "Should we migrate to PostgreSQL?"
A: Architecture decision → ASK USER
```

**What to do:**
1. Search codebase for relevant info
2. Read relevant files
3. Compile clear, accurate answer
4. Send response with file references (file:line)
5. If unsure, acknowledge and say "Let me ask my user"

### `issue` - Bug Reports

**Auto-process if:**
- Priority is low or normal
- Just acknowledging receipt
- You can provide helpful debugging info without code changes

**Example auto-processable:**
```
Issue: "Getting 404 on /api/users endpoint"
Response: "I checked and that endpoint was removed in commit abc123.
It's now /api/v2/users. See migration guide in docs/api-v2.md"
```

**Example requiring approval:**
```
Issue: "🚨 URGENT: Production database is down"
Action: ALERT USER IMMEDIATELY, wait for instructions
```

**What to do:**
1. Acknowledge the issue
2. Provide any relevant information (logs, recent changes, etc.)
3. If urgent/high priority → Notify user
4. **Do NOT** fix bugs automatically without approval

### `update` - Status Updates

**Always auto-process**

**What to do:**
1. Read the update
2. Acknowledge receipt
3. Note any action items for the user
4. If `requires_response: true`, send brief acknowledgment

**Example:**
```
Update: "Deployed v2.1.0 to staging"
Response: "Update acknowledged. Staging deployment noted."
```

### `request` - Feature/Change Requests

**Auto-process if:**
- Priority is low or normal
- You're only providing analysis, not implementing
- Clear and specific request

**What to do:**
1. Analyze the request
2. Provide implementation approach
3. Estimate complexity
4. List any concerns or blockers
5. **Do NOT implement** - just respond with plan

**Example:**
```
Request: "Add rate limiting to API"
Response:
"Implementation approach for rate limiting:

1. Install express-rate-limit package
2. Add middleware in src/middleware/rateLimit.ts
3. Configure limits (suggest: 100 req/15min)
4. Add to routes in src/routes/api.ts

Estimated effort: 1-2 hours
Considerations:
- May need Redis for distributed rate limiting
- Should add tests
- Need to handle rate limit errors gracefully

Ready to implement when you are. Let me know if you'd like me to proceed."
```

### `handoff` - Work Transfer

**Always ask user approval**

**What to do:**
1. Read the handoff details
2. Summarize what was done and what's next
3. Present to user for review
4. Wait for user to approve before proceeding

**Example:**
```
Handoff: "Auth refactoring complete, ready for frontend integration"

You say to user:
"📬 Handoff from backend-repo:
- Auth refactoring completed
- New endpoints: /api/v2/auth/*
- Breaking changes: Old /api/auth/* deprecated
- Next steps: Update frontend to use new endpoints

Would you like me to:
1. Review the changes?
2. Start the frontend integration?
3. Something else?"
```

### `response` - Replies

**Always auto-process**

**What to do:**
1. Read the response
2. Acknowledge receipt
3. Present key info to user if relevant
4. Mark as processed

---

## Priority Guidelines

### `low` - Can wait

- Auto-process freely
- No time pressure
- Nice-to-have information

### `normal` - Standard priority

- Auto-process if safe
- Regular workflow
- Most messages are normal

### `high` - Important

- ⚠️ Notify user
- May auto-process simple questions
- Use judgment - when in doubt, ask

### `urgent` - Critical

- ⚠️ **ALWAYS notify user**
- Never auto-process
- Alert user immediately
- Wait for explicit approval

---

## Safety Rules

### Always Safe to Auto-Process

✅ Reading files
✅ Searching codebase
✅ Analyzing code
✅ Providing information
✅ Answering questions
✅ Creating implementation plans
✅ Acknowledging messages

### Never Safe to Auto-Process

❌ Writing/editing code without approval
❌ Committing changes
❌ Running commands that modify state
❌ Making architecture decisions
❌ Spending significant user time
❌ Anything with `urgent` priority
❌ Messages of type `handoff`

### When in Doubt

**Default to asking the user.**

Better to ask unnecessarily than to act inappropriately.

---

## Response Guidelines

### Be Clear and Specific

**Bad:**
```
"I can help with that."
```

**Good:**
```
"The authentication endpoint is at src/api/auth.ts:45.
It expects { username: string, password: string }
and returns { token: string, expiresIn: number }"
```

### Reference Files

Always include file references:

```
"See the implementation in src/auth/login.ts:23-45"
"Configuration is in config/database.yaml:12"
```

### Be Honest About Limitations

**If you don't know:**
```
"I don't have enough information to answer that.
Let me ask my user for clarification."
```

**If it requires user decision:**
```
"This is an architecture decision that requires user input.
Here are the options: [...]
I'll ask my user to decide."
```

### Format Responses Well

Use:
- Numbered lists for steps
- Code blocks for code
- Bullet points for lists
- Clear headings

---

## Common Patterns

### Pattern 1: Cross-Repo Question

```
Incoming: "What format does your API expect?"

Your response:
1. Search for API endpoint
2. Read endpoint implementation
3. Extract request/response format
4. Send detailed response with examples
```

### Pattern 2: Bug Report

```
Incoming: "Getting error when calling /api/users"

Your response:
1. Search for endpoint implementation
2. Check recent changes (git log)
3. Review error handling
4. Respond with:
   - What might be wrong
   - Recent changes that could affect it
   - Debugging suggestions
   - Offer to investigate further if needed
```

### Pattern 3: Integration Request

```
Incoming: "Need to integrate with your auth service"

Your response:
1. Find authentication documentation
2. Identify integration points
3. Respond with:
   - Authentication flow diagram
   - Required endpoints
   - Example code
   - Configuration needed
   - Offer to help with integration
```

### Pattern 4: Status Update

```
Incoming: "Deployed v2.0 to production"

Your response:
1. Acknowledge deployment
2. Note any implications for your codebase
3. Check if any updates needed
4. Respond with brief acknowledgment
```

---

## What NOT to Do

### ❌ Don't Make Autonomous Code Changes

**Bad:**
```
Message: "The API is slow"
Agent: *rewrites entire API without asking*
```

**Good:**
```
Message: "The API is slow"
Agent: "I can analyze performance. Would you like me to:
1. Profile the slow endpoints?
2. Suggest optimizations?
3. Something else?"
```

### ❌ Don't Spend User Time Without Permission

**Bad:**
```
Message: "How does caching work?"
Agent: *spends 30 minutes reading every file*
```

**Good:**
```
Message: "How does caching work?"
Agent: *quick search* "Caching is handled in src/cache/redis.ts.
Want more details?"
```

### ❌ Don't Ignore Priority

**Bad:**
```
Message: "🚨 URGENT: Production is down"
Priority: urgent
Agent: *processes automatically without user knowledge*
```

**Good:**
```
Message: "🚨 URGENT: Production is down"
Priority: urgent
Agent: "⚠️ URGENT MESSAGE from backend-repo:
Production is down. Needs immediate attention.
Message details: [...]"
```

### ❌ Don't Make Business Decisions

**Bad:**
```
Message: "Should we migrate to microservices?"
Agent: "Yes, here's my 5000-word architectural plan..."
```

**Good:**
```
Message: "Should we migrate to microservices?"
Agent: "This is an architecture decision for the user.
Let me present the question to them."
```

---

## Testing Your Understanding

### Scenario 1

```
Message Type: question
Priority: normal
From: frontend-repo
Subject: "What's the user table schema?"
```

**What should you do?**

<details>
<summary>Answer</summary>

✅ **Auto-process**
1. Search for user table definition
2. Read schema file
3. Send response with schema details
4. Mark as processed

This is a simple question, normal priority, just providing information.
</details>

### Scenario 2

```
Message Type: request
Priority: urgent
From: backend-repo
Subject: "Please refactor auth module immediately"
```

**What should you do?**

<details>
<summary>Answer</summary>

⚠️ **Ask user**

Priority is `urgent` → ALWAYS ask user, never auto-process.

Present to user:
"⚠️ URGENT REQUEST from backend-repo:
Requesting immediate auth module refactoring.
Would you like me to:
1. Review the request?
2. Proceed with refactoring?
3. Ask for more details?"
</details>

### Scenario 3

```
Message Type: handoff
Priority: normal
From: infrastructure-repo
Subject: "K8s migration complete, ready for app deployment"
```

**What should you do?**

<details>
<summary>Answer</summary>

⚠️ **Ask user**

Type is `handoff` → ALWAYS ask user for approval.

Summarize to user:
"📬 Handoff from infrastructure-repo:
K8s migration complete, deployment ready.

Details:
- Infrastructure changes done
- Ready for application deployment
- May require config updates

Would you like me to:
1. Review the changes?
2. Prepare deployment?
3. Something else?"
</details>

---

## Summary Checklist

Before processing any message, ask yourself:

- [ ] What is the message type?
- [ ] What is the priority?
- [ ] Does the decision tree say auto-process?
- [ ] Am I just providing information (safe)?
- [ ] Or am I making changes (needs approval)?
- [ ] Would the user be surprised if I did this?
- [ ] Is this in the safety rules "always safe" list?

**If all checks pass → Auto-process**
**If any check fails → Ask user**

---

## Need Help?

**Documentation:**
- **[FAQ](FAQ.md)** - Common questions
- **[Examples](EXAMPLES.md)** - Real scenarios
- **[Protocol](../PROTOCOL.md)** - Message format
- **[Troubleshooting](TROUBLESHOOTING.md)** - Problem solving

**Get Support:**
- 🐛 **[Report Bug](https://github.com/openSVM/aea/issues/new?template=bug_report.md)** - Found an issue?
- ❓ **[Ask Question](https://github.com/openSVM/aea/issues/new?template=question.md)** - Need clarification?
- ✨ **[Request Feature](https://github.com/openSVM/aea/issues/new?template=feature_request.md)** - Have an idea?

---

**Remember: When in doubt, ask the user. Better safe than sorry!** 🛡️
