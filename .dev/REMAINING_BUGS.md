# AEA Protocol - Remaining Bugs & Issues

**Date**: 2025-10-22
**Status**: Priority fixes completed, remaining issues documented for future work

---

## 🟡 Medium Priority Issues (4 items)

### 8. Inefficient Search in Auto-Processor
**Location**: `scripts/aea-auto-processor.sh:309-331`

**Problem**:
```bash
for term in $search_terms; do
    local file_results=$(find . -type f -name "*${term}*" 2>/dev/null | ...)
    local content_results=$(grep -r "$term" . --exclude-dir={...} | ...)
done
```
- Runs `find` and `grep -r` multiple times per message
- Can be extremely slow on large repositories
- May cause hook timeouts

**Impact**: Performance degradation, potential timeouts

**Recommended Fix**:
- Add search timeout (5-10 seconds)
- Use faster tools: `fd` instead of `find`, `ripgrep` instead of `grep -r`
- Cache search results for repeated terms
- Limit search depth

**Example Solution**:
```bash
search_codebase() {
    local search_terms="$1"
    local timeout=10

    # Use faster tools if available
    if command -v fd &> /dev/null && command -v rg &> /dev/null; then
        timeout $timeout rg --files-with-matches "$search_terms" --max-depth 5
    else
        timeout $timeout find . -maxdepth 5 -name "*${search_terms}*" 2>/dev/null
    fi
}
```

---

### 9. Timestamp Format Inconsistency
**Location**: Multiple files

**Problem**:
Different timestamp formats used across codebase:
- `aea-send.sh:214`: `date -u +%Y%m%dT%H%M%SZ` (compact)
- `install-aea.sh:912`: `date -u +%Y-%m-%dT%H:%M:%SZ` (ISO 8601 with separators)
- `create-test-scenarios.sh`: Both formats used

**Impact**:
- Parsing confusion
- Potential filename collisions (same-second messages)
- Inconsistent log formats

**Recommended Fix**:
Create a shared function in a common utilities script:

```bash
# scripts/aea-common.sh
get_timestamp_compact() {
    date -u +%Y%m%dT%H%M%S%3NZ  # Include milliseconds
}

get_timestamp_iso8601() {
    date -u +%Y-%m-%dT%H:%M:%S.%3NZ
}
```

**Standardization Proposal**:
- **Filenames**: Use compact format with milliseconds: `20251022T085436123Z`
- **JSON timestamps**: Use ISO 8601 with milliseconds: `2025-10-22T08:54:36.123Z`
- **Logs**: Use ISO 8601 format for readability

---

### 10. Monitor Loop Error Handling
**Location**: `scripts/aea-monitor.sh:321-326`

**Problem**:
```bash
if ! sed -i "/path: \"$escaped_path\"/,/^  [a-z]/ s/last_check:.*/last_check: \"$timestamp\"/" "$CONFIG_FILE" 2>/dev/null; then
    warn "Failed to update last_check timestamp in config"
fi
```
- Warns but continues
- `last_check` may be stale forever
- No retry mechanism

**Impact**: Status information becomes unreliable

**Recommended Fix**:
- Add retry logic (3 attempts)
- Fall back to temp file update
- Log to separate monitoring log

```bash
update_last_check() {
    local max_retries=3
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        if sed -i "/path: \"$path\"/,/^  [a-z]/ s/last_check:.*/last_check: \"$timestamp\"/" "$CONFIG_FILE" 2>/dev/null; then
            return 0
        fi
        warn "Failed to update last_check (attempt $attempt/$max_retries)"
        sleep 1
        ((attempt++))
    done

    error "Could not update last_check after $max_retries attempts"
    return 1
}
```

---

### 11. Hardcoded Path Assumptions
**Location**: Various scripts

**Problem**:
- Some scripts still assume specific directory structures
- Relative paths not always resolved correctly
- Edge cases with unusual installation locations

**Examples**:
- `scripts/create-test-scenarios.sh:20-24` assumes `.aea/` in parent
- Some scripts don't handle being run from subdirectories

**Impact**: Breaks in non-standard installations

**Recommended Fix**:
- Create shared path resolution library
- Always validate resolved paths
- Add diagnostic mode to show resolved paths

---

## 🔵 Low Priority / Code Quality Issues (10 items)

### 12. Duplicate Message Processing Logic
**Location**: `scripts/aea-monitor.sh:276`, `aea.sh:226`

**Problem**:
- Monitor has TODO comment but fallback tries to process
- Inconsistent behavior between implementations

**Fix**: Remove fallback auto-processing or document it clearly

---

### 13. Unused Function Parameters
**Location**: `aea.sh:93`

**Problem**:
```bash
cmd_process() {
    local mode="${1:-interactive}"  # Never used when delegating
    bash "$SCRIPTS_DIR/process-messages-iterative.sh"  # Doesn't receive mode
}
```

**Fix**: Either pass `mode` parameter or remove it

---

### 14. Inefficient Array Iteration
**Location**: Multiple files (e.g., `aea.sh:57-64`)

**Problem**:
```bash
local basename=$(basename "$msg")  # Spawns subprocess
```

**Fix**: Use parameter expansion:
```bash
local basename="${msg##*/}"  # Pure bash, no subprocess
```

**Estimated Improvement**: 10-50ms per message on large repos

---

### 15. Test Directory Hardcoded
**Location**: `aea.sh:287`

**Problem**:
```bash
for dir in ".processed" "logs" "scripts" "tests/v0.1.0"; do
```
- `tests/v0.1.0` doesn't exist in installed repos
- Test always fails for this check

**Fix**: Make test directories configurable or remove from default check

---

### 16. Misleading Exit Code
**Location**: `scripts/aea-check.sh:86`

**Problem**:
```bash
exit 1  # Exit with error code so caller knows there are messages
```
- Returns error when messages exist (normal operation)
- Hooks may interpret as failure

**Recommended Fix**:
Use exit code convention:
- `0`: No messages
- `1`: Messages found (success, but action needed)
- `2`: Actual error (file access, jq missing, etc.)

```bash
# Updated logic
if [ ${#unprocessed[@]} -eq 0 ]; then
    exit 0  # No messages
fi

# Display messages...
exit 1  # Messages found (not an error, just notification)
```

But consider: maybe this is intentional for hooks to detect messages?

---

### 17. Installation Script Fallback
**Location**: `scripts/install-aea.sh:1479-1497`

**Problem**:
- Creates minimal CLAUDE.md if template missing
- Template should always exist in source repo
- Silent degradation

**Fix**: Error if template missing (fail-fast principle)

---

### 18. Missing Error Context
**Location**: Various error messages

**Problem**: Errors don't always include helpful context

**Example**:
```bash
log_error "Failed to parse message"
```

**Better**:
```bash
log_error "Failed to parse message: $msg_file (line $line_num: $parse_error)"
```

---

### 19. No Message Size Limits
**Location**: Message processing scripts

**Problem**: No validation of message size before processing

**Risk**: Extremely large messages could cause issues

**Fix**: Add size validation (e.g., max 1MB per message)

---

### 20. Unquoted Variables in Loops
**Location**: `scripts/aea-auto-processor.sh:479, 513`

**Problem**:
```bash
for msg in $messages; do  # Breaks with spaces in filenames
```

**Fix**:
```bash
# Convert to array properly
readarray -t message_array < <(find .aea -name "message-*.json")
for msg in "${message_array[@]}"; do
```

---

### 21. Code Quality: Magic Numbers
**Problem**: Hardcoded values throughout codebase

**Examples**:
- `CHECK_INTERVAL=300` (monitor)
- `MAX_MESSAGES_PER_RUN=10` (auto-processor)
- Various timeouts

**Fix**: Move to configuration file or constants section

---

## 🏗️ Architectural Issues (3 items)

### A. No Message Encryption/Authentication
**Severity**: High (for production use)

**Problem**:
- Messages are plain JSON files
- No cryptographic signatures
- No encryption for sensitive content
- Anyone with filesystem access can read/modify

**PROTOCOL.md mentions this but not implemented**

**Recommended Implementation**:

#### Phase 1: Message Signing
```bash
# Add to protocol v0.2.0
{
    "signature": {
        "algorithm": "ed25519",
        "public_key": "...",
        "signature": "..."
    }
}
```

#### Phase 2: Encryption
```bash
# Optional encryption for sensitive messages
{
    "encrypted": true,
    "encryption": {
        "algorithm": "age",
        "recipients": ["..."],
        "ciphertext": "..."
    }
}
```

**Tools**: Use `age` for encryption, `minisign` for signatures

**Effort**: 2-3 days implementation + testing

---

### B. Registry Uses Brittle YAML Parsing
**Severity**: Medium

**Problem**:
- YAML parsed with `awk`/`sed`/`grep`
- Can't handle complex YAML features
- Manual edits can break parser
- No validation

**Examples of what breaks**:
- Multi-line strings
- YAML arrays
- Comments in wrong places
- Nested structures

**Recommended Fix**:

**Option 1: Use `yq`** (YAML processor)
```bash
# Install: pip install yq
yq -r '.agents["agent-name"].path' "$REGISTRY_FILE"
```

**Option 2: Switch to JSON**
- Easier to parse with `jq`
- More robust
- Better tooling support

```bash
# registry.json
{
    "version": "1.0",
    "agents": {
        "my-agent": {
            "path": "/path/to/repo",
            "enabled": true
        }
    }
}
```

**Effort**: 1 day to migrate + testing

---

### C. No Message TTL Enforcement
**Severity**: Low-Medium

**Problem**:
- Protocol defines `ttl_seconds` field
- Not enforced anywhere
- Old messages accumulate forever
- No automatic cleanup

**Recommended Implementation**:

**Add to monitor or check scripts**:
```bash
cleanup_expired_messages() {
    local now=$(date +%s)

    for msg in .aea/message-*.json; do
        [ -f "$msg" ] || continue

        local timestamp=$(jq -r '.timestamp' "$msg")
        local ttl=$(jq -r '.ttl_seconds // 2592000' "$msg")  # Default 30 days

        local msg_time=$(date -d "$timestamp" +%s)
        local expires_at=$((msg_time + ttl))

        if [ $now -gt $expires_at ]; then
            log_info "Archiving expired message: $(basename "$msg")"
            mkdir -p .aea/.archived
            mv "$msg" .aea/.archived/
        fi
    done
}
```

**Effort**: 2-3 hours

---

## 📊 Prioritization Matrix

| Issue | Severity | Effort | Priority | ETA |
|-------|----------|--------|----------|-----|
| #8 Inefficient search | Medium | 2h | High | Sprint 1 |
| #9 Timestamp inconsistency | Medium | 3h | Medium | Sprint 1 |
| #A Message signing/encryption | High | 3d | High | Sprint 2 |
| #B Registry YAML parsing | Medium | 1d | Medium | Sprint 2 |
| #10 Monitor error handling | Medium | 2h | Medium | Sprint 2 |
| #C TTL enforcement | Low | 3h | Low | Sprint 3 |
| #11-21 Code quality | Low | 4h | Low | Ongoing |

**Sprint Duration**: 1 week per sprint

---

## 🎯 Recommended Roadmap

### Sprint 1 (Week 1): Performance & Reliability
- [x] Priority fixes (completed)
- [ ] #8 - Add search timeout and use faster tools
- [ ] #9 - Standardize timestamp formats
- [ ] #14 - Optimize subprocess usage

### Sprint 2 (Week 2): Security & Architecture
- [ ] #A - Implement message signing
- [ ] #B - Migrate to JSON registry or use yq
- [ ] #10 - Improve error handling and retries

### Sprint 3 (Week 3): Polish & Cleanup
- [ ] #C - Implement TTL enforcement
- [ ] #15-21 - Code quality improvements
- [ ] Add comprehensive test suite
- [ ] Update documentation

---

## 📝 Notes

- **All critical bugs fixed**: The system is now production-ready for basic use
- **Remaining issues**: Mostly performance, code quality, and nice-to-have features
- **No blockers**: None of the remaining issues prevent normal operation
- **Security**: Message signing should be implemented before using in sensitive environments

---

**Document Status**: Living document - update as issues are resolved
**Last Updated**: 2025-10-22
**Next Review**: After Sprint 1 completion
