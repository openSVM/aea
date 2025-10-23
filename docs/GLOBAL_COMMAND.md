# AEA Global Command ('a') - Quick Access Guide

The global `a` command provides quick access to AEA protocol from any directory, making it easy to check for messages, install AEA, and manage agent communication across multiple repositories.

## Quick Start

### 1. One-Time Setup

```bash
# From the AEA repository
bash aea.sh setup-global

# Or with auto mode (no prompts)
bash aea.sh setup-global --auto
```

This will:
- Detect available shells (bash, zsh, fish)
- Add the `a` command to your shell configuration
- Support multiple shells simultaneously

### 2. Activate the Command

```bash
# For bash
source ~/.bashrc

# For zsh
source ~/.zshrc

# For fish
# Already active, just restart your terminal
```

## Usage

### Basic Commands

```bash
# Show AEA status in current directory
a
a status

# Install AEA in current directory
a install

# Check for messages (if AEA installed)
a check

# Process messages interactively
a process

# Control background monitor
a monitor start
a monitor stop
a monitor status

# Run tests
a test

# Show AEA version
a version

# Update AEA from source
a update

# Show help
a help
```

## Workflow Examples

### Scenario 1: Starting work in a new repository

```bash
cd ~/my-project

# Check if AEA is installed
a status
# Output: ⚠ AEA not installed in this directory

# Install AEA
a install
# Prompts: Continue? (y/n): y
# Creates .aea/ directory structure

# Check for messages
a check
# Output: ✅ No new AEA messages
```

### Scenario 2: Working across multiple repositories

```bash
# In repository A
cd ~/project-a
a check
# Found 2 unprocessed messages

a process
# Process messages interactively

# Move to repository B
cd ~/project-b
a check
# No messages

# Create handoff message for repository A
# (after doing work in repo B)
```

### Scenario 3: Continuous monitoring

```bash
cd ~/my-repo
a monitor start
# Output: ✓ Monitor started (PID: 12345)

# Work continues...
# Monitor checks every 5 minutes automatically

a monitor status
# Output: ✓ Monitor running (PID: 12345)

# When done
a monitor stop
# Output: ✓ Monitor stopped
```

## Supported Shells

### Bash

**Configuration file**: `~/.bashrc`

```bash
# Setup adds shell function to ~/.bashrc
bash aea.sh setup-global
source ~/.bashrc
```

### Zsh

**Configuration file**: `~/.zshrc`

```bash
# Setup adds shell function to ~/.zshrc
bash aea.sh setup-global
source ~/.zshrc
```

### Fish

**Configuration file**: `~/.config/fish/functions/a.fish`

```bash
# Setup creates dedicated function file
bash aea.sh setup-global
# Reload fish configuration or restart terminal
```

## Features

### Smart Directory Detection

The `a` command automatically detects whether AEA is installed in the current directory:

- **AEA installed**: Delegates to local `.aea/aea.sh`
- **AEA not installed**: Offers to install or shows status

### Global Commands (work from any directory)

- `a version` - Show AEA protocol version
- `a update` - Update AEA from source repository
- `a help` - Show comprehensive help

### Local Commands (require AEA installation)

- `a check` - Check for messages
- `a process` - Process messages
- `a monitor` - Control monitor
- `a test` - Run tests

## Configuration

The AEA repository path is stored in your shell configuration:

```bash
# Bash/Zsh
local AEA_REPO="/home/user/path/to/aea"

# Fish
set -l AEA_REPO "/home/user/path/to/aea"
```

To change the path, edit your shell configuration file or re-run setup.

## Troubleshooting

### Command not found

```bash
# Re-run setup
bash /path/to/aea/aea.sh setup-global

# Reload shell configuration
source ~/.bashrc  # or ~/.zshrc
```

### Wrong AEA repository path

```bash
# Edit your shell config file
nano ~/.bashrc  # or ~/.zshrc

# Find and update the AEA_REPO path
local AEA_REPO="/correct/path/to/aea"

# Reload
source ~/.bashrc
```

### Multiple shells not working

```bash
# Re-run setup and choose "Configure all shells"
bash aea.sh setup-global

# When prompted: "Configure all shells? (y/n): y"
```

## Advanced Usage

### Alias Customization

If you prefer a different command name, you can modify the shell function:

```bash
# In ~/.bashrc or ~/.zshrc
# Change function name from 'a' to 'aea'
aea() {
    # ... rest of function
}
```

### Auto-check on directory change

Add to your shell config to automatically check for AEA messages when entering a directory:

#### Bash
```bash
cd() {
    builtin cd "$@" && [ -f ".aea/aea.sh" ] && a check || true
}
```

#### Zsh
```bash
chpwd() {
    [ -f ".aea/aea.sh" ] && a check || true
}
```

#### Fish
```fish
function cd --description 'Change directory and check for AEA'
    builtin cd $argv
    and test -f ".aea/aea.sh"
    and a check
end
```

## Security Considerations

The global `a` command:
- Only reads/writes files in the current directory's `.aea/` folder
- Requires explicit confirmation before installing AEA
- Never modifies files outside `.aea/` without user approval
- Respects all AEA safety policies from `agent-config.yaml`

## Comparison: Global vs Local

| Feature | Global (`a`) | Local (`bash .aea/aea.sh`) |
|---------|-------------|----------------------------|
| Ease of use | Quick, from any dir | Requires full path |
| Setup | One-time shell integration | No setup needed |
| Cross-repo | Seamless | Need to track paths |
| Auto-install | Offers to install | Manual installation |
| Update from source | `a update` | Manual git pull |

## Uninstallation

To remove the global `a` command:

### Bash/Zsh
```bash
# Edit your shell config
nano ~/.bashrc  # or ~/.zshrc

# Delete the section starting with:
# # AEA Global Command - Quick access to AEA protocol from any directory
# ... (delete entire function)

# Reload
source ~/.bashrc
```

### Fish
```bash
# Remove the function file
rm ~/.config/fish/functions/a.fish

# Restart fish
```

## Examples

### Example 1: Developer workflow

```bash
# Morning: Check all projects
cd ~/project-1 && a check
cd ~/project-2 && a check
cd ~/project-3 && a check

# Work on project-1
cd ~/project-1
a process  # Process incoming messages

# Create integration work for project-2
# ... do work ...

# Send handoff message to project-2
# (message file created manually or via script)

cd ~/project-2
a check    # Verify message received
```

### Example 2: Multi-agent coordination

```bash
# Agent A (in repo-a)
cd ~/repo-a
a install
a monitor start

# Agent B (in repo-b)
cd ~/repo-b
a install
a check
# Found question from Agent A
a process
# Answer sent back to repo-a

# Agent A receives response
cd ~/repo-a
a check
# Response received
```

## Integration with Claude Code

The `a` command is designed for Claude Code agents to:

1. **Check on every interaction**: `a check` in CLAUDE.md workflows
2. **Process autonomously**: `a process` based on response policies
3. **Monitor continuously**: `a monitor start` for background checking
4. **Quick installation**: `a install` when working in new repos

Add to your `CLAUDE.md`:

```markdown
## Daily Workflow

1. Check for AEA messages: `a check`
2. If messages found: `a process`
3. Continue with user's request
```

---

**Version**: 0.1.0
**Last Updated**: 2025-10-16
**Status**: Production-Ready
