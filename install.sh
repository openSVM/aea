#!/usr/bin/env bash
# AEA Protocol - Standalone Installer
# Downloads and installs AEA from GitHub
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/openSVM/aea/main/install.sh | bash
#   bash install.sh [TARGET_DIR]
#   bash install.sh --help

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GITHUB_REPO="openSVM/aea"
GITHUB_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}▶${NC} $1"; }

show_help() {
    cat << EOF
AEA Protocol - Standalone Installer

USAGE:
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | bash
    bash install.sh [TARGET_DIR]
    bash install.sh --help

OPTIONS:
    TARGET_DIR      Directory to install AEA (default: current directory)
    --help          Show this help message

EXAMPLES:
    # Install in current directory
    bash install.sh

    # Install in specific directory
    bash install.sh /path/to/project

    # One-liner from anywhere
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | bash

WHAT IT DOES:
    1. Downloads AEA files from GitHub
    2. Creates .aea/ directory structure
    3. Installs scripts, configs, and documentation
    4. Sets up Claude Code integration

EOF
    exit 0
}

# ==============================================================================
# Main Installation Logic
# ==============================================================================

install_aea() {
    local target_dir="${1:-.}"

    # Validate and resolve absolute path
    if [ ! -d "$target_dir" ]; then
        log_error "Directory does not exist: $target_dir"
        exit 1
    fi

    if [ ! -w "$target_dir" ]; then
        log_error "Directory is not writable: $target_dir"
        exit 1
    fi

    target_dir="$(cd "$target_dir" && pwd)"

    log_info "Installing AEA Protocol in: $target_dir"

    # Check if .aea already exists
    if [ -d "$target_dir/.aea" ]; then
        log_warning ".aea directory already exists in $target_dir"

        # Check if running interactively (not piped)
        if [ -t 0 ]; then
            echo -e "${YELLOW}Options:${NC}"
            echo "  1) Backup and reinstall"
            echo "  2) Cancel installation"
            read -p "Choose (1/2): " choice
        else
            # Non-interactive mode: auto-backup
            log_info "Non-interactive mode detected. Auto-backing up existing installation."
            choice="1"
        fi

        case "$choice" in
            1)
                local backup_dir="$HOME/.aea/backups/backup-$(date +%Y%m%d-%H%M%S)"
                mkdir -p "$backup_dir"
                log_step "Backing up to $backup_dir"
                cp -r "$target_dir/.aea" "$backup_dir/"
                rm -rf "$target_dir/.aea"
                ;;
            *)
                log_info "Installation cancelled"
                exit 0
                ;;
        esac
    fi

    # Create directory structure
    log_step "Creating .aea directory structure..."
    mkdir -p "$target_dir/.aea"/{scripts,prompts,docs,.processed}

    # Download core files
    log_step "Downloading AEA files from GitHub..."

    local files_to_download=(
        "aea.sh:.aea/"
        "agent-config.yaml:.aea/"
        "PROTOCOL.md:.aea/"
        "scripts/aea-check.sh:.aea/scripts/"
        "scripts/aea-send.sh:.aea/scripts/"
        "scripts/aea-monitor.sh:.aea/scripts/"
        "scripts/aea-registry.sh:.aea/scripts/"
        "scripts/aea-cleanup.sh:.aea/scripts/"
        "scripts/aea-common.sh:.aea/scripts/"
        "scripts/aea-validate-message.sh:.aea/scripts/"
        "scripts/aea-issues.sh:.aea/scripts/"
        "scripts/process-messages-iterative.sh:.aea/scripts/"
        "scripts/uninstall-aea.sh:.aea/scripts/"
        "scripts/setup-global-alias.sh:.aea/scripts/"
        "prompts/check-messages.md:.aea/prompts/"
        "templates/CLAUDE_INSTALLED.md:.aea/CLAUDE.md"
        "docs/aea-rules.md:.aea/docs/"
        "docs/GETTING_STARTED.md:.aea/docs/"
        "docs/EXAMPLES.md:.aea/docs/"
        "docs/SECURITY.md:.aea/docs/"
        "docs/INSTALLATION.md:.aea/docs/"
    )

    local failed_downloads=0
    for file_mapping in "${files_to_download[@]}"; do
        local source_file="${file_mapping%%:*}"
        local dest_path="${file_mapping##*:}"
        local url="${GITHUB_RAW_URL}/${source_file}"
        local dest="${target_dir}/${dest_path}$(basename "$source_file")"

        # Special case for CLAUDE_INSTALLED.md -> CLAUDE.md
        if [[ "$source_file" == "templates/CLAUDE_INSTALLED.md" ]]; then
            dest="${target_dir}/.aea/CLAUDE.md"
        fi

        if curl -fsSL "$url" -o "$dest"; then
            echo -e "  ${GREEN}✓${NC} $(basename "$source_file")"
        else
            echo -e "  ${RED}✗${NC} $(basename "$source_file")"
            ((failed_downloads++))
        fi
    done

    if [ $failed_downloads -gt 0 ]; then
        log_error "Failed to download $failed_downloads file(s)"
        log_error "Installation incomplete. Please check your internet connection."
        exit 1
    fi

    # Make scripts executable
    log_step "Setting file permissions..."
    chmod +x "$target_dir/.aea/aea.sh"
    chmod +x "$target_dir/.aea/scripts/"*.sh

    # Generate unique agent ID
    log_step "Configuring agent..."
    # Portable random ID generation
    if [ -c /dev/urandom ]; then
        local agent_id="agent-$(date +%s)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    else
        local agent_id="agent-$(date +%s)-$(printf '%04x' $$)"
    fi
    local project_name="$(basename "$target_dir")"

    # Update agent-config.yaml (portable sed)
    if [ -f "$target_dir/.aea/agent-config.yaml" ]; then
        local temp_config="$target_dir/.aea/agent-config.yaml.tmp"
        awk -v id="$agent_id" -v name="$project_name" '
            /^  id:/ { print "  id: \"" id "\""; next }
            /^  name:/ { print "  name: \"" name "\""; next }
            { print }
        ' "$target_dir/.aea/agent-config.yaml" > "$temp_config"

        if [ -s "$temp_config" ]; then
            mv "$temp_config" "$target_dir/.aea/agent-config.yaml"
        else
            log_error "Failed to update agent-config.yaml"
            rm -f "$temp_config"
        fi
    fi

    # Setup .claude directory for hooks
    log_step "Setting up Claude Code integration..."
    mkdir -p "$target_dir/.claude/commands"

    # Create /aea slash command
    cat > "$target_dir/.claude/commands/aea.md" << 'EOF'
Check for AEA messages and process them:

1. Run: bash .aea/scripts/aea-check.sh
2. If messages found, read and analyze them
3. Take appropriate action based on message type
4. Mark messages as processed
EOF

    # Setup hooks in .claude/settings.json
    # Preserve existing settings by merging
    if [ -f "$target_dir/.claude/settings.json" ]; then
        log_step "Merging with existing Claude Code settings..."
        cp "$target_dir/.claude/settings.json" "$target_dir/.claude/settings.json.bak"

        # Check if jq is available for proper JSON merging
        if command -v jq &>/dev/null; then
            local temp_settings="$target_dir/.claude/settings.json.tmp"
            jq '.hooks.SessionStart = "bash .aea/scripts/aea-check.sh" |
                .hooks.UserPromptSubmit = "bash .aea/scripts/aea-check.sh" |
                .hooks.Stop = "bash .aea/scripts/aea-check.sh"' \
                "$target_dir/.claude/settings.json" > "$temp_settings"

            if [ -s "$temp_settings" ]; then
                mv "$temp_settings" "$target_dir/.claude/settings.json"
            else
                rm -f "$temp_settings"
                log_warning "Failed to merge settings. Creating new settings file."
                cat > "$target_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "SessionStart": "bash .aea/scripts/aea-check.sh",
    "UserPromptSubmit": "bash .aea/scripts/aea-check.sh",
    "Stop": "bash .aea/scripts/aea-check.sh"
  }
}
EOF
            fi
        else
            log_warning "jq not found. Existing settings will be overwritten."
            log_warning "Backup saved to: .claude/settings.json.bak"
            cat > "$target_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "SessionStart": "bash .aea/scripts/aea-check.sh",
    "UserPromptSubmit": "bash .aea/scripts/aea-check.sh",
    "Stop": "bash .aea/scripts/aea-check.sh"
  }
}
EOF
        fi
    else
        cat > "$target_dir/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "SessionStart": "bash .aea/scripts/aea-check.sh",
    "UserPromptSubmit": "bash .aea/scripts/aea-check.sh",
    "Stop": "bash .aea/scripts/aea-check.sh"
  }
}
EOF
    fi

    # Update .gitignore
    log_step "Updating .gitignore..."
    if [ -f "$target_dir/.gitignore" ]; then
        if ! grep -q "^.aea/$" "$target_dir/.gitignore" 2>/dev/null; then
            echo ".aea/" >> "$target_dir/.gitignore"
        fi
    else
        echo ".aea/" > "$target_dir/.gitignore"
    fi

    # Create initial log file
    touch "$target_dir/.aea/agent.log"

    # Success message
    echo ""
    log_success "AEA Protocol installed successfully!"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Read the guide: cat .aea/CLAUDE.md"
    echo "  2. Check for messages: bash .aea/scripts/aea-check.sh"
    echo "  3. Use the /aea command in Claude Code"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo "  • .aea/CLAUDE.md - Complete usage guide"
    echo "  • .aea/PROTOCOL.md - Protocol specification"
    echo "  • .aea/docs/ - Additional documentation"
    echo ""
    echo -e "${CYAN}Automatic Checking:${NC}"
    echo "  Claude Code will automatically check for AEA messages on:"
    echo "  • Session start"
    echo "  • Before processing prompts"
    echo "  • After completing tasks"
    echo ""
}

# ==============================================================================
# Entry Point
# ==============================================================================

main() {
    # Parse arguments
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        *)
            install_aea "${1:-.}"
            ;;
    esac
}

main "$@"
