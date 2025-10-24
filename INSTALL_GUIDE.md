# AEA Protocol - Installation Guide

## Quick Start

```bash
# Download AEA
git clone https://github.com/openSVM/aea.git
cd aea

# Install in any project
cd /path/to/your/project
bash /path/to/aea/install.sh
```

That's it! The installer automatically detects your project type and installs AEA appropriately.

---

## Smart Installation

The `install.sh` script is **context-aware** and automatically:

### ✅ Detects Project Type

Supports **100+ programming languages** via package manager detection:

| Language | Package Managers Detected |
|----------|--------------------------|
| **JavaScript/TypeScript** | package.json, yarn.lock, pnpm-lock.yaml, bun.lockb |
| **Python** | requirements.txt, pyproject.toml, Pipfile, conda.yaml |
| **Rust** | Cargo.toml |
| **Go** | go.mod, go.sum |
| **Ruby** | Gemfile, Rakefile |
| **PHP** | composer.json |
| **Java** | pom.xml, build.gradle, build.sbt |
| **.NET/C#** | *.csproj, packages.config, global.json |
| **C/C++** | CMakeLists.txt, Makefile, meson.build, conanfile |
| **Dart/Flutter** | pubspec.yaml |
| **Swift** | Package.swift, Podfile |
| **Elixir** | mix.exs |
| **Haskell** | stack.yaml, *.cabal |
| **OCaml** | dune-project, opam |
| **Clojure** | project.clj, deps.edn |
| **R** | DESCRIPTION, renv.lock |
| **Julia** | Project.toml |
| **Zig** | build.zig |
| **Nim** | *.nimble |
| **Crystal** | shard.yml |
| **D** | dub.json |
| **Terraform** | *.tf |
| **Docker** | Dockerfile, docker-compose.yml |
| **Kubernetes** | YAML with apiVersion |
| ...and more! |

### ✅ Auto-Decides Installation Location

- **Project directory?** → Installs in `.aea/` subdirectory
- **Regular directory?** → Asks where to install

### ✅ Handles Existing Installations

If `.aea/` already exists:

1. **Complete installation** → Offers repair or delete
2. **Partial installation** → Offers repair
3. **No installation** → Proceeds with fresh install

---

## Installation Scenarios

### Scenario 1: Installing in a Rust Project

```bash
cd /path/to/my-rust-app
bash /path/to/aea/install.sh
```

**Output:**
```
[INFO] Current directory: /path/to/my-rust-app
[INFO] Detected project type(s): Rust/Cargo
[SUCCESS] Installing AEA in project directory
▶ Installing AEA in: /path/to/my-rust-app
...
[SUCCESS] AEA installed successfully!
```

### Scenario 2: Installing in a Non-Project Directory

```bash
cd ~/random-files
bash /path/to/aea/install.sh
```

**Output:**
```
[INFO] Not a project directory (no package managers detected)

This doesn't appear to be a project directory

Where would you like to install AEA?
  1) Current directory (.aea subfolder)
  2) Cancel

Choose [1-2]: 1
```

### Scenario 3: Repairing Existing Installation

```bash
cd /path/to/project
bash /path/to/aea/install.sh
```

**Output:**
```
⚠ AEA is already installed in this directory

What would you like to do?
  1) Repair installation (fix missing files)
  2) Delete and backup (move to ~/.aea/backups)
  3) Cancel

Choose [1-3]: 1
```

### Scenario 4: Deleting with Backup

```bash
cd /path/to/project
bash /path/to/aea/install.sh
```

**Choose option 2:**
```
This will backup and remove the existing .aea directory
Are you sure? (yes/no): yes

[SUCCESS] Deleted and backed up to: ~/.aea/backups/my-project-20251022-153045

Install fresh AEA now? (yes/no): yes
```

---

## Backup Management

### Automatic Backups

When you delete an AEA installation, it's **automatically backed up** to:

```
~/.aea/backups/
└── project-name-TIMESTAMP/
    ├── aea-backup/           # Your .aea directory
    └── BACKUP_INFO.json      # Metadata
```

### Backup Metadata

Each backup includes comprehensive metadata:

```json
{
  "timestamp": "2025-10-22T15:30:45Z",
  "source_path": "/path/to/project",
  "project_name": "my-project",
  "reason": "user-requested-deletion",
  "backup_size": "2.3M",
  "message_count": 15,
  "restore_command": "mv ~/.aea/backups/... /path/to/project/.aea"
}
```

### List Backups

```bash
bash install.sh --list
```

**Output:**
```
Available backups:

  my-rust-app-20251022-153045
    Project: my-rust-app
    Date: 2025-10-22T15:30:45Z
    Reason: user-requested-deletion
    Size: 2.3M

  backend-api-20251021-091523
    Project: backend-api
    Date: 2025-10-21T09:15:23Z
    Reason: user-requested-deletion
    Size: 5.1M
```

### Restore from Backup

```bash
# Find your backup
ls ~/.aea/backups/

# Restore it
mv ~/.aea/backups/my-project-TIMESTAMP/aea-backup /path/to/project/.aea
```

---

## Advanced Usage

### Running from Different Locations

The installer works from **anywhere**:

```bash
# From AEA source directory
cd /path/to/aea
./install.sh

# From a project directory
cd /path/to/my-project
bash /path/to/aea/install.sh

# From .aea directory (if copying installer)
cd /path/to/my-project/.aea
bash install.sh
```

### Force Reinstall

```bash
bash install.sh --force
```

### Repair Only

```bash
bash install.sh --repair
```

---

## What Gets Installed

When AEA is installed in your project:

```
your-project/
├── .aea/
│   ├── aea.sh                  # Main command interface
│   ├── PROTOCOL.md             # Protocol specification
│   ├── CLAUDE.md               # Instructions for Claude Code
│   ├── agent-config.yaml       # Configuration (auto-generated)
│   ├── scripts/                # Operational scripts
│   │   ├── aea-check.sh
│   │   ├── aea-send.sh
│   │   ├── aea-monitor.sh
│   │   └── ...
│   ├── prompts/                # Prompt templates
│   ├── docs/                   # Documentation
│   ├── .processed/             # Message tracking (runtime)
│   ├── logs/                   # Log directory (runtime)
│   └── .gitignore              # Ignores runtime files
│
└── your-project-files...
```

### Configuration is Auto-Generated

The `agent-config.yaml` is customized for your project:

```yaml
agent:
  id: "claude-your-project-name"  # Based on directory name
  type: "claude-sonnet-4.5"
  repository: "."
  ...
```

---

## Verification

After installation, verify it works:

```bash
# Check for messages
bash .aea/aea.sh check

# View help
bash .aea/aea.sh help

# Set up global command
bash .aea/aea.sh setup-global
```

---

## Troubleshooting

### "Cannot find AEA source directory"

**Cause:** Running `install.sh` from a location where it can't find the AEA repository.

**Solution:** Run from the AEA repository or specify the full path:
```bash
bash /full/path/to/aea/install.sh
```

### "Permission denied"

**Cause:** Script not executable.

**Solution:**
```bash
chmod +x /path/to/aea/install.sh
```

### Backup Directory Full

**Cause:** Too many backups in `~/.aea/backups/`.

**Solution:**
```bash
# List backups
bash install.sh --list

# Remove old backups
rm -rf ~/.aea/backups/old-project-*
```

---

## Uninstallation

To remove AEA while keeping a backup:

```bash
cd /path/to/project
bash /path/to/aea/install.sh
# Choose option 2 (Delete and backup)
```

To remove without backup:

```bash
rm -rf /path/to/project/.aea
```

---

## Next Steps

After installation:

1. **Check documentation:** `cat .aea/CLAUDE.md`
2. **Test messaging:** `bash .aea/scripts/create-test-scenarios.sh all`
3. **Set up monitoring:** `bash .aea/aea.sh monitor start`
4. **Read the protocol:** `cat .aea/PROTOCOL.md`

---

## Support

For issues or questions:
- Check `.aea/CLAUDE.md` for usage instructions
- Review `.aea/PROTOCOL.md` for protocol details
- Check backups in `~/.aea/backups/`
