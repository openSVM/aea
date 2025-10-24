# GitHub Issues Integration

**Version**: 0.1.0
**Status**: Beta
**Added**: 2025-10-24

---

## Overview

AEA can automatically check GitHub issues and suggest relevant ones based on your current work context. This helps you stay aware of open issues that might be related to what you're working on.

---

## Features

✨ **Automatic Issue Checking**
- Runs when you check for AEA messages
- Caches results to avoid rate limiting
- Configurable check interval

🎯 **Context Matching**
- Analyzes current directory and files
- Scores issues by relevance
- Highlights highly relevant issues

🏷️ **Label Filtering**
- Filter by specific labels (bug, enhancement, etc.)
- Focus on issues that matter to you

⚡ **Smart Caching**
- Caches issue list for configurable interval
- Force refresh with `--force` flag
- Reduces API calls

---

## Prerequisites

### 1. Install GitHub CLI

```bash
# macOS
brew install gh

# Linux (Ubuntu/Debian)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Other platforms: https://cli.github.com/
```

### 2. Authenticate

```bash
gh auth login
```

Follow the prompts to authenticate with GitHub.

---

## Configuration

Edit `.aea/agent-config.yaml`:

```yaml
github_integration:
  enabled: true  # Set to true to enable
  repository: "owner/repo"  # Your GitHub repository

  # Filter issues by labels
  labels:
    - bug
    - enhancement
    - good first issue

  # How often to check (in minutes)
  check_interval_minutes: 60

  # Context matching settings
  context_matching:
    enabled: true
    relevance_threshold: 5
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable GitHub integration |
| `repository` | string | - | GitHub repo (format: "owner/repo") |
| `labels` | array | - | Filter issues by these labels |
| `check_interval_minutes` | number | `60` | How often to check for new issues |
| `context_matching.enabled` | boolean | `true` | Match issues to current work |
| `context_matching.relevance_threshold` | number | `5` | Minimum score for relevance |

---

## Usage

### Automatic Checking

Once enabled, GitHub issues are automatically checked when you run:

```bash
bash .aea/scripts/aea-check.sh
```

Or when using the `/aea` slash command in Claude Code.

### Manual Checking

```bash
# Check issues
bash .aea/scripts/aea-issues.sh

# Force refresh (ignore cache)
bash .aea/scripts/aea-issues.sh --force

# Use custom config
bash .aea/scripts/aea-issues.sh --config /path/to/config.yaml
```

---

## Output Example

```
📋 Open GitHub Issues:

  ★ Issue #42: Fix authentication timeout in login.ts
    Labels: bug, high-priority
    Relevance: High (score: 15)

  • Issue #38: Improve error handling in API routes
    Labels: enhancement

  • Issue #35: Add tests for user service
    Labels: testing, good first issue

View all: gh issue list --repo owner/repo
```

### Relevance Indicators

- ★ (green) - Highly relevant (score > 10)
- • (yellow) - Somewhat relevant (score > 5)
- • (default) - General issue

### Relevance Scoring

Issues are scored based on:
- **+10** - File name mentioned in issue title
- **+5** - Directory name mentioned in title
- **+3** - Has priority labels (bug, critical, high)

---

## Examples

### Example 1: Enable for Your Project

```bash
# Edit config
nano .aea/agent-config.yaml
```

```yaml
github_integration:
  enabled: true
  repository: "myorg/myproject"
  labels:
    - bug
    - needs-review
  check_interval_minutes: 30
```

```bash
# Check issues
bash .aea/scripts/aea-check.sh
```

### Example 2: Check Issues While Working

```bash
# You're editing src/auth/login.ts
cd src/auth
vim login.ts

# Check for messages and issues
bash ../../.aea/scripts/aea-check.sh

# Output might show:
# ★ Issue #42: Fix authentication timeout in login.ts
#   (Highly relevant because you're in the same file!)
```

### Example 3: Filter by Specific Labels

```yaml
github_integration:
  enabled: true
  repository: "owner/repo"
  labels:
    - security
    - performance
  check_interval_minutes: 120
```

This will only show issues tagged with "security" or "performance".

---

## Troubleshooting

### Issue: "GitHub CLI (gh) not installed"

**Solution**: Install gh CLI:
```bash
# macOS
brew install gh

# Linux
# See: https://cli.github.com/
```

### Issue: "GitHub CLI not authenticated"

**Solution**: Authenticate:
```bash
gh auth login
```

### Issue: "Failed to fetch issues from repo"

**Possible causes**:
1. Repository name incorrect
2. Repository is private and you don't have access
3. Network connectivity issues

**Solution**:
```bash
# Test manually
gh issue list --repo owner/repo

# Check repository access
gh repo view owner/repo
```

### Issue: No issues shown, but I know there are open issues

**Possible causes**:
1. Label filter excludes all issues
2. Cache is stale
3. Issues don't have the specified labels

**Solution**:
```bash
# Force refresh
bash .aea/scripts/aea-issues.sh --force

# Remove label filter temporarily
# Edit agent-config.yaml and remove or comment out labels
```

---

## Caching

Issues are cached in `~/.cache/aea/github-issues.cache`.

**Cache behavior**:
- Cache duration: Configured by `check_interval_minutes`
- Location: `~/.cache/aea/github-issues.cache`
- Format: Plain text (gh CLI output)

**Clear cache**:
```bash
rm ~/.cache/aea/github-issues.cache

# Or force refresh
bash .aea/scripts/aea-issues.sh --force
```

---

## Privacy & Rate Limiting

### Privacy
- Uses your authenticated GitHub account
- Respects repository permissions
- No data sent to third parties
- Cache stored locally only

### Rate Limiting
- GitHub API has rate limits
- Default: 5000 requests/hour (authenticated)
- Caching helps stay within limits
- Recommended: 30-60 minute intervals

**Check your rate limit**:
```bash
gh api rate_limit
```

---

## Disabling

To disable GitHub integration:

```yaml
github_integration:
  enabled: false  # Disable
```

Or remove the entire `github_integration` section.

When disabled, the feature runs silently without any output.

---

## Advanced Usage

### Custom Relevance Threshold

```yaml
context_matching:
  enabled: true
  relevance_threshold: 10  # Only show highly relevant issues
```

### Multiple Label Conditions

```yaml
labels:
  - bug
  - critical
  - security
```

This shows issues with **any** of these labels (OR condition).

### Disable Context Matching

```yaml
context_matching:
  enabled: false  # Show all issues without scoring
```

---

## Integration with Claude Code

When enabled, Claude Code automatically:
1. Checks for GitHub issues during message checks
2. Receives context about relevant open issues
3. Can suggest fixing issues if highly relevant
4. Provides issue numbers in responses

Example Claude response:
```
I noticed Issue #42 is about authentication timeouts in login.ts.
Since we're working on auth right now, would you like me to
investigate and fix this issue?
```

---

## Limitations

- **Requires gh CLI**: Must have GitHub CLI installed and authenticated
- **Public/accessible repos only**: Can't access private repos you don't have permission for
- **Label filtering**: OR condition only (can't do AND conditions)
- **Simple matching**: Context matching uses basic keyword search
- **Cache granularity**: Per-repository cache (not per-label-set)

---

## Future Enhancements

Planned for v0.2.0:
- [ ] Pull request checking
- [ ] Issue assignment suggestions
- [ ] Advanced context matching (AST analysis)
- [ ] Multi-repository support
- [ ] Custom relevance scoring rules
- [ ] Integration with project boards

---

## FAQ

**Q: Do I need to enable this?**
A: No, it's optional. AEA works fine without it.

**Q: Will it slow down message checking?**
A: No, results are cached. First check takes ~1s, subsequent checks are instant (until cache expires).

**Q: Can I use this for private repositories?**
A: Yes, if you have access. Make sure you're authenticated with an account that has access.

**Q: Does it work offline?**
A: It will show cached results. New checks require internet connectivity.

**Q: Can I check multiple repositories?**
A: Not currently. v0.2.0 will support multiple repositories.

---

## Related Documentation

- [Getting Started](GETTING_STARTED.md)
- [Configuration](../agent-config.yaml)
- [AEA Protocol](../PROTOCOL.md)

---

**Last Updated**: 2025-10-24
**Version**: 0.1.0
