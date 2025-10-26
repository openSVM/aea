#!/usr/bin/env bash
#
# AEA Upgrade Script
# Updates an existing AEA installation with latest docs, scripts, and prompts
#
# Usage:
#   bash .aea/scripts/aea-upgrade.sh
#   OR from repo root: bash aea.sh upgrade
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine AEA directory
if [ -d ".aea" ]; then
    AEA_DIR=".aea"
elif [ -f "./aea.sh" ]; then
    # We're in .aea directory itself
    AEA_DIR="."
else
    log_error "Not in AEA directory or repository root"
    log_error "Run from repository root, or from .aea/ directory"
    exit 1
fi

# Find AEA source
# Could be either:
# 1. In AEA development repo: /path/to/aea/scripts/aea-upgrade.sh
# 2. In installed .aea: /path/to/project/.aea/scripts/aea-upgrade.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try parent of scripts/ directory first
AEA_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"

# If that doesn't have docs/ and scripts/, it might be installed in .aea/
# Try to find AEA source from environment or use current location
if [ ! -d "$AEA_SOURCE_DIR/docs" ] || [ ! -d "$AEA_SOURCE_DIR/scripts" ]; then
    # Allow override via environment variable
    if [ -n "$AEA_SOURCE" ] && [ -d "$AEA_SOURCE/docs" ]; then
        AEA_SOURCE_DIR="$AEA_SOURCE"
    else
        log_error "Cannot find AEA source directory with docs/ and scripts/"
        log_error "Tried: $AEA_SOURCE_DIR"
        echo ""
        log_info "To upgrade from GitHub (latest):"
        echo "  curl -fsSL https://raw.githubusercontent.com/openSVM/aea/main/scripts/aea-upgrade.sh | bash"
        echo ""
        log_info "To upgrade from local AEA repo:"
        echo "  export AEA_SOURCE=/path/to/aea"
        echo "  bash .aea/scripts/aea-upgrade.sh"
        echo ""
        log_info "Or run from the AEA source repo:"
        echo "  cd /path/to/aea"
        echo "  bash scripts/aea-upgrade.sh"
        exit 1
    fi
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          AEA Protocol - Upgrade Utility                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "AEA Directory: $AEA_DIR"
log_info "Source: $AEA_SOURCE_DIR"
echo ""

# Create backup
BACKUP_DIR="$AEA_DIR/.backup-$(date +%Y%m%d-%H%M%S)"
log_info "Creating backup at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

# Backup current installation (except messages and logs)
for item in docs scripts prompts PROTOCOL.md CLAUDE.md agent-config.yaml; do
    if [ -e "$AEA_DIR/$item" ]; then
        cp -r "$AEA_DIR/$item" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

log_success "Backup created at $BACKUP_DIR"
echo ""

# Track what was upgraded
UPGRADED_COUNT=0

# ==============================================================================
# 1. Update Documentation
# ==============================================================================

log_info "Updating documentation..."

# Ensure docs directory exists
mkdir -p "$AEA_DIR/docs"

if [ -d "$AEA_SOURCE_DIR/docs" ]; then
    DOC_COUNT=0
    for doc_file in "$AEA_SOURCE_DIR/docs"/*.md; do
        if [ -f "$doc_file" ]; then
            filename=$(basename "$doc_file")

            # Check if file is different
            if [ -f "$AEA_DIR/docs/$filename" ]; then
                if ! diff -q "$doc_file" "$AEA_DIR/docs/$filename" >/dev/null 2>&1; then
                    cp "$doc_file" "$AEA_DIR/docs/$filename"
                    log_success "Updated docs/$filename"
                    ((DOC_COUNT++))
                fi
            else
                # New file
                cp "$doc_file" "$AEA_DIR/docs/$filename"
                log_success "Added docs/$filename"
                ((DOC_COUNT++))
            fi
        fi
    done

    if [ $DOC_COUNT -gt 0 ]; then
        log_success "Updated $DOC_COUNT documentation file(s)"
        ((UPGRADED_COUNT += DOC_COUNT))
    else
        log_info "Documentation already up to date"
    fi
else
    log_warning "No docs/ directory in source"
fi

echo ""

# ==============================================================================
# 2. Update Scripts
# ==============================================================================

log_info "Updating scripts..."

# Ensure scripts directory exists
mkdir -p "$AEA_DIR/scripts"

if [ -d "$AEA_SOURCE_DIR/scripts" ]; then
    SCRIPT_COUNT=0

    # List of scripts to update (exclude install-aea.sh and aea-upgrade.sh)
    for script_file in "$AEA_SOURCE_DIR/scripts"/*.sh; do
        if [ -f "$script_file" ]; then
            filename=$(basename "$script_file")

            # Skip installer and upgrader
            if [ "$filename" = "install-aea.sh" ] || [ "$filename" = "aea-upgrade.sh" ]; then
                continue
            fi

            # Check if file is different
            if [ -f "$AEA_DIR/scripts/$filename" ]; then
                if ! diff -q "$script_file" "$AEA_DIR/scripts/$filename" >/dev/null 2>&1; then
                    cp "$script_file" "$AEA_DIR/scripts/$filename"
                    chmod +x "$AEA_DIR/scripts/$filename"
                    log_success "Updated scripts/$filename"
                    ((SCRIPT_COUNT++))
                fi
            else
                # New script
                cp "$script_file" "$AEA_DIR/scripts/$filename"
                chmod +x "$AEA_DIR/scripts/$filename"
                log_success "Added scripts/$filename"
                ((SCRIPT_COUNT++))
            fi
        fi
    done

    if [ $SCRIPT_COUNT -gt 0 ]; then
        log_success "Updated $SCRIPT_COUNT script(s)"
        ((UPGRADED_COUNT += SCRIPT_COUNT))
    else
        log_info "Scripts already up to date"
    fi
else
    log_warning "No scripts/ directory in source"
fi

echo ""

# ==============================================================================
# 3. Update Prompts
# ==============================================================================

log_info "Updating prompts..."

# Ensure prompts directory exists
mkdir -p "$AEA_DIR/prompts"

if [ -d "$AEA_SOURCE_DIR/prompts" ]; then
    PROMPT_COUNT=0
    for prompt_file in "$AEA_SOURCE_DIR/prompts"/*.md; do
        if [ -f "$prompt_file" ]; then
            filename=$(basename "$prompt_file")

            # Check if file is different
            if [ -f "$AEA_DIR/prompts/$filename" ]; then
                if ! diff -q "$prompt_file" "$AEA_DIR/prompts/$filename" >/dev/null 2>&1; then
                    cp "$prompt_file" "$AEA_DIR/prompts/$filename"
                    log_success "Updated prompts/$filename"
                    ((PROMPT_COUNT++))
                fi
            else
                # New prompt
                cp "$prompt_file" "$AEA_DIR/prompts/$filename"
                log_success "Added prompts/$filename"
                ((PROMPT_COUNT++))
            fi
        fi
    done

    if [ $PROMPT_COUNT -gt 0 ]; then
        log_success "Updated $PROMPT_COUNT prompt(s)"
        ((UPGRADED_COUNT += PROMPT_COUNT))
    else
        log_info "Prompts already up to date"
    fi
else
    log_warning "No prompts/ directory in source"
fi

echo ""

# ==============================================================================
# 4. Update PROTOCOL.md
# ==============================================================================

log_info "Checking PROTOCOL.md..."

if [ -f "$AEA_SOURCE_DIR/PROTOCOL.md" ]; then
    if [ -f "$AEA_DIR/PROTOCOL.md" ]; then
        if ! diff -q "$AEA_SOURCE_DIR/PROTOCOL.md" "$AEA_DIR/PROTOCOL.md" >/dev/null 2>&1; then
            cp "$AEA_SOURCE_DIR/PROTOCOL.md" "$AEA_DIR/PROTOCOL.md"
            log_success "Updated PROTOCOL.md"
            ((UPGRADED_COUNT++))
        else
            log_info "PROTOCOL.md already up to date"
        fi
    else
        cp "$AEA_SOURCE_DIR/PROTOCOL.md" "$AEA_DIR/PROTOCOL.md"
        log_success "Added PROTOCOL.md"
        ((UPGRADED_COUNT++))
    fi
else
    log_warning "PROTOCOL.md not found in source"
fi

echo ""

# ==============================================================================
# 5. Update CLAUDE.md (template)
# ==============================================================================

log_info "Checking CLAUDE.md template..."

if [ -f "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" ]; then
    if [ -f "$AEA_DIR/CLAUDE.md" ]; then
        if ! diff -q "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" "$AEA_DIR/CLAUDE.md" >/dev/null 2>&1; then
            log_warning "CLAUDE.md has updates available"
            log_warning "Manual review recommended - backup is at $BACKUP_DIR/CLAUDE.md"
            echo "  To update: cp $AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md $AEA_DIR/CLAUDE.md"
        else
            log_info "CLAUDE.md already up to date"
        fi
    else
        cp "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" "$AEA_DIR/CLAUDE.md"
        log_success "Added CLAUDE.md"
        ((UPGRADED_COUNT++))
    fi
else
    log_warning "CLAUDE.md template not found in source"
fi

echo ""

# ==============================================================================
# Summary
# ==============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ $UPGRADED_COUNT -gt 0 ]; then
    log_success "Upgrade complete! Updated $UPGRADED_COUNT file(s)"
    echo ""
    echo "✅ Documentation updated"
    echo "✅ Scripts updated"
    echo "✅ Prompts updated"
    echo "✅ Protocol specification updated"
    echo ""
    log_info "Backup saved at: $BACKUP_DIR"
    echo ""
    log_info "To rollback if needed:"
    echo "  cp -r $BACKUP_DIR/* $AEA_DIR/"
else
    log_success "Already up to date! No changes needed."
    echo ""
    log_info "Backup preserved at: $BACKUP_DIR"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Show what was NOT updated (preserved)
log_info "Preserved (not modified):"
echo "  ✓ agent-config.yaml (your configuration)"
echo "  ✓ message-*.json (your messages)"
echo "  ✓ .processed/ (your processing history)"
echo "  ✓ agent.log (your activity log)"
echo ""

log_success "AEA is now up to date! 🎉"
