#!/bin/bash
# AEA Protocol - Smart Installer
# Can be run from anywhere - detects context and installs appropriately
#
# Usage:
#   bash install.sh                    # Auto-detect and install
#   bash install.sh --repair           # Repair existing installation
#   bash install.sh --force            # Force reinstall
#   bash install.sh --help             # Show help

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script location
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Check if running from AEA source directory
if [ -f "$SCRIPT_DIR/aea.sh" ] && [ -f "$SCRIPT_DIR/PROTOCOL.md" ]; then
    AEA_SOURCE_DIR="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../aea.sh" ] && [ -f "$SCRIPT_DIR/../PROTOCOL.md" ]; then
    AEA_SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    echo -e "${RED}ERROR: Cannot find AEA source directory${NC}"
    echo "This script must be run from the AEA repository or .aea directory"
    exit 1
fi

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}▶${NC} $1"; }

# ==============================================================================
# Package Manager Detection (Top 100+ Programming Languages)
# ==============================================================================

detect_project_type() {
    local dir="$1"
    local project_types=()

    # JavaScript/TypeScript/Node.js
    [ -f "$dir/package.json" ] && project_types+=("Node.js/JavaScript")
    [ -f "$dir/yarn.lock" ] && project_types+=("Yarn")
    [ -f "$dir/pnpm-lock.yaml" ] && project_types+=("pnpm")
    [ -f "$dir/bun.lockb" ] && project_types+=("Bun")

    # Python
    [ -f "$dir/requirements.txt" ] && project_types+=("Python/pip")
    [ -f "$dir/setup.py" ] && project_types+=("Python/setuptools")
    [ -f "$dir/pyproject.toml" ] && project_types+=("Python/Poetry")
    [ -f "$dir/Pipfile" ] && project_types+=("Python/Pipenv")
    [ -f "$dir/poetry.lock" ] && project_types+=("Python/Poetry")
    [ -f "$dir/conda.yaml" ] && project_types+=("Python/Conda")
    [ -f "$dir/environment.yml" ] && project_types+=("Python/Conda")

    # Rust
    [ -f "$dir/Cargo.toml" ] && project_types+=("Rust/Cargo")

    # Go
    [ -f "$dir/go.mod" ] && project_types+=("Go")
    [ -f "$dir/go.sum" ] && project_types+=("Go")

    # Ruby
    [ -f "$dir/Gemfile" ] && project_types+=("Ruby/Bundler")
    [ -f "$dir/Gemfile.lock" ] && project_types+=("Ruby/Bundler")
    [ -f "$dir/Rakefile" ] && project_types+=("Ruby/Rake")

    # PHP
    [ -f "$dir/composer.json" ] && project_types+=("PHP/Composer")
    [ -f "$dir/composer.lock" ] && project_types+=("PHP/Composer")

    # Java/JVM
    [ -f "$dir/pom.xml" ] && project_types+=("Java/Maven")
    [ -f "$dir/build.gradle" ] && project_types+=("Java/Gradle")
    [ -f "$dir/build.gradle.kts" ] && project_types+=("Kotlin/Gradle")
    [ -f "$dir/settings.gradle" ] && project_types+=("Gradle")
    [ -f "$dir/gradlew" ] && project_types+=("Gradle")
    [ -f "$dir/build.sbt" ] && project_types+=("Scala/SBT")

    # .NET/C#
    [ -f "$dir/packages.config" ] && project_types+=(".NET/NuGet")
    [ -f "$dir/paket.dependencies" ] && project_types+=(".NET/Paket")
    [ -n "$(find "$dir" -maxdepth 1 -name "*.csproj" -o -name "*.fsproj" -o -name "*.vbproj" 2>/dev/null)" ] && project_types+=(".NET")
    [ -f "$dir/global.json" ] && project_types+=(".NET")

    # C/C++
    [ -f "$dir/CMakeLists.txt" ] && project_types+=("C++/CMake")
    [ -f "$dir/Makefile" ] && project_types+=("C/C++/Make")
    [ -f "$dir/meson.build" ] && project_types+=("C++/Meson")
    [ -f "$dir/conanfile.txt" ] && project_types+=("C++/Conan")
    [ -f "$dir/conanfile.py" ] && project_types+=("C++/Conan")
    [ -f "$dir/vcpkg.json" ] && project_types+=("C++/vcpkg")

    # Dart/Flutter
    [ -f "$dir/pubspec.yaml" ] && project_types+=("Dart/Flutter")
    [ -f "$dir/pubspec.lock" ] && project_types+=("Dart/Flutter")

    # Swift
    [ -f "$dir/Package.swift" ] && project_types+=("Swift/SPM")
    [ -f "$dir/Podfile" ] && project_types+=("Swift/CocoaPods")
    [ -f "$dir/Cartfile" ] && project_types+=("Swift/Carthage")

    # Objective-C/iOS
    [ -f "$dir/Podfile.lock" ] && project_types+=("iOS/CocoaPods")

    # Elixir
    [ -f "$dir/mix.exs" ] && project_types+=("Elixir/Mix")

    # Erlang
    [ -f "$dir/rebar.config" ] && project_types+=("Erlang/Rebar")

    # Haskell
    [ -f "$dir/stack.yaml" ] && project_types+=("Haskell/Stack")
    [ -f "$dir/cabal.project" ] && project_types+=("Haskell/Cabal")
    [ -n "$(find "$dir" -maxdepth 1 -name "*.cabal" 2>/dev/null)" ] && project_types+=("Haskell/Cabal")

    # OCaml
    [ -f "$dir/dune-project" ] && project_types+=("OCaml/Dune")
    [ -f "$dir/opam" ] && project_types+=("OCaml/OPAM")

    # Clojure
    [ -f "$dir/project.clj" ] && project_types+=("Clojure/Leiningen")
    [ -f "$dir/deps.edn" ] && project_types+=("Clojure/tools.deps")

    # Scala
    [ -f "$dir/build.sc" ] && project_types+=("Scala/Mill")

    # Kotlin
    [ -f "$dir/build.gradle.kts" ] && project_types+=("Kotlin/Gradle")

    # R
    [ -f "$dir/DESCRIPTION" ] && grep -q "Package:" "$dir/DESCRIPTION" 2>/dev/null && project_types+=("R")
    [ -f "$dir/renv.lock" ] && project_types+=("R/renv")

    # Julia
    [ -f "$dir/Project.toml" ] && project_types+=("Julia")
    [ -f "$dir/Manifest.toml" ] && project_types+=("Julia")

    # Lua
    [ -f "$dir/rockspec" ] && project_types+=("Lua/LuaRocks")

    # Perl
    [ -f "$dir/cpanfile" ] && project_types+=("Perl/CPAN")
    [ -f "$dir/Makefile.PL" ] && project_types+=("Perl/MakeMaker")

    # Zig
    [ -f "$dir/build.zig" ] && project_types+=("Zig")

    # Nim
    [ -f "$dir/nimble" ] && project_types+=("Nim")
    [ -n "$(find "$dir" -maxdepth 1 -name "*.nimble" 2>/dev/null)" ] && project_types+=("Nim")

    # Crystal
    [ -f "$dir/shard.yml" ] && project_types+=("Crystal")

    # D
    [ -f "$dir/dub.json" ] && project_types+=("D/Dub")
    [ -f "$dir/dub.sdl" ] && project_types+=("D/Dub")

    # V
    [ -f "$dir/v.mod" ] && project_types+=("V")

    # Terraform
    [ -n "$(find "$dir" -maxdepth 1 -name "*.tf" 2>/dev/null)" ] && project_types+=("Terraform")

    # Docker
    [ -f "$dir/Dockerfile" ] && project_types+=("Docker")
    [ -f "$dir/docker-compose.yml" ] && project_types+=("Docker Compose")
    [ -f "$dir/docker-compose.yaml" ] && project_types+=("Docker Compose")

    # Kubernetes (safer check)
    local k8s_files=$(find "$dir" -maxdepth 2 \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | head -5)
    if [ -n "$k8s_files" ]; then
        if echo "$k8s_files" | xargs grep -l "apiVersion:" 2>/dev/null | head -1 | grep -q .; then
            project_types+=("Kubernetes")
        fi
    fi

    # Shell scripts
    [ -f "$dir/Makefile" ] && project_types+=("Make")

    # Return project types
    if [ ${#project_types[@]} -gt 0 ]; then
        printf '%s\n' "${project_types[@]}" | sort -u
        return 0
    else
        return 1
    fi
}

is_project_directory() {
    detect_project_type "$1" &>/dev/null
    return $?
}

# ==============================================================================
# Installation State Detection
# ==============================================================================

check_aea_installation() {
    local target_dir="$1"

    if [ -d "$target_dir/.aea" ]; then
        if [ -f "$target_dir/.aea/aea.sh" ] && [ -f "$target_dir/.aea/PROTOCOL.md" ]; then
            echo "installed"
        else
            echo "partial"
        fi
    else
        echo "not_installed"
    fi
}

# ==============================================================================
# Backup Management
# ==============================================================================

create_backup() {
    local source_dir="$1"
    local backup_reason="$2"

    # Create backup directory structure
    local backup_root="$HOME/.aea/backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local project_name=$(basename "$(cd "$source_dir/.." && pwd)")
    local backup_dir="$backup_root/$project_name-$timestamp"

    mkdir -p "$backup_dir"

    log_step "Creating backup in: $backup_dir"

    # Move .aea directory to backup
    if ! mv "$source_dir/.aea" "$backup_dir/aea-backup"; then
        log_error "Failed to create backup"
        return 1
    fi

    # Create metadata file (plain text format, no jq dependency)
    cat > "$backup_dir/BACKUP_INFO.txt" << EOF
AEA Installation Backup
=======================
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Source Path: $source_dir
Project Name: $project_name
Reason: $backup_reason
Backup Size: $(du -sh "$backup_dir/aea-backup" 2>/dev/null | cut -f1 || echo "unknown")
Message Count: $(find "$backup_dir/aea-backup" -name "message-*.json" 2>/dev/null | wc -l)

To Restore:
  mv "$backup_dir/aea-backup" "$source_dir/.aea"
EOF

    # Also create JSON if jq is available
    if command -v jq &>/dev/null; then
        cat > "$backup_dir/BACKUP_INFO.json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_path": "$source_dir",
  "project_name": "$project_name",
  "reason": "$backup_reason",
  "backup_size": "$(du -sh "$backup_dir/aea-backup" 2>/dev/null | cut -f1 || echo "unknown")",
  "message_count": $(find "$backup_dir/aea-backup" -name "message-*.json" 2>/dev/null | wc -l),
  "restore_command": "mv $backup_dir/aea-backup $source_dir/.aea"
}
EOF
    fi

    log_success "Backup created: $backup_dir"
    echo "$backup_dir"
}

list_backups() {
    local backup_root="$HOME/.aea/backups"

    if [ ! -d "$backup_root" ] || [ -z "$(ls -A "$backup_root" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No backups found${NC}"
        return 0
    fi

    echo -e "${CYAN}Available backups:${NC}"
    echo ""

    for backup in "$backup_root"/*; do
        [ -d "$backup" ] || continue

        # Try JSON first (if jq available), fallback to text
        if [ -f "$backup/BACKUP_INFO.json" ] && command -v jq &>/dev/null; then
            local project=$(jq -r '.project_name' "$backup/BACKUP_INFO.json" 2>/dev/null || echo "unknown")
            local timestamp=$(jq -r '.timestamp' "$backup/BACKUP_INFO.json" 2>/dev/null || echo "unknown")
            local reason=$(jq -r '.reason' "$backup/BACKUP_INFO.json" 2>/dev/null || echo "unknown")
            local size=$(jq -r '.backup_size' "$backup/BACKUP_INFO.json" 2>/dev/null || echo "unknown")
        elif [ -f "$backup/BACKUP_INFO.txt" ]; then
            # Parse text file
            local project=$(grep "^Project Name:" "$backup/BACKUP_INFO.txt" | cut -d: -f2- | xargs)
            local timestamp=$(grep "^Timestamp:" "$backup/BACKUP_INFO.txt" | cut -d: -f2- | xargs)
            local reason=$(grep "^Reason:" "$backup/BACKUP_INFO.txt" | cut -d: -f2- | xargs)
            local size=$(grep "^Backup Size:" "$backup/BACKUP_INFO.txt" | cut -d: -f2- | xargs)
        else
            local project="unknown"
            local timestamp="unknown"
            local reason="unknown"
            local size="unknown"
        fi

        echo -e "  ${GREEN}$(basename "$backup")${NC}"
        echo "    Project: $project"
        echo "    Date: $timestamp"
        echo "    Reason: $reason"
        echo "    Size: $size"
        echo ""
    done
}

# ==============================================================================
# Installation Logic
# ==============================================================================

perform_installation() {
    local target_dir="$1"

    # Validate target directory is writable
    if [ ! -w "$target_dir" ]; then
        log_error "Target directory is not writable: $target_dir"
        return 1
    fi

    log_step "Installing AEA in: $target_dir"

    # Create .aea directory
    if ! mkdir -p "$target_dir/.aea"; then
        log_error "Failed to create .aea directory"
        return 1
    fi

    # Copy core files with error checking
    log_info "Copying AEA files..."

    if ! cp "$AEA_SOURCE_DIR/aea.sh" "$target_dir/.aea/"; then
        log_error "Failed to copy aea.sh"
        rm -rf "$target_dir/.aea"
        return 1
    fi

    if ! cp "$AEA_SOURCE_DIR/PROTOCOL.md" "$target_dir/.aea/"; then
        log_error "Failed to copy PROTOCOL.md"
        rm -rf "$target_dir/.aea"
        return 1
    fi

    if ! cp "$AEA_SOURCE_DIR/agent-config.yaml" "$target_dir/.aea/"; then
        log_error "Failed to copy agent-config.yaml"
        rm -rf "$target_dir/.aea"
        return 1
    fi

    # Copy scripts directory
    if [ -d "$AEA_SOURCE_DIR/scripts" ]; then
        cp -r "$AEA_SOURCE_DIR/scripts" "$target_dir/.aea/"
    fi

    # Copy prompts directory
    if [ -d "$AEA_SOURCE_DIR/prompts" ]; then
        cp -r "$AEA_SOURCE_DIR/prompts" "$target_dir/.aea/"
    fi

    # Copy docs directory
    if [ -d "$AEA_SOURCE_DIR/docs" ]; then
        cp -r "$AEA_SOURCE_DIR/docs" "$target_dir/.aea/"
    fi

    # Copy templates
    if [ -d "$AEA_SOURCE_DIR/templates" ]; then
        mkdir -p "$target_dir/.aea/templates"
        cp -r "$AEA_SOURCE_DIR/templates"/* "$target_dir/.aea/templates/"
    fi

    # Install CLAUDE.md for installed repos
    if [ -f "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" ]; then
        cp "$AEA_SOURCE_DIR/templates/CLAUDE_INSTALLED.md" "$target_dir/.aea/CLAUDE.md"
    fi

    # Create runtime directories
    mkdir -p "$target_dir/.aea/.processed"
    mkdir -p "$target_dir/.aea/logs"

    # Create .gitignore
    cat > "$target_dir/.aea/.gitignore" << 'EOF'
# AEA Runtime Files
*.log
agent.log
logs/*.log
.processed/
*.tmp
*.temp
.monitor.pid
.dedup-cache.json
correlation/
retry/
EOF

    # Update agent-config.yaml with project-specific info
    local project_name=$(basename "$target_dir")
    local agent_id="claude-$project_name"

    # Use awk for safer, more portable in-place editing
    if [ -f "$target_dir/.aea/agent-config.yaml" ]; then
        local tempfile="$target_dir/.aea/agent-config.yaml.tmp.$$"
        awk -v new_id="$agent_id" '
            /^  id:/ { print "  id: \"" new_id "\""; next }
            { print }
        ' "$target_dir/.aea/agent-config.yaml" > "$tempfile"

        if [ -s "$tempfile" ]; then
            mv "$tempfile" "$target_dir/.aea/agent-config.yaml"
        else
            log_warning "Failed to update agent ID in config"
            rm -f "$tempfile"
        fi
    fi

    # Make scripts executable
    chmod +x "$target_dir/.aea/aea.sh"
    [ -d "$target_dir/.aea/scripts" ] && chmod +x "$target_dir/.aea/scripts"/*.sh 2>/dev/null || true

    log_success "AEA installed successfully!"

    # Show next steps
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "1. Check for messages:"
    echo "   ${GREEN}bash .aea/aea.sh check${NC}"
    echo ""
    echo "2. Set up global 'a' command:"
    echo "   ${GREEN}bash .aea/aea.sh setup-global${NC}"
    echo ""
    echo "3. View help:"
    echo "   ${GREEN}bash .aea/aea.sh help${NC}"
    echo ""
}

# ==============================================================================
# Main Installation Flow
# ==============================================================================

main() {
    local mode="${1:-auto}"
    local current_dir="$(pwd)"

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        AEA Protocol - Smart Installer            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Handle flags
    case "$mode" in
        --help|-h)
            cat << 'EOF'
AEA Protocol - Smart Installer

Usage:
  bash install.sh               Auto-detect and install
  bash install.sh --repair      Repair existing installation
  bash install.sh --force       Force reinstall (backup and fresh install)
  bash install.sh --list        List backups
  bash install.sh --help        Show this help

The installer automatically detects:
  • Project directories (via package managers)
  • Existing installations
  • Best installation location

Supports 100+ programming languages and package managers.
EOF
            exit 0
            ;;
        --list)
            list_backups
            exit 0
            ;;
        --repair)
            log_info "Repairing AEA installation in: $current_dir"
            if [ ! -d "$current_dir/.aea" ]; then
                log_error "No AEA installation found to repair"
                exit 1
            fi
            perform_installation "$current_dir"
            exit $?
            ;;
        --force)
            log_info "Force reinstalling AEA in: $current_dir"
            if [ -d "$current_dir/.aea" ]; then
                backup_path=$(create_backup "$current_dir" "force-reinstall")
                if [ -n "$backup_path" ]; then
                    log_success "Backup created: $backup_path"
                fi
            fi
            perform_installation "$current_dir"
            exit $?
            ;;
    esac

    # Check current installation state
    local install_state=$(check_aea_installation "$current_dir")

    log_info "Current directory: $current_dir"

    # Detect if this is a project directory
    local is_project=false
    local project_types=""

    if is_project_directory "$current_dir"; then
        is_project=true
        project_types=$(detect_project_type "$current_dir" | tr '\n' ', ' | sed 's/,$//')
        log_info "Detected project type(s): $project_types"
    else
        log_info "Not a project directory (no package managers detected)"
    fi

    echo ""

    # Handle based on installation state
    case "$install_state" in
        installed)
            echo -e "${YELLOW}⚠  AEA is already installed in this directory${NC}"
            echo ""
            echo "What would you like to do?"
            echo "  1) Repair installation (fix missing files)"
            echo "  2) Delete and backup (move to ~/.aea/backups)"
            echo "  3) Cancel"
            echo ""
            read -p "Choose [1-3]: " choice

            case "$choice" in
                1)
                    log_step "Repairing installation..."
                    perform_installation "$current_dir"
                    ;;
                2)
                    echo ""
                    echo -e "${RED}This will backup and remove the existing .aea directory${NC}"
                    read -p "Are you sure? (yes/no): " confirm

                    if [ "$confirm" = "yes" ]; then
                        backup_path=$(create_backup "$current_dir" "user-requested-deletion")
                        log_success "Deleted and backed up to: $backup_path"
                        echo ""
                        read -p "Install fresh AEA now? (yes/no): " install_fresh
                        if [ "$install_fresh" = "yes" ]; then
                            perform_installation "$current_dir"
                        fi
                    else
                        log_info "Cancelled"
                    fi
                    ;;
                3|*)
                    log_info "Cancelled"
                    exit 0
                    ;;
            esac
            ;;

        partial)
            echo -e "${YELLOW}⚠  Partial AEA installation detected${NC}"
            log_warning "The .aea directory exists but is incomplete"
            echo ""
            read -p "Repair the installation? (yes/no): " repair

            if [ "$repair" = "yes" ]; then
                perform_installation "$current_dir"
            else
                log_info "Cancelled"
                exit 0
            fi
            ;;

        not_installed)
            if [ "$is_project" = true ]; then
                # Project directory - install in .aea
                log_success "Installing AEA in project directory"
                perform_installation "$current_dir"
            else
                # Not a project - ask user
                echo -e "${YELLOW}This doesn't appear to be a project directory${NC}"
                echo ""
                echo "Where would you like to install AEA?"
                echo "  1) Current directory (.aea subfolder)"
                echo "  2) Cancel"
                echo ""
                read -p "Choose [1-2]: " choice

                case "$choice" in
                    1)
                        perform_installation "$current_dir"
                        ;;
                    2|*)
                        log_info "Cancelled"
                        exit 0
                        ;;
                esac
            fi
            ;;
    esac

    echo ""
}

# Run main
main "$@"
