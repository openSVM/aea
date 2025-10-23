# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⚠️ REPOSITORY CONTEXT

**You are in the AEA Protocol SOURCE repository** - this is where the protocol itself is developed and maintained.

If you're looking for instructions on using AEA in a project, see `templates/CLAUDE_INSTALLED.md` which gets copied to target repositories.

---

## Project Overview

**AEA (Agentic Economic Activity) Protocol** - A file-based messaging protocol enabling asynchronous, autonomous communication between Claude Code agents across multiple repositories.

**Current Protocol Version**: v0.1.0

**This Repository Contains**:
- Protocol specification (`PROTOCOL.md`)
- Installation scripts (`scripts/install-aea.sh`)
- Core operational scripts that get installed
- Documentation and templates
- Self-hosted `.aea/` for testing (dogfooding)

---

## Essential Commands

### Development & Testing

```bash
# Test the protocol locally
bash aea.sh check              # Check .aea/ subdirectory for test messages
bash aea.sh test               # Run test suite

# Create test scenarios (writes to .aea/)
bash scripts/create-test-scenarios.sh simple-question
bash scripts/create-test-scenarios.sh urgent-issue
bash scripts/create-test-scenarios.sh all

# Process test messages
bash aea.sh process
```

### Installation

```bash
# Install AEA in another repository
bash scripts/install-aea.sh /path/to/target/repo

# Install in current directory (converts it to AEA-enabled)
bash scripts/install-aea.sh
```

### Global Setup (Optional)

```bash
# Setup global 'a' command
bash aea.sh setup-global
source ~/.bashrc  # or ~/.zshrc

# Then use anywhere:
a check
a process
a monitor start
```

---

## Architecture Overview

### Repository Structure

```
aea/                              # THIS REPO (protocol source)
├── aea.sh                        # Main operational script
├── agent-config.yaml             # Config for THIS agent (AEA developer)
├── CLAUDE.md                     # This file (for development)
├── PROTOCOL.md                   # Protocol specification
├── README.md                     # Overview
│
├── scripts/                      # Scripts that GET INSTALLED
│   ├── aea-check.sh              # Message checker
│   ├── aea-monitor.sh            # Background monitor
│   ├── process-messages-iterative.sh
│   ├── install-aea.sh            # Installation script
│   └── create-test-scenarios.sh  # Test data generator
│
├── templates/                    # Templates for installation
│   └── CLAUDE_INSTALLED.md       # Gets copied to target/.aea/CLAUDE.md
│
├── docs/                         # Documentation
│   ├── aea-rules.md              # Protocol rules
│   └── GETTING_STARTED.md
│
├── prompts/                      # Prompt templates
│   └── check-messages.md
│
└── .aea/                         # Self-hosting (for testing)
    ├── agent.log
    └── .processed/
```

### What Gets Installed

When you run `bash scripts/install-aea.sh /target/repo`:

```
/target/repo/
├── .aea/                         # AEA gets installed HERE
│   ├── aea.sh                    # Copied from this repo
│   ├── agent-config.yaml         # Template, needs configuration
│   ├── CLAUDE.md                 # From templates/CLAUDE_INSTALLED.md
│   ├── PROTOCOL.md               # Protocol spec
│   ├── scripts/                  # All operational scripts
│   ├── prompts/
│   ├── docs/
│   ├── agent.log                 # Created at runtime
│   ├── message-*.json            # Incoming messages
│   └── .processed/               # Processed markers
│
├── .claude/
│   ├── commands/
│   │   └── aea.md                # /aea slash command
│   └── settings.json             # Hooks for automatic checking
│
└── CLAUDE.md                     # Updated with AEA section
```

**Automatic Checking via Hooks:**

The installation configures Claude Code hooks in `.claude/settings.json`:
- **SessionStart** - Checks for messages when Claude Code starts
- **UserPromptSubmit** - Checks before processing user messages
- **Stop** - Checks after completing tasks

This enables **truly automatic** message checking without manual `/aea` commands!

---

## Development Workflow

### Working on the Protocol

1. **Make changes** to scripts, protocol spec, or documentation
2. **Test locally** using the `.aea/` subdirectory:
   ```bash
   bash scripts/create-test-scenarios.sh all
   bash aea.sh check
   bash aea.sh process
   ```
3. **Verify** test suite passes:
   ```bash
   bash aea.sh test
   ```

### Testing Installation

```bash
# Create a test directory
mkdir -p /tmp/test-repo
cd /tmp/test-repo

# Install AEA
bash /path/to/aea/scripts/install-aea.sh

# Verify installation
ls -la .aea/
cat .aea/CLAUDE.md  # Should be CLAUDE_INSTALLED.md content
```

### Updating Templates

When updating the installed experience:

1. Edit `templates/CLAUDE_INSTALLED.md` (NOT this file)
2. Edit template sections in `scripts/install-aea.sh`
3. Test by installing in a fresh directory
4. Verify commands work from installed context

---

## Key Implementation Details

### Dual Directory Structure

**This repo has TWO .aea-related locations**:

1. **`.aea/`** (subdirectory) - For self-testing
   - Contains test messages
   - Used during development
   - Commands: `bash aea.sh check` (checks `.aea/`)

2. **Root level** - The protocol source
   - Contains `scripts/`, `aea.sh`, configs
   - Gets installed to OTHER repos' `.aea/` directories
   - Commands: `bash scripts/aea-check.sh` (for development)

**They serve different purposes** - don't confuse them!

### Path Conventions

**In THIS repo (development)**:
```bash
bash aea.sh check                 # Checks .aea/ subdirectory
bash scripts/aea-check.sh         # Direct script execution
bash scripts/install-aea.sh /target
```

**In INSTALLED repo** (see templates/CLAUDE_INSTALLED.md):
```bash
bash .aea/aea.sh check            # Checks .aea/ for messages
bash .aea/scripts/aea-check.sh    # Direct script execution
```

### Testing the Dogfooding Setup

This repo uses AEA for itself (self-hosting):

```bash
# Create a test message in .aea/
bash scripts/create-test-scenarios.sh simple-question

# Check for it
bash aea.sh check

# Process it
bash aea.sh process

# Verify it was marked processed
ls -la .aea/.processed/
```

---

## Common Development Tasks

### Adding a New Script

1. Create script in `scripts/`
2. Add to `scripts/install-aea.sh` installation list
3. Test locally
4. Document in `templates/CLAUDE_INSTALLED.md` if user-facing

### Updating the Protocol

1. Edit `PROTOCOL.md`
2. Update affected scripts
3. Update `templates/CLAUDE_INSTALLED.md` if needed
4. Increment version number
5. Test with `bash aea.sh test`

### Creating New Test Scenarios

Edit `scripts/create-test-scenarios.sh`:
- Add new function for scenario
- Follow existing pattern
- Ensure it writes to `.aea/message-*.json`

---

## Troubleshooting

### Test Scenarios Fail to Create

```bash
# Ensure .aea/ directory exists
ls -la .aea/

# If missing:
mkdir -p .aea/.processed

# Try again
bash scripts/create-test-scenarios.sh simple-question
```

### Scripts Not Executable

```bash
chmod +x scripts/*.sh
chmod +x aea.sh
```

### Installation Fails

```bash
# Check target directory exists
ls -la /target/repo

# Check script is executable
ls -la scripts/install-aea.sh

# Run with verbose output
bash -x scripts/install-aea.sh /target/repo
```

---

## Key Files

### For Development (this repo)
- **aea.sh** - Main operational script
- **scripts/install-aea.sh** - Installation script
- **PROTOCOL.md** - Protocol specification
- **templates/CLAUDE_INSTALLED.md** - Template for installed repos
- **scripts/create-test-scenarios.sh** - Test data generator

### For Installed Repos
- See `templates/CLAUDE_INSTALLED.md` for the user-facing documentation

---

## External Dependencies

- `bash` (4.0+)
- `jq` - JSON parsing
- `openssl` - Cryptographic signatures (optional)
- Standard utilities: `date`, `touch`, `mkdir`, `cat`, `grep`

---

## Integration Workflow

### When Installing AEA Elsewhere

The `scripts/install-aea.sh` script:

1. Creates `.aea/` directory structure in target
2. Copies scripts, configs, and documentation
3. **Installs `templates/CLAUDE_INSTALLED.md` as `.aea/CLAUDE.md`**
4. Creates runtime directories (`.processed/`, `logs/`)
5. Sets up `.gitignore`

The target repository then has AEA available at `.aea/` with context-appropriate documentation.

---

## Important Notes

### This File vs. Installed File

- **This file** (`CLAUDE.md`): For working ON the AEA protocol
- **Installed file** (`templates/CLAUDE_INSTALLED.md` → `.aea/CLAUDE.md`): For working IN a repo that USES AEA

**Don't confuse them!** They have different commands and contexts.

### When to Edit Which File

- **Edit this file**: When documenting protocol development, testing, or installation
- **Edit `templates/CLAUDE_INSTALLED.md`**: When documenting how to USE AEA in a project

### Path Portability

All scripts use relative paths and are designed to work when installed in `.aea/` subdirectory of target repositories.
