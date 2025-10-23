# Contributing to AEA Protocol

Thank you for your interest in contributing to the AEA (Agentic Economic Activity) Protocol! This document provides guidelines for contributing to the project.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)

---

## Code of Conduct

Be respectful, constructive, and collaborative. We're all here to improve inter-agent communication.

---

## Getting Started

### Prerequisites

- `bash` 4.0+
- `jq` for JSON parsing
- `openssl` (optional, for cryptographic features)
- Git for version control

### Clone and Setup

```bash
git clone <repository-url>
cd aea

# Verify scripts work
bash aea.sh test

# Create test scenarios
bash scripts/create-test-scenarios.sh all
bash aea.sh check
```

---

## Development Workflow

### Repository Structure

This repository has a **dual purpose**:

1. **Protocol source** - Scripts, specs, and tools for developing AEA
2. **Self-hosting** - Uses `.aea/` subdirectory to dogfood the protocol

**Key files**:
- `CLAUDE.md` - For working ON the protocol (development context)
- `templates/CLAUDE_INSTALLED.md` - For working IN repos using AEA
- `PROTOCOL.md` - Protocol specification
- `scripts/` - Core operational scripts
- `scripts/install-aea.sh` - Installation script
- `.aea/` - Self-testing area (dogfooding)

### Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** to scripts, documentation, or protocol

3. **Test locally**:
   ```bash
   # Test in this repo
   bash scripts/create-test-scenarios.sh all
   bash aea.sh check
   bash aea.sh test

   # Test installation
   mkdir -p /tmp/test-install
   bash scripts/install-aea.sh /tmp/test-install
   cd /tmp/test-install && bash .aea/scripts/aea-check.sh
   ```

4. **Update documentation** if needed:
   - `CLAUDE.md` if changing development workflows
   - `templates/CLAUDE_INSTALLED.md` if changing usage
   - `PROTOCOL.md` if changing protocol specification
   - `README.md` if changing user-facing features

5. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: Add feature description"
   ```

---

## Testing

### Run Test Suite

```bash
# Run all tests
bash aea.sh test

# Should see: Tests Passed: 16+/17
```

### Create Test Scenarios

```bash
# Create individual scenarios
bash scripts/create-test-scenarios.sh simple-question
bash scripts/create-test-scenarios.sh urgent-issue

# Create all scenarios
bash scripts/create-test-scenarios.sh all
```

### Test Installation

```bash
# Test in a fresh directory
mkdir -p /tmp/test-aea-install
bash scripts/install-aea.sh /tmp/test-aea-install

# Verify installation
cd /tmp/test-aea-install
ls -la .aea/
cat .aea/CLAUDE.md  # Should be CLAUDE_INSTALLED.md content
bash .aea/scripts/aea-check.sh  # Should work
```

### Add New Tests

When adding features:

1. Add test to `scripts/test-features.sh`
2. Follow existing pattern (Test X.Y format)
3. Use `print_result` and `add_test_result`
4. Ensure JSON validation between operations

---

## Documentation

### When to Update Which File

| File | Update When... |
|------|---------------|
| `CLAUDE.md` | Changing development workflows, testing, or installation |
| `templates/CLAUDE_INSTALLED.md` | Changing how users interact with installed AEA |
| `PROTOCOL.md` | Changing message format, protocol rules, or versioning |
| `README.md` | Changing user-facing features or quick start |
| `CHANGELOG.md` | Adding features, fixing bugs, or making changes |

### Documentation Standards

- Use clear, concise language
- Include code examples where helpful
- Separate development context from usage context
- Reference files with line numbers where applicable
- Update examples to match current protocol version

---

## Submitting Changes

### Pull Request Process

1. **Ensure all tests pass**:
   ```bash
   bash aea.sh test
   ```

2. **Update documentation**:
   - Update `CHANGELOG.md` with your changes
   - Update relevant docs if features changed
   - Add examples if introducing new features

3. **Create pull request**:
   - Clear title describing the change
   - Reference any related issues
   - Include test results
   - Describe what was changed and why

4. **PR template** (if applicable):
   ```markdown
   ## Description
   Brief description of changes

   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Breaking change

   ## Testing
   - [ ] Ran test suite (X/17 passing)
   - [ ] Tested installation in fresh directory
   - [ ] Tested commands in both contexts

   ## Documentation
   - [ ] Updated CLAUDE.md (if dev workflow changed)
   - [ ] Updated CLAUDE_INSTALLED.md (if usage changed)
   - [ ] Updated PROTOCOL.md (if protocol changed)
   - [ ] Updated CHANGELOG.md
   ```

---

## Style Guidelines

### Bash Scripts

- Use `#!/usr/bin/env bash` shebang
- Use `set -e` for error handling
- Quote variables: `"$variable"`
- Use relative paths (for portability)
- Add comments for complex logic
- Use functions for reusability

**Example**:
```bash
#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

my_function() {
    local arg="$1"
    echo "Processing: $arg"
}
```

### JSON Files

- Use 2-space indentation
- Include required fields per PROTOCOL.md
- Use ISO 8601 timestamps (UTC)
- Validate with `jq '.' file.json`

### Markdown

- Use ATX-style headers (`#`)
- Code blocks with language tags
- One sentence per line (for diffs)
- Add blank lines between sections

---

## Areas Needing Contribution

### High Priority

- [ ] API-based Claude instance triggering
- [ ] Message threading support
- [ ] Performance benchmarking
- [ ] Windows compatibility testing
- [ ] Additional test scenarios

### Medium Priority

- [ ] Web UI for monitoring
- [ ] GitHub Actions integration
- [ ] Docker containerization
- [ ] Message analytics/metrics
- [ ] Example multi-repo setup

### Low Priority

- [ ] Alternative message transports
- [ ] Plugin system
- [ ] Message templates library
- [ ] Visual flow diagrams
- [ ] Video tutorials

---

## Questions?

- **Protocol questions**: See `PROTOCOL.md` or `docs/aea-rules.md`
- **Development questions**: See `CLAUDE.md`
- **Usage questions**: See `README.md` or `templates/CLAUDE_INSTALLED.md`
- **Installation issues**: Check `scripts/install-aea.sh`

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see `LICENSE` file).

---

**Thank you for contributing to AEA Protocol!** 🚀
