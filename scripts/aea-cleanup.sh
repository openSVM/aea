#!/bin/bash
# aea-cleanup.sh - Clean up old AEA messages and logs
#
# Usage:
#   bash .aea/scripts/aea-cleanup.sh              # Interactive mode
#   bash .aea/scripts/aea-cleanup.sh --auto       # Automatic (30 days)
#   bash .aea/scripts/aea-cleanup.sh --days 60    # Custom age

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

# Default settings
DAYS_OLD=30
AUTO_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --days)
            DAYS_OLD="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
AEA Cleanup - Remove old messages and logs

Usage:
  $(basename "$0")               # Interactive mode
  $(basename "$0") --auto        # Automatic (30 days)
  $(basename "$0") --days 60     # Custom age

Options:
  --auto       Run without prompts (archive files older than 30 days)
  --days N     Set age threshold (default: 30)
  --help       Show this help

Examples:
  $(basename "$0")               # Interactive cleanup
  $(basename "$0") --auto        # Auto-archive 30+ day old messages
  $(basename "$0") --days 7      # Interactive, 7+ days old

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ==============================================================================
# Checks
# ==============================================================================

if [ ! -d ".aea" ]; then
    echo "ERROR: Not in an AEA repository (no .aea/ directory)"
    exit 1
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              AEA Cleanup Utility                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ==============================================================================
# Find Old Files
# ==============================================================================

log_info "Scanning for files older than $DAYS_OLD days..."

# Find old messages (count properly)
OLD_MESSAGES=$(find .aea -maxdepth 1 -name "message-*.json" -type f -mtime +"$DAYS_OLD" 2>/dev/null || true)
if [ -n "$OLD_MESSAGES" ]; then
    OLD_MESSAGE_COUNT=$(printf '%s\n' "$OLD_MESSAGES" | wc -l)
else
    OLD_MESSAGE_COUNT=0
fi

# Find old processed markers (count properly)
OLD_PROCESSED=$(find .aea/.processed -type f -mtime +"$DAYS_OLD" 2>/dev/null || true)
if [ -n "$OLD_PROCESSED" ]; then
    OLD_PROCESSED_COUNT=$(printf '%s\n' "$OLD_PROCESSED" | wc -l)
else
    OLD_PROCESSED_COUNT=0
fi

# Check log size
LOG_SIZE=0
if [ -f ".aea/agent.log" ]; then
    LOG_SIZE=$(du -h .aea/agent.log | awk '{print $1}')
fi

# ==============================================================================
# Display Summary
# ==============================================================================

echo ""
echo "📊 Cleanup Summary:"
echo "  • Old messages (${DAYS_OLD}+ days): $OLD_MESSAGE_COUNT"
echo "  • Old processed markers: $OLD_PROCESSED_COUNT"
echo "  • Agent log size: $LOG_SIZE"
echo ""

if [ $OLD_MESSAGE_COUNT -eq 0 ] && [ $OLD_PROCESSED_COUNT -eq 0 ]; then
    log_success "Nothing to clean up!"
    exit 0
fi

# ==============================================================================
# Confirm Action
# ==============================================================================

if [ "$AUTO_MODE" = false ]; then
    echo "🗑️  This will:"
    echo "  1. Archive old messages to .aea/.archive/"
    echo "  2. Remove old processed markers"
    echo "  3. Optionally rotate agent.log"
    echo ""

    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
fi

# ==============================================================================
# Archive Old Messages
# ==============================================================================

if [ $OLD_MESSAGE_COUNT -gt 0 ]; then
    log_info "Archiving $OLD_MESSAGE_COUNT old message(s)..."

    # Create archive directory with timestamp
    ARCHIVE_DIR=".aea/.archive/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$ARCHIVE_DIR"

    # Move old messages safely
    printf '%s\n' "$OLD_MESSAGES" | while IFS= read -r msg; do
        # Skip empty lines
        [ -n "$msg" ] || continue
        # Check file exists before moving
        if [ -f "$msg" ]; then
            mv "$msg" "$ARCHIVE_DIR/" || {
                log_warning "Failed to move: $msg"
            }
        fi
    done

    # Create archive manifest
    cat > "$ARCHIVE_DIR/MANIFEST.txt" << EOF
AEA Message Archive
Created: $(date)
Age threshold: $DAYS_OLD days
Message count: $OLD_MESSAGE_COUNT

These messages were older than $DAYS_OLD days and have been archived.

To restore:
1. cp $ARCHIVE_DIR/message-*.json .aea/
2. bash .aea/scripts/aea-check.sh

To permanently delete:
rm -rf $ARCHIVE_DIR
EOF

    log_success "Archived to: $ARCHIVE_DIR"
fi

# ==============================================================================
# Clean Processed Markers
# ==============================================================================

if [ $OLD_PROCESSED_COUNT -gt 0 ]; then
    log_info "Removing $OLD_PROCESSED_COUNT old processed marker(s)..."

    printf '%s\n' "$OLD_PROCESSED" | while IFS= read -r marker; do
        # Skip empty lines
        [ -n "$marker" ] || continue
        if [ -f "$marker" ]; then
            rm -f "$marker" || {
                log_warning "Failed to remove: $marker"
            }
        fi
    done

    log_success "Processed markers cleaned"
fi

# ==============================================================================
# Log Rotation
# ==============================================================================

if [ -f ".aea/agent.log" ]; then
    log_info "Agent log: $LOG_SIZE"

    # Get size in KB for comparison
    LOG_SIZE_KB=$(du -k .aea/agent.log | awk '{print $1}')

    if [ $LOG_SIZE_KB -gt 1024 ]; then
        # Log is over 1MB
        if [ "$AUTO_MODE" = true ]; then
            rotate_log=true
        else
            echo ""
            read -p "Log is large ($LOG_SIZE). Rotate it? (yes/no): " rotate_log
            [ "$rotate_log" = "yes" ] && rotate_log=true || rotate_log=false
        fi

        if [ "$rotate_log" = true ]; then
            log_info "Rotating agent.log..."

            # Keep last 1000 lines (atomic operation)
            if tail -1000 .aea/agent.log > .aea/agent.log.tmp 2>/dev/null; then
                # Backup original
                if mv .aea/agent.log .aea/agent.log.old 2>/dev/null; then
                    # Install new version
                    if mv .aea/agent.log.tmp .aea/agent.log 2>/dev/null; then
                        # Compress old log
                        gzip .aea/agent.log.old 2>/dev/null || true
                        log_success "Log rotated (old: .aea/agent.log.old.gz)"
                    else
                        # Restore backup if new install failed
                        mv .aea/agent.log.old .aea/agent.log
                        rm -f .aea/agent.log.tmp
                        log_warning "Failed to install rotated log, restored original"
                    fi
                else
                    rm -f .aea/agent.log.tmp
                    log_warning "Failed to backup original log, rotation cancelled"
                fi
            else
                rm -f .aea/agent.log.tmp
                log_warning "Failed to create rotated log"
            fi
        fi
    fi
fi

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Cleanup Complete                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $OLD_MESSAGE_COUNT -gt 0 ]; then
    echo "✓ Archived $OLD_MESSAGE_COUNT message(s)"
fi

if [ $OLD_PROCESSED_COUNT -gt 0 ]; then
    echo "✓ Cleaned $OLD_PROCESSED_COUNT processed marker(s)"
fi

if [ -f ".aea/agent.log.old.gz" ]; then
    echo "✓ Rotated agent.log"
fi

echo ""
echo "📂 Archives are kept in: .aea/.archive/"
echo "   Review and delete when no longer needed"

echo ""
echo "💡 Schedule regular cleanup with:"
echo "   crontab -e"
echo "   # Add: 0 2 * * * cd /path/to/repo && bash .aea/scripts/aea-cleanup.sh --auto"

echo ""
