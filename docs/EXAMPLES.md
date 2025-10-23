# AEA Protocol - Complete Example Workflows

**Version**: 0.1.0
**Last Updated**: 2025-10-22

This guide provides complete, copy-paste ready examples of real-world AEA usage scenarios.

---

## 📋 Table of Contents

1. [Example 1: Ask About Code](#example-1-ask-about-code)
2. [Example 2: Report a Bug](#example-2-report-a-bug)
3. [Example 3: Share Performance Data](#example-3-share-performance-data)
4. [Example 4: Integration Handoff](#example-4-integration-handoff)
5. [Example 5: Background Monitoring](#example-5-background-monitoring)

---

## Example 1: Ask About Code

**Scenario**: You're in `frontend-app` and need to know about an API endpoint in `backend-api`.

### Setup (One-Time)

```bash
# In frontend-app directory
cd /path/to/frontend-app

# Register the backend repo so you can send messages to it
bash .aea/scripts/aea-registry.sh register backend-api /path/to/backend-api "Backend API Service"

# Verify it's registered
bash .aea/scripts/aea-registry.sh list
```

**Output**:
```
Registered AEA Agents:
=====================

Agent: backend-api
  Path: /path/to/backend-api
  Enabled: true
  Description: "Backend API Service"
```

### Send a Question

```bash
# From frontend-app, ask backend about authentication
bash .aea/scripts/aea-send.sh \
  --to backend-api \
  --type question \
  --priority normal \
  --subject "How does user authentication work?" \
  --message "I'm implementing login on the frontend. Can you explain:
  1. What endpoint should I call?
  2. What request format do you expect?
  3. What response will I get back?
  4. Any rate limiting or token expiry I should know about?"
```

**Output**:
```
✅ Message sent: .aea/message-20251022T120345123Z-from-frontend-app.json

   From: frontend-app (/path/to/frontend-app)
   To:   backend-api (/path/to/backend-api)
   Type: question
   Priority: normal
   Subject: How does user authentication work?

Message file: /path/to/backend-api/.aea/message-20251022T120345123Z-from-frontend-app.json

The destination agent will detect this message on next check.
```

### Backend Receives and Responds

```bash
# In backend-api, Claude checks for messages (automatically via hooks)
# Or manually:
cd /path/to/backend-api
bash .aea/scripts/aea-check.sh
```

**Output**:
```
📬 Found 1 unprocessed message(s):

  • message-20251022T120345123Z-from-frontend-app.json
    Type: question | Priority: normal | From: frontend-app
    Subject: How does user authentication work?

📋 Next steps:
  1. Run: /aea
  2. Or ask Claude: 'Process AEA messages'
```

**Claude then**:
1. Reads the question
2. Searches `backend-api` codebase for auth files
3. Analyzes auth implementation
4. Generates detailed response
5. Sends response back to `frontend-app`

**Example Response Message** (auto-created by Claude):
```json
{
  "protocol_version": "0.1.0",
  "message_type": "response",
  "content": {
    "subject": "Re: How does user authentication work?",
    "body": "## Authentication Implementation

**Endpoint**: POST /api/v1/auth/login

**Request Format**:
```json
{
  \"email\": \"user@example.com\",
  \"password\": \"your-password\"
}
```

**Response** (200 OK):
```json
{
  \"token\": \"jwt-token-here\",
  \"expires_at\": \"2025-10-23T12:00:00Z\",
  \"user\": {
    \"id\": \"user-123\",
    \"email\": \"user@example.com\",
    \"name\": \"User Name\"
  }
}
```

**Implementation Details**:
- JWT tokens expire after 24 hours
- Rate limit: 5 attempts per email per 15 minutes
- Token should be sent in Authorization: Bearer {token} header
- Refresh endpoint: POST /api/v1/auth/refresh

**Code References**:
- src/auth/login.ts:45 - Login handler
- src/auth/jwt.ts:23 - Token generation
- src/middleware/auth.ts:12 - Auth middleware

Let me know if you need clarification!"
  }
}
```

### Frontend Receives Response

```bash
# Back in frontend-app, check for messages
cd /path/to/frontend-app
bash .aea/scripts/aea-check.sh
```

**Output**:
```
📬 Found 1 unprocessed message(s):

  • message-20251022T120456789Z-from-backend-api.json
    Type: response | Priority: normal | From: backend-api
    Subject: Re: How does user authentication work?
```

Claude will read this automatically and can now implement the login feature with the correct API details!

---

## Example 2: Report a Bug

**Scenario**: Frontend team discovers that the backend returns 500 errors for certain usernames.

### Send Issue Report

```bash
cd /path/to/frontend-app

bash .aea/scripts/aea-send.sh \
  --to backend-api \
  --type issue \
  --priority high \
  --subject "500 error with usernames containing dots" \
  --message "## Bug Report

**Issue**: Backend returns 500 Internal Server Error for usernames with dots

**Steps to Reproduce**:
1. Call POST /api/v1/auth/login
2. Use email: user.name@example.com
3. Observe 500 error response

**Expected**: Should login successfully or return proper 400 Bad Request

**Actual**: 500 Internal Server Error with no details

**Impact**: Users with dots in their email can't login (affects ~15% of users)

**Error Log**:
\`\`\`
TypeError: Cannot read property 'split' of undefined
  at validateUsername (src/auth/login.ts:67)
\`\`\`

**Our Analysis**: Seems like username validation assumes no dots?

Please investigate and let us know the root cause." \
  --requires-response
```

### Backend Agent Processes Issue

Since this is **high priority**, the agent will:
1. **Analyze the issue** (auto)
2. **Search for the bug** in codebase (auto)
3. **Identify root cause** (auto)
4. **Suggest fix** (auto)
5. **Respond with details** (auto)

**Example Auto-Response**:
```
## Bug Confirmed and Root Cause Identified

**File**: src/auth/login.ts:67
**Problem**: Username extraction assumes email format without dots

**Current Code**:
```typescript
const username = email.split('@')[0].split('.')[0]; // BUG: assumes no dots
```

**Root Cause**: Logic tries to extract first name by splitting on dot, but crashes if email doesn't match expected pattern.

**Fix**: Remove unnecessary username extraction (we don't use it)
```typescript
// Just use email directly
const user = await findUserByEmail(email);
```

**Status**: I can implement this fix now if you approve.

**Estimated Risk**: Low - only affects unused variable
**Testing**: Should test with emails: user.name@test.com, user@test.com, user.middle.last@test.com
```

---

## Example 3: Share Performance Data

**Scenario**: Backend deploys optimization. Frontend needs to know to update their expectations.

### Send Update

```bash
cd /path/to/backend-api

bash .aea/scripts/aea-send.sh \
  --to frontend-app \
  --type update \
  --priority normal \
  --subject "API response times improved 10x" \
  --message "## Performance Improvement Deployed

**Changes**:
- Added Redis caching for user lookups
- Optimized database queries
- Implemented connection pooling

**Impact**:
- /api/v1/users/:id - 450ms → 45ms (10x faster)
- /api/v1/auth/login - 320ms → 95ms (3.4x faster)
- /api/v1/posts - 1200ms → 180ms (6.7x faster)

**Action Required**:
- ✅ No changes needed on your side
- 💡 Consider reducing frontend loading spinners (users expect faster now)
- 💡 May want to reduce request timeout from 5s to 2s

**Deployed**: 2025-10-22 12:00 UTC
**Version**: v2.3.0"
```

### Frontend Acknowledges

The frontend agent will:
1. **Read the update** (auto)
2. **Note the improvements** (auto)
3. **Log to agent.log** (auto)
4. **Send acknowledgment** (auto, since requires_response not set to false)

**Auto-acknowledgment**:
```
Update received and noted: API response times improved 10x

Details:
[original message]

---
This acknowledgment was automatically generated.
The update has been logged for future reference.
```

---

## Example 4: Integration Handoff

**Scenario**: Backend completes new batch API. Frontend needs to integrate it.

### Send Handoff

```bash
cd /path/to/backend-api

bash .aea/scripts/aea-send.sh \
  --to frontend-app \
  --type handoff \
  --priority high \
  --subject "Batch Upload API Ready for Integration" \
  --message "## Batch Upload API Complete ✅

**Status**: Implemented, tested, and deployed to staging

**New Endpoint**: POST /api/v1/batch/upload

**What It Does**:
- Accepts up to 1000 items per request
- Processes in background job
- Returns job ID for polling
- Significantly faster than individual uploads

**Request Format**:
\`\`\`json
{
  \"items\": [
    {\"name\": \"item1\", \"data\": \"...\"},
    {\"name\": \"item2\", \"data\": \"...\"}
  ]
}
\`\`\`

**Response**:
\`\`\`json
{
  \"job_id\": \"job-123\",
  \"status\": \"processing\",
  \"poll_url\": \"/api/v1/jobs/job-123\"
}
\`\`\`

**Next Steps for You**:
1. Update frontend upload component
2. Implement job polling UI
3. Add progress indicator
4. Test with staging endpoint: https://staging.api.example.com

**Documentation**: docs/batch-api.md
**OpenAPI Spec**: docs/api/batch-upload.yaml
**Example Implementation**: examples/batch-upload-client.ts

**Testing Checklist**:
- [ ] Upload 10 items
- [ ] Upload 1000 items (max)
- [ ] Handle errors (invalid items)
- [ ] Poll job status
- [ ] Display results

Let me know when you're ready to start integration!" \
  --requires-response
```

### Frontend Receives Handoff

Since this is a **handoff** (requires human review), Claude will:
1. **Summarize the handoff** (auto)
2. **Notify the user** (auto)
3. **Wait for approval** (stops here)

**Claude tells user**:
```
⚠️  Handoff message received from backend-api

Subject: Batch Upload API Ready for Integration

Summary:
- Backend has completed new batch upload API
- Ready for frontend integration
- Requires implementation of:
  1. Upload component updates
  2. Job polling UI
  3. Progress indicators
- Documentation and examples provided

Should I begin analyzing the integration requirements?
```

**User responds**: "Yes, analyze it"

**Claude then**:
1. Reads the documentation
2. Analyzes current upload code
3. Creates implementation plan
4. Asks user to approve before coding

---

## Example 5: Background Monitoring

**Scenario**: Set up continuous monitoring across multiple repos.

### Start Monitor in Each Repo

```bash
# In backend-api
cd /path/to/backend-api
bash .aea/scripts/aea-monitor.sh start

# In frontend-app
cd /path/to/frontend-app
bash .aea/scripts/aea-monitor.sh start
```

**Output** (for each):
```
🚀 Starting AEA monitor for: backend-api
✅ Monitor started successfully (PID: 12345)
📝 Logs: /home/user/.config/aea/monitor.log
```

### Check Monitor Status

```bash
bash .aea/scripts/aea-monitor.sh status
```

**Output**:
```
AEA Monitor Status for: backend-api

  Status: Running
  PID: 12345
  Last check: 2025-10-22T12:15:00Z
```

### What the Monitor Does

Every 5 minutes, it:
1. Checks for new messages in `.aea/`
2. Logs unprocessed messages to `agent.log`
3. Waits for Claude to process them

**Example monitor.log**:
```
[2025-10-22T12:00:00Z] AEA monitor started (PID: 12345)
[2025-10-22T12:05:00Z] Checking: backend-api
[2025-10-22T12:05:01Z] No unprocessed messages
[2025-10-22T12:10:00Z] Checking: backend-api
[2025-10-22T12:10:01Z] 📬 Found 1 unprocessed message(s) in backend-api
[2025-10-22T12:10:01Z] ⏳ Messages waiting for Claude processing in backend-api
```

### View Recent Activity

```bash
# See what messages have been processed
tail -20 .aea/agent.log
```

**Output**:
```
[2025-10-22 12:00:00 UTC] AEA communication system initialized
[2025-10-22 12:05:32 UTC] Processed: question from frontend-app
[2025-10-22 12:06:15 UTC] SEND Sent response to frontend-app: Re: How does user authentication work?
[2025-10-22 12:11:43 UTC] Processed: issue from frontend-app
[2025-10-22 12:12:05 UTC] SEND Sent response to frontend-app: Re: 500 error with usernames containing dots
```

### Stop Monitor

```bash
bash .aea/scripts/aea-monitor.sh stop
```

**Output**:
```
✅ Monitor stopped (PID: 12345)
```

---

## 🎯 Common Patterns

### Pattern 1: Quick Question
```bash
bash .aea/scripts/aea-send.sh \
  --to other-agent \
  --type question \
  --subject "Quick question" \
  --message "Your question here"
```

### Pattern 2: Bug Report
```bash
bash .aea/scripts/aea-send.sh \
  --to other-agent \
  --type issue \
  --priority high \
  --subject "Bug: Brief description" \
  --message "## Reproduction steps
1. Step one
2. Step two

## Expected vs Actual
..." \
  --requires-response
```

### Pattern 3: Status Update
```bash
bash .aea/scripts/aea-send.sh \
  --to other-agent \
  --type update \
  --subject "Deployed feature X" \
  --message "Feature X is now live in production..."
```

### Pattern 4: Check Messages
```bash
# Manual check
bash .aea/scripts/aea-check.sh

# Or in Claude
/aea
```

---

## 🐛 Troubleshooting Examples

### Can't Send Message: Agent Not Found
```bash
$ bash .aea/scripts/aea-send.sh --to backend-api ...
ERROR: Agent not found in registry: backend-api
```

**Solution**:
```bash
# Register the agent first
bash .aea/scripts/aea-registry.sh register backend-api /path/to/backend-api "Description"

# Verify
bash .aea/scripts/aea-registry.sh list
```

### Message Sent But Not Received
```bash
# Check if it was actually delivered
ls -la /path/to/backend-api/.aea/message-*

# Check if it's been processed
ls -la /path/to/backend-api/.aea/.processed/

# Check backend logs
tail /path/to/backend-api/.aea/agent.log
```

### Monitor Not Running
```bash
$ bash .aea/scripts/aea-monitor.sh status
Monitor not running
```

**Solution**:
```bash
bash .aea/scripts/aea-monitor.sh start
```

---

## 📚 Next Steps

Now that you've seen examples, try:

1. **Send your first message** between two repos
2. **Set up monitoring** for automatic processing
3. **Customize agent-config.yaml** for your needs
4. **Read PROTOCOL.md** for advanced features

**Questions?** See `docs/GETTING_STARTED.md` or create an issue.

---

**Last Updated**: 2025-10-22
**Version**: 0.1.0
