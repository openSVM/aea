# Changelog

All notable changes to the AEA (Agentic Economic Activity) Protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-10-22

### Added
- Initial release of AEA Protocol v0.1.0
- File-based asynchronous messaging between Claude Code agents
- Message types: question, issue, update, request, handoff, response
- Auto-processing policies based on message type and priority
- Background monitoring daemon with PID management
- Multi-project support via centralized configuration
- Cryptographic security (ED25519 signatures, AES-256-GCM encryption)
- Installation script for easy deployment
- Comprehensive documentation (CLAUDE.md, PROTOCOL.md, README.md)
- Test suite with 16/17 passing tests
- Test scenario generator for development
- Integration with Claude Code via slash commands

### 🎉 Hybrid Autonomy (Added 2025-10-22)
- **Agent Registry System** (`aea-registry.sh`) - Centralized agent discovery and routing
- **Cross-Repository Message Delivery** - Automatic message delivery via registry lookup
- **Autonomous Message Processor** (`aea-auto-processor.sh`) - Fully autonomous processing for simple operations
- **Smart Classification** - Decision matrix based on message type and priority
- **Auto-Responders** - Automatic responses for simple queries, updates, and acknowledgments
- **Smart Escalation** - Complex operations escalated to Claude with user approval
- **Claude Code Hooks Integration** - SessionStart and Stop hooks call auto-processor
- **Rate Limiting** - Process max 10 messages per hook invocation (prevents hangs)
- **JSON Validation** - Malformed messages skipped gracefully with error logging
- **Autonomy Level**: 75-80% for simple operations, with safe escalation for complex tasks

### Architecture
- Message processing pipeline with idempotency via `.processed/` markers
- Adaptive retry with health-based backoff
- Webhook support for external notifications
- Multi-hop messaging with routing path tracking
- TTL-based message expiration (default 30 days)

### Documentation
- **CLAUDE.md** - Development context (working ON the protocol)
- **templates/CLAUDE_INSTALLED.md** - Usage context (working IN repos with AEA)
- **PROTOCOL.md** - Complete protocol specification
- **README.md** - Usage guide for installed repos
- **docs/aea-rules.md** - Integration rules for agents
- **docs/GETTING_STARTED.md** - Quick start guide
- **docs/GLOBAL_COMMAND.md** - Global alias setup

### Security
- Optional message signing with ED25519
- Optional message encryption with AES-256-GCM
- Safety policies requiring approval for risky operations
- Key storage in `~/.aea/{agent-id}/{repo}/{branch}/`

### Known Issues
- Test 2.1 may fail on subsequent runs due to persisted test data (not a bug, run `bash aea.sh test` fresh)
- `create-test-scenarios.sh` requires `.aea/` directory to exist (fixed in this release)

### Notes
- This is a pre-release version (v0.1.0) for early adopters
- Protocol may evolve based on real-world usage
- Contributions welcome (see CONTRIBUTING.md)

## [Unreleased]

### Planned Features
- API-based triggering of Claude instances
- Message queue with priority handling
- Broadcast messaging to multiple agents
- Message threading and conversation tracking
- Performance metrics and analytics
- Web UI for message monitoring
- GitHub Actions integration
- Docker containerization

---

## Version History

- **v0.1.0** (2025-10-22) - Initial release with core protocol features
