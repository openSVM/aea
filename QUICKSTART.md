# AEA Protocol - Quick Start

## Install in 30 Seconds

```bash
# 1. Clone AEA
git clone https://github.com/openSVM/aea && cd aea

# 2. Go to your project
cd /path/to/your/project

# 3. Run installer
bash /path/to/aea/install.sh
```

Done! ✅

---

## Common Commands

```bash
# Check for messages
bash .aea/aea.sh check

# Send a message
bash .aea/scripts/aea-send.sh \
  --to other-agent \
  --type question \
  --subject "Quick question" \
  --message "How do I...?"

# Set up global 'a' command
bash .aea/aea.sh setup-global
source ~/.bashrc  # Then use: a check

# View help
bash .aea/aea.sh help
```

---

## Smart Installer Features

### Auto-Detects Projects

Supports **100+ languages**:
- JavaScript (package.json)
- Python (requirements.txt, pyproject.toml)
- Rust (Cargo.toml)
- Go (go.mod)
- Java (pom.xml, build.gradle)
- ...and 95 more!

### Manages Existing Installations

```
⚠ AEA is already installed in this directory

What would you like to do?
  1) Repair installation (fix missing files)
  2) Delete and backup (move to ~/.aea/backups)
  3) Cancel
```

### Automatic Backups

Delete installations are backed up to `~/.aea/backups/` with metadata:

```bash
# List backups
bash /path/to/aea/install.sh --list

# Restore a backup
mv ~/.aea/backups/my-project-TIMESTAMP/aea-backup /path/to/project/.aea
```

---

## What Gets Installed

```
your-project/
└── .aea/
    ├── aea.sh              # Main interface
    ├── CLAUDE.md           # Instructions
    ├── agent-config.yaml   # Auto-generated config
    └── scripts/            # All AEA scripts
```

**Agent ID:** Auto-generated as `claude-your-project-name`

---

## Next Steps

1. **Read instructions:** `cat .aea/CLAUDE.md`
2. **Test messaging:** `bash .aea/scripts/create-test-scenarios.sh all`
3. **Check messages:** `bash .aea/aea.sh check`
4. **Set up monitoring:** `bash .aea/aea.sh monitor start`

---

## Troubleshooting

**"Cannot find AEA source directory"**
```bash
# Use full path
bash /full/path/to/aea/install.sh
```

**Permission denied**
```bash
chmod +x /path/to/aea/install.sh
```

**Want to uninstall?**
```bash
# Backup and remove
bash /path/to/aea/install.sh  # Choose option 2

# Or remove directly
rm -rf .aea
```

---

## Help

```bash
# View installer help
bash /path/to/aea/install.sh --help

# View AEA help
bash .aea/aea.sh help

# List backups
bash /path/to/aea/install.sh --list
```

---

📖 **Full Guide:** [INSTALL_GUIDE.md](INSTALL_GUIDE.md)
📋 **Protocol Spec:** [PROTOCOL.md](PROTOCOL.md)
💡 **Examples:** [docs/EXAMPLES.md](docs/EXAMPLES.md)
