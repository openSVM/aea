#!/bin/sh
# AEA Protocol - Standalone Installer (POSIX-compatible)
# Downloads and installs AEA from GitHub
#
# Usage:
#   curl -fsSL https://aea.sh | sh
#   sh install.sh [TARGET_DIR]
#   sh install.sh --help

set -eu

# Colors (will work in most terminals, degrade gracefully)
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

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"; }
log_warning() { printf "${YELLOW}[WARNING]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step() { printf "${CYAN}▶${NC} %s\n" "$1"; }

show_help() {
    cat << 'EOF'
AEA Protocol - Standalone Installer

USAGE:
    curl -fsSL https://aea.sh | sh
    sh install.sh [TARGET_DIR]
    sh install.sh --help

OPTIONS:
    TARGET_DIR      Directory to install AEA (default: current directory)
    --help          Show this help message

EXAMPLES:
    # Install in current directory
    sh install.sh

    # Install in specific directory
    sh install.sh /path/to/project

    # One-liner from anywhere
    curl -fsSL https://aea.sh | sh

WHAT IT DOES:
    1. Downloads AEA files from GitHub
    2. Creates .aea/ directory structure
    3. Installs scripts, configs, and documentation
    4. Sets up Claude Code integration

EOF
    exit 0
}

# Download a single file
download_file() {
    source_file="$1"
    dest_path="$2"
    url="${GITHUB_RAW_URL}/${source_file}"
    dest="${target_dir}/${dest_path}$(basename "$source_file")"

    # Special case for CLAUDE_INSTALLED.md -> CLAUDE.md
    case "$source_file" in
        templates/CLAUDE_INSTALLED.md)
            dest="${target_dir}/.aea/CLAUDE.md"
            ;;
    esac

    if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
        printf "  ${GREEN}✓${NC} %s\n" "$(basename "$source_file")"
        return 0
    else
        printf "  ${RED}✗${NC} %s\n" "$(basename "$source_file")"
        return 1
    fi
}

# ==============================================================================
# Main Installation Logic
# ==============================================================================

install_aea() {
    target_dir="${1:-.}"

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
            printf "${YELLOW}Options:${NC}\n"
            printf "  1) Backup and reinstall\n"
            printf "  2) Cancel installation\n"
            printf "Choose (1/2): "
            read -r choice
        else
            # Non-interactive mode: auto-backup
            log_info "Non-interactive mode detected. Auto-backing up existing installation."
            choice="1"
        fi

        case "$choice" in
            1)
                backup_dir="$HOME/.aea/backups/backup-$(date +%Y%m%d-%H%M%S)"
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
    mkdir -p "$target_dir/.aea/scripts"
    mkdir -p "$target_dir/.aea/prompts"
    mkdir -p "$target_dir/.aea/docs"
    mkdir -p "$target_dir/.aea/.processed"

    # Download core files
    log_step "Downloading AEA files from GitHub..."

    failed_downloads=0

    # Download files one by one (POSIX-compatible, no arrays)
    download_file "aea.sh" ".aea/" || failed_downloads=$((failed_downloads + 1))
    download_file "agent-config.yaml" ".aea/" || failed_downloads=$((failed_downloads + 1))
    download_file "PROTOCOL.md" ".aea/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-check.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-send.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-monitor.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-registry.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-cleanup.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-common.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-validate-message.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/aea-issues.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/process-messages-iterative.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/uninstall-aea.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "scripts/setup-global-alias.sh" ".aea/scripts/" || failed_downloads=$((failed_downloads + 1))
    download_file "prompts/check-messages.md" ".aea/prompts/" || failed_downloads=$((failed_downloads + 1))
    download_file "templates/CLAUDE_INSTALLED.md" ".aea/" || failed_downloads=$((failed_downloads + 1))
    download_file "docs/aea-rules.md" ".aea/docs/" || failed_downloads=$((failed_downloads + 1))
    download_file "docs/GETTING_STARTED.md" ".aea/docs/" || failed_downloads=$((failed_downloads + 1))
    download_file "docs/EXAMPLES.md" ".aea/docs/" || failed_downloads=$((failed_downloads + 1))
    download_file "docs/SECURITY.md" ".aea/docs/" || failed_downloads=$((failed_downloads + 1))
    download_file "docs/INSTALLATION.md" ".aea/docs/" || failed_downloads=$((failed_downloads + 1))

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
        agent_id="agent-$(date +%s)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    else
        agent_id="agent-$(date +%s)-$(printf '%04x' $$)"
    fi
    project_name="$(basename "$target_dir")"

    # Update agent-config.yaml (portable awk)
    if [ -f "$target_dir/.aea/agent-config.yaml" ]; then
        temp_config="$target_dir/.aea/agent-config.yaml.tmp"
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
        if command -v jq >/dev/null 2>&1; then
            temp_settings="$target_dir/.claude/settings.json.tmp"
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
    printf "\n"
    log_success "AEA Protocol installed successfully!"
    printf "\n"
    printf "${CYAN}Next Steps:${NC}\n"
    printf "  1. Read the guide: cat .aea/CLAUDE.md\n"
    printf "  2. Check for messages: bash .aea/scripts/aea-check.sh\n"
    printf "  3. Use the /aea command in Claude Code\n"
    printf "\n"
    printf "${CYAN}Documentation:${NC}\n"
    printf "  • .aea/CLAUDE.md - Complete usage guide\n"
    printf "  • .aea/PROTOCOL.md - Protocol specification\n"
    printf "  • .aea/docs/ - Additional documentation\n"
    printf "\n"
    printf "${CYAN}Automatic Checking:${NC}\n"
    printf "  Claude Code will automatically check for AEA messages on:\n"
    printf "  • Session start\n"
    printf "  • Before processing prompts\n"
    printf "  • After completing tasks\n"
    printf "\n"
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
