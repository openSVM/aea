#!/bin/bash
# uninstall-aea.sh - Safely remove AEA from a repository
#
# Usage:
#   bash scripts/uninstall-aea.sh              # Uninstall from current directory
#   bash scripts/uninstall-aea.sh /path/to/repo # Uninstall from specified directory

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Determine target directory
TARGET_DIR="${1:-.}"

if ! cd "$TARGET_DIR"; then
    log_error "Failed to change to directory: $TARGET_DIR"
    exit 1
fi

TARGET_DIR="$(pwd)"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           AEA Protocol Uninstaller                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

log_info "Checking if AEA is installed in: $TARGET_DIR"

if [ ! -d ".aea" ]; then
    log_error "AEA is not installed in this directory (no .aea/ found)"
    exit 1
fi

log_success "AEA installation found"

# ==============================================================================
# Interactive Confirmation
# ==============================================================================

echo ""
echo -e "${YELLOW}⚠️  WARNING: This will remove:${NC}"
echo "  • .aea/ directory and all messages"
echo "  • .claude/commands/aea.md"
echo "  • AEA sections from CLAUDE.md"
echo "  • AEA hooks from .claude/settings.json"
echo "  • Registry entry from ~/.config/aea/agents.yaml"
echo ""
echo "📍 Target: $TARGET_DIR"
echo ""

# Count messages properly
message_files=$(find .aea -maxdepth 1 -name "message-*.json" -type f 2>/dev/null || true)
if [ -n "$message_files" ]; then
    message_count=$(printf '%s\n' "$message_files" | wc -l)
else
    message_count=0
fi

if [ "$message_count" -gt 0 ]; then
    echo -e "${YELLOW}📬 WARNING: $message_count unprocessed/processed message(s) will be deleted${NC}"
    echo ""
fi

read -p "Are you sure you want to uninstall AEA? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_info "Uninstall cancelled"
    exit 0
fi

# ==============================================================================
# Backup Option
# ==============================================================================

echo ""
read -p "Do you want to backup messages before uninstalling? (yes/no): " backup

if [ "$backup" = "yes" ]; then
    backup_dir=".aea-backup-$(date +%Y%m%d-%H%M%S)"
    log_info "Creating backup: $backup_dir"

    mkdir -p "$backup_dir"

    # Backup messages safely
    if [ -d ".aea" ]; then
        # Copy message files if they exist
        for msg in .aea/message-*.json; do
            [ -e "$msg" ] || continue
            cp "$msg" "$backup_dir/" 2>/dev/null || {
                log_warning "Failed to backup: $msg"
            }
        done

        # Copy log and config if they exist
        [ -f ".aea/agent.log" ] && cp .aea/agent.log "$backup_dir/" 2>/dev/null || true
        [ -f ".aea/agent-config.yaml" ] && cp .aea/agent-config.yaml "$backup_dir/" 2>/dev/null || true
    fi

    # Create backup summary
    cat > "$backup_dir/BACKUP_INFO.txt" << EOF
AEA Backup
Date: $(date)
Directory: $TARGET_DIR
Message Count: $message_count

Contents:
- message-*.json files
- agent.log
- agent-config.yaml

To restore:
1. Reinstall AEA: bash /path/to/aea/scripts/install-aea.sh
2. Copy messages back: cp $backup_dir/message-*.json .aea/
EOF

    log_success "Backup created: $backup_dir"
fi

# ==============================================================================
# Stop Monitor
# ==============================================================================

echo ""
log_info "Stopping AEA monitor (if running)..."

if [ -f ".aea/scripts/aea-monitor.sh" ]; then
    bash .aea/scripts/aea-monitor.sh stop 2>/dev/null || log_warning "Monitor was not running"
else
    log_info "No monitor script found"
fi

# ==============================================================================
# Remove from Registry
# ==============================================================================

echo ""
log_info "Removing from agent registry..."

# Try to get agent ID
agent_id=""
if [ -f ".aea/agent-config.yaml" ]; then
    agent_id=$(grep "^agent_id:" .aea/agent-config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
fi

if [ -z "$agent_id" ]; then
    agent_id="claude-$(basename "$TARGET_DIR")"
fi

# Remove from registry if aea-registry.sh is available
if [ -f ".aea/scripts/aea-registry.sh" ]; then
    bash .aea/scripts/aea-registry.sh unregister "$agent_id" 2>/dev/null || log_warning "Could not remove from registry (may not be registered)"
else
    log_warning "Registry script not found, skipping registry cleanup"
fi

# ==============================================================================
# Remove Files
# ==============================================================================

echo ""
log_info "Removing AEA files..."

# Remove .aea directory
if [ -d ".aea" ]; then
    rm -rf .aea
    log_success "Removed .aea/ directory"
fi

# Remove .claude/commands/aea.md
if [ -f ".claude/commands/aea.md" ]; then
    rm -f .claude/commands/aea.md
    log_success "Removed .claude/commands/aea.md"
fi

# ==============================================================================
# Clean .claude/settings.json
# ==============================================================================

log_info "Cleaning .claude/settings.json..."

if [ -f ".claude/settings.json" ] && command -v jq &>/dev/null; then
    # Remove AEA hooks
    jq '
        if .hooks then
            .hooks |= with_entries(
                select(.value.command | contains("aea") | not)
            )
        else
            .
        end
    ' .claude/settings.json > .claude/settings.json.tmp

    mv .claude/settings.json.tmp .claude/settings.json
    log_success "Cleaned AEA hooks from .claude/settings.json"
elif [ -f ".claude/settings.json" ]; then
    log_warning "jq not found, cannot clean .claude/settings.json automatically"
    log_info "Please manually remove AEA hooks from .claude/settings.json"
fi

# ==============================================================================
# Clean CLAUDE.md
# ==============================================================================

log_info "Cleaning CLAUDE.md..."

if [ -f "CLAUDE.md" ]; then
    # Remove AEA section using awk (safer than sed)
    local tempfile="CLAUDE.md.tmp.$$"

    awk '
        /## 📬 Inter-Agent Communication \(AEA Protocol\)/ { skip = 1; next }
        skip && /^---$/ { skip = 0; next }
        !skip { print }
    ' CLAUDE.md > "$tempfile" 2>/dev/null

    if [ -s "$tempfile" ]; then
        # Remove trailing empty lines safely
        awk '
            NF > 0 { blank = 0; print; next }
            { blank++; line[blank] = $0 }
            END {
                if (NF > 0) {
                    for (i = 1; i <= blank; i++) print line[i]
                }
            }
        ' "$tempfile" > "$tempfile.2"

        if [ -s "$tempfile.2" ]; then
            mv "$tempfile.2" "CLAUDE.md" && rm -f "$tempfile"
            log_success "Cleaned AEA section from CLAUDE.md"
        else
            log_warning "Could not automatically remove AEA section from CLAUDE.md"
            rm -f "$tempfile" "$tempfile.2"
        fi
    else
        log_warning "Could not automatically remove AEA section from CLAUDE.md"
        rm -f "$tempfile"
    fi
fi

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Uninstall Complete                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

log_success "AEA has been uninstalled from: $TARGET_DIR"

if [ "$backup" = "yes" ]; then
    echo ""
    echo "📦 Backup saved to: $backup_dir"
    echo "   Keep this if you want to restore messages later"
fi

echo ""
echo "🧹 Cleaned up:"
echo "  ✓ .aea/ directory removed"
echo "  ✓ .claude/commands/aea.md removed"
echo "  ✓ AEA hooks removed from .claude/settings.json"
echo "  ✓ AEA section removed from CLAUDE.md"
echo "  ✓ Agent unregistered from ~/.config/aea/agents.yaml"

echo ""
echo "📝 Manual cleanup (if needed):"
echo "  • Review CLAUDE.md for any remaining AEA references"
echo "  • Check .claude/settings.json if jq was not available"
echo "  • Remove backup: rm -rf $backup_dir"

echo ""
log_info "To reinstall AEA later:"
echo "  bash /path/to/aea/scripts/install-aea.sh $TARGET_DIR"

echo ""
