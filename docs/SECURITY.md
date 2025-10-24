# AEA Protocol - Security Guide

**Version**: 0.1.0
**Last Updated**: 2025-10-22
**Status**: ⚠️ **READ THIS BEFORE USING**

---

## ⚠️ **Critical Security Information**

### **Messages Are NOT Encrypted or Authenticated**

The current version (v0.1.0) of AEA Protocol has **NO built-in security features**:

- ❌ **No encryption** - Messages are plain JSON text files
- ❌ **No authentication** - Anyone can create/modify messages
- ❌ **No signatures** - No way to verify message sender
- ❌ **No access control** - Filesystem permissions only

**What this means**:
- Anyone with filesystem access can read your messages
- Anyone can modify messages without detection
- Anyone can impersonate other agents
- Deleted messages can be recovered from disk

---

## 🚨 **DO NOT** Use For

### ❌ **Secrets or Credentials**
```bash
# NEVER DO THIS
bash .aea/scripts/aea-send.sh \
  --message "The API key is: sk-1234567890abcdef"  # ← NEVER!
```

**Why**: Messages are stored as plain text. Anyone with access to the filesystem can read them.

### ❌ **Personal Identifiable Information (PII)**
```bash
# NEVER DO THIS
bash .aea/scripts/aea-send.sh \
  --message "User john@example.com has SSN: 123-45-6789"  # ← NEVER!
```

**Why**: Privacy violation and potential legal issues.

### ❌ **Production Passwords or Tokens**
```bash
# NEVER DO THIS
bash .aea/scripts/aea-send.sh \
  --message "Production database password: SuperSecret123"  # ← NEVER!
```

**Why**: Compromise of production systems.

### ❌ **Financial or Health Data**
```bash
# NEVER DO THIS
bash .aea/scripts/aea-send.sh \
  --message "Customer credit card: 4111-1111-1111-1111"  # ← NEVER!
```

**Why**: Regulatory compliance violations (PCI-DSS, HIPAA, GDPR).

---

## ✅ **Safe Uses**

### ✅ **Code Questions**
```bash
# SAFE
bash .aea/scripts/aea-send.sh \
  --type question \
  --message "How does the auth middleware work?"
```

### ✅ **Bug Reports**
```bash
# SAFE
bash .aea/scripts/aea-send.sh \
  --type issue \
  --message "Login endpoint returns 500 for emails with dots"
```

### ✅ **Performance Data**
```bash
# SAFE
bash .aea/scripts/aea-send.sh \
  --type update \
  --message "API response time improved from 450ms to 45ms"
```

### ✅ **Code Locations**
```bash
# SAFE
bash .aea/scripts/aea-send.sh \
  --message "Auth logic is in src/auth/login.ts:67"
```

---

## 🔒 **Security Best Practices**

### 1. **Filesystem Permissions**

**Protect the `.aea/` directory**:

```bash
# Restrict .aea directory to your user only
chmod 700 .aea

# Make message files private
chmod 600 .aea/message-*.json

# Verify permissions
ls -la .aea/
```

**Expected output**:
```
drwx------  (0700)  .aea/
-rw-------  (0600)  .aea/message-*.json
```

### 2. **Git Ignore Configuration**

**IMPORTANT**: Ensure `.aea/` is in `.gitignore`:

```bash
# Add to .gitignore
echo ".aea/" >> .gitignore

# Verify it's excluded
git check-ignore .aea/
```

**Why**: Prevents committing messages to version control.

### 3. **Regular Cleanup**

**Archive old messages**:

```bash
# Move processed messages older than 30 days
find .aea/.processed/ -type f -mtime +30 -exec rm {} \;

# Archive old messages
mkdir -p .aea/.archive
find .aea/ -name "message-*.json" -mtime +30 -exec mv {} .aea/.archive/ \;
```

### 4. **Monitor Access**

**Check who has access to your repository**:

```bash
# Linux/Mac: Check filesystem permissions
ls -la . | head -5

# Check if others have access
stat -c "%A %U %G" .

# If permissions are too open (e.g., world-readable):
chmod 750 .  # Owner full, group read/exec, no others
```

### 5. **Use Environment-Specific Agents**

**Don't mix dev and production**:

```bash
# Development agents
dev-backend-agent → dev-frontend-agent  ✅

# Production agents
prod-backend-agent → prod-frontend-agent  ✅

# NEVER mix
dev-backend-agent → prod-frontend-agent  ❌
```

---

## 🛡️ **Threat Model**

### **Threats v0.1.0 DOES NOT Protect Against**

| Threat | Protected? | Mitigation |
|--------|------------|------------|
| **Filesystem access** | ❌ No | Use OS permissions (chmod) |
| **Message tampering** | ❌ No | Coming in v0.2.0 (signatures) |
| **Impersonation** | ❌ No | Coming in v0.2.0 (authentication) |
| **Eavesdropping** | ❌ No | Coming in v0.2.0 (encryption) |
| **Message replay** | ❌ No | Use TTL, check timestamps |
| **Denial of service** | ⚠️ Partial | Rate limiting (10 msgs per run) |
| **Disk space exhaustion** | ⚠️ Partial | Manual cleanup required |

### **Who Can Attack**

**Anyone with access to**:
- Your user account
- The filesystem where repos are stored
- Backup systems
- Docker containers (if running there)
- SSH access to your machine
- Shared servers or VMs

---

## 🔐 **Security Roadmap**

### **v0.2.0 (Planned - Q1 2026)**

#### Message Signing
```json
{
  "signature": {
    "algorithm": "ed25519",
    "public_key": "age1...",
    "signature": "base64-encoded-sig"
  }
}
```

**Benefits**:
- Verify message sender
- Detect tampering
- Non-repudiation

#### Message Encryption
```json
{
  "encrypted": true,
  "encryption": {
    "algorithm": "age",
    "recipients": ["age1pubkey..."],
    "ciphertext": "..."
  }
}
```

**Benefits**:
- Confidential messages
- Protect sensitive data
- End-to-end encryption

### **v0.3.0 (Future)**

- Access control lists (ACL)
- Message expiration enforcement
- Audit logging to immutable log
- Integration with secret managers (Vault, AWS Secrets)

---

## 📋 **Security Checklist**

Before using AEA in any environment:

- [ ] **Read this document completely**
- [ ] **Set proper filesystem permissions** (`chmod 700 .aea`)
- [ ] **Add `.aea/` to `.gitignore`**
- [ ] **Never store secrets in messages**
- [ ] **Review who has filesystem access**
- [ ] **Set up regular message cleanup**
- [ ] **Use different agents for dev/staging/prod**
- [ ] **Document your security requirements**
- [ ] **Consider if v0.1.0 meets your needs** (may need to wait for v0.2.0)

---

## 🚧 **Production Use Guidance**

### **When v0.1.0 is Acceptable**

✅ **Safe for production if**:
- Messages contain only non-sensitive data
- Repos are on secure, single-user systems
- All users have proper access controls
- You understand and accept the risks
- You have alternative protection (firewall, VPN, etc.)

### **When to Wait for v0.2.0**

⚠️ **Wait if you need**:
- Message confidentiality (encryption)
- Sender authentication (signatures)
- Compliance with security standards
- Protection against insider threats
- Audit trail for security events

### **When NOT to Use AEA (Yet)**

❌ **Don't use if**:
- Handling regulated data (healthcare, finance)
- Multiple untrusted users on same system
- Shared hosting environment
- Required compliance (SOC2, ISO27001, etc.)
- Zero-trust architecture

---

## 🔍 **Incident Response**

### **If Messages Are Compromised**

1. **Immediately**:
   ```bash
   # Stop all monitors
   bash .aea/scripts/aea-monitor.sh stop

   # Archive all messages
   mkdir -p .aea/.incident-$(date +%Y%m%d)
   mv .aea/message-*.json .aea/.incident-$(date +%Y%m%d)/
   ```

2. **Assess Impact**:
   - What data was in the messages?
   - Who had access?
   - Were secrets exposed?

3. **Remediate**:
   - Rotate any exposed credentials
   - Review filesystem permissions
   - Check all registered agents
   - Review logs: `.aea/agent.log`

4. **Prevent**:
   - Implement stricter permissions
   - Review security practices
   - Consider waiting for v0.2.0

---

## 📚 **Additional Resources**

- **PROTOCOL.md**: Technical message format specification
- **EXAMPLES.md**: Safe usage examples
- **GETTING_STARTED.md**: Basic setup with security in mind

---

## ⚡ **TL;DR - Quick Security Rules**

1. ❌ **NO SECRETS** - Never put passwords, keys, or tokens in messages
2. 🔒 **LOCK DOWN** - Use `chmod 700 .aea` to restrict access
3. 🚫 **DON'T COMMIT** - Add `.aea/` to `.gitignore`
4. 🧹 **CLEAN UP** - Archive old messages regularly
5. 🔐 **WAIT IF NEEDED** - If you need encryption, wait for v0.2.0

---

## 📞 **Reporting Security Issues**

Found a security vulnerability? **DO NOT** create a public issue.

Contact:
- Email: GitHub Issues: https://github.com/openSVM/aea/issues
- PGP Key: [Coming soon]

We follow responsible disclosure and will acknowledge reports within 48 hours.

---

**Remember**: Security is a spectrum, not a binary. Understand the risks, apply appropriate controls, and use the right tool for your security requirements.

**v0.1.0 is designed for development and internal use with non-sensitive data.**

**For production use with sensitive data, wait for v0.2.0 with encryption and signing.**

---

**Last Updated**: 2025-10-22
**Version**: 0.1.0
**Status**: Pre-release security documentation
