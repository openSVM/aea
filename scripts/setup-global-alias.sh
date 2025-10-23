#!/bin/bash
# AEA Global Shell Integration Setup
# Creates a global 'a' command for quick AEA access from any directory

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Determine AEA repository location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AEA_REPO_PATH="$SCRIPT_DIR"

# Validate AEA repository
if [ ! -f "$AEA_REPO_PATH/aea.sh" ]; then
    echo -e "${RED}ERROR: AEA repository not found at: $AEA_REPO_PATH${NC}"
    echo "Expected to find aea.sh in the AEA repository root"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    AEA Global Shell Integration Setup                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Detect shells
detect_available_shells() {
    local shells=()

    # Check for bash (config file or binary)
    if [ -f "$HOME/.bashrc" ] || command -v bash >/dev/null 2>&1; then
        shells+=("bash")
    fi

    # Check for zsh (config file or binary)
    if [ -f "$HOME/.zshrc" ] || command -v zsh >/dev/null 2>&1; then
        shells+=("zsh")
    fi

    # Check for fish (config dir or binary)
    if [ -d "$HOME/.config/fish" ] || command -v fish >/dev/null 2>&1; then
        shells+=("fish")
    fi

    # Safely echo array (handles empty case)
    echo "${shells[@]:-}"
}

detect_current_shell() {
    if [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        echo "zsh"
    elif [ -n "${FISH_VERSION:-}" ]; then
        echo "fish"
    else
        echo "unknown"
    fi
}

CURRENT_SHELL=$(detect_current_shell)

# Safely populate array from command output
AVAILABLE_SHELLS=()
while IFS= read -r shell; do
    [ -n "$shell" ] && AVAILABLE_SHELLS+=("$shell")
done < <(detect_available_shells | tr ' ' '\n')

# Safety check for empty array
if [ ${#AVAILABLE_SHELLS[@]} -eq 0 ]; then
    echo -e "${YELLOW}Warning: No supported shell configurations found${NC}"
    AVAILABLE_SHELLS=("$CURRENT_SHELL")
fi

echo -e "${GREEN}Current shell: $CURRENT_SHELL${NC}"
echo -e "${GREEN}Available shells: ${AVAILABLE_SHELLS[*]:-none}${NC}"
echo -e "${GREEN}AEA repository: $AEA_REPO_PATH${NC}"
echo ""

# Create the shell function for bash/zsh
create_bash_function() {
    cat << 'EOF'
# AEA Global Command - Quick access to AEA protocol from any directory
a() {
    local AEA_REPO="AEA_REPO_PATH_PLACEHOLDER"
    local command="${1:-status}"

    # Handle global commands
    case "$command" in
        --help|-h|help)
            echo "AEA Global Command - Quick access to AEA protocol"
            echo ""
            echo "Usage: a [command] [options]"
            echo ""
            echo "Commands:"
            echo "  a                   - Show AEA status in current directory"
            echo "  a status            - Show AEA status"
            echo "  a install           - Install AEA in current directory"
            echo "  a check             - Check for messages (if AEA installed)"
            echo "  a process           - Process messages (if AEA installed)"
            echo "  a monitor [action]  - Control background monitor"
            echo "  a test              - Run tests"
            echo "  a version           - Show AEA version"
            echo "  a update            - Update AEA from source"
            echo ""
            echo "If AEA is not installed in current directory, most commands"
            echo "will offer to install it first."
            return 0
            ;;

        version|--version|-v)
            if [ -f "$AEA_REPO/aea.sh" ]; then
                bash "$AEA_REPO/aea.sh" version
            else
                echo "AEA repository not found at: $AEA_REPO"
            fi
            return 0
            ;;

        update)
            echo "Updating AEA from source repository..."
            if [ -d "$AEA_REPO/.git" ]; then
                ( cd "$AEA_REPO" && git pull )
                echo "✓ AEA updated"
            else
                echo "✗ AEA repository is not a git repository"
            fi
            return 0
            ;;
    esac

    # Check if AEA is installed in current directory
    if [ -f ".aea/aea.sh" ]; then
        # AEA installed, delegate to local installation
        bash .aea/aea.sh "$@"
    else
        # AEA not installed
        case "$command" in
            status)
                echo -e "\033[0;33m⚠ AEA not installed in this directory\033[0m"
                echo ""
                echo "Directory: $(pwd)"
                echo "Status: Not installed"
                echo ""
                echo "To install: a install"
                ;;

            install)
                if [ ! -f "$AEA_REPO/aea.sh" ]; then
                    echo -e "\033[0;31m✗ AEA repository not found at: $AEA_REPO\033[0m"
                    echo "Please update AEA_REPO in your shell configuration"
                    return 1
                fi

                echo "Installing AEA in: $(pwd)"
                echo ""
                read -p "Continue? (y/n): " response
                if [ "$response" = "y" ] || [ "$response" = "yes" ]; then
                    bash "$AEA_REPO/aea.sh" install .
                else
                    echo "Installation cancelled"
                fi
                ;;

            *)
                echo -e "\033[0;33m⚠ AEA not installed in this directory\033[0m"
                echo ""
                echo "Available commands without AEA installed:"
                echo "  a install    - Install AEA here"
                echo "  a status     - Check installation status"
                echo "  a help       - Show help"
                echo ""
                ;;
        esac
    fi
}
EOF
}

# Create the shell function for fish
create_fish_function() {
    cat << 'EOF'
# AEA Global Command - Quick access to AEA protocol from any directory
function a --description 'AEA protocol quick access'
    set -l AEA_REPO "AEA_REPO_PATH_PLACEHOLDER"
    set -l command (if test (count $argv) -gt 0; echo $argv[1]; else; echo "status"; end)

    # Handle global commands
    switch $command
        case --help -h help
            echo "AEA Global Command - Quick access to AEA protocol"
            echo ""
            echo "Usage: a [command] [options]"
            echo ""
            echo "Commands:"
            echo "  a                   - Show AEA status in current directory"
            echo "  a status            - Show AEA status"
            echo "  a install           - Install AEA in current directory"
            echo "  a check             - Check for messages (if AEA installed)"
            echo "  a process           - Process messages (if AEA installed)"
            echo "  a monitor [action]  - Control background monitor"
            echo "  a test              - Run tests"
            echo "  a version           - Show AEA version"
            echo "  a update            - Update AEA from source"
            return 0

        case version --version -v
            if test -f "$AEA_REPO/aea.sh"
                bash "$AEA_REPO/aea.sh" version
            else
                echo "AEA repository not found at: $AEA_REPO"
            end
            return 0

        case update
            echo "Updating AEA from source repository..."
            if test -d "$AEA_REPO/.git"
                begin
                    cd "$AEA_REPO"; and git pull
                end
                echo "✓ AEA updated"
            else
                echo "✗ AEA repository is not a git repository"
            end
            return 0
    end

    # Check if AEA is installed in current directory
    if test -f ".aea/aea.sh"
        # AEA installed, delegate to local installation
        bash .aea/aea.sh $argv
    else
        # AEA not installed
        switch $command
            case status
                echo "⚠ AEA not installed in this directory"
                echo ""
                echo "Directory: "(pwd)
                echo "Status: Not installed"
                echo ""
                echo "To install: a install"

            case install
                if not test -f "$AEA_REPO/aea.sh"
                    echo "✗ AEA repository not found at: $AEA_REPO"
                    echo "Please update AEA_REPO in your fish configuration"
                    return 1
                end

                echo "Installing AEA in: "(pwd)
                echo ""
                read -P "Continue? (y/n): " response
                if test "$response" = "y" -o "$response" = "yes"
                    bash "$AEA_REPO/aea.sh" install .
                else
                    echo "Installation cancelled"
                end

            case '*'
                echo "⚠ AEA not installed in this directory"
                echo ""
                echo "Available commands without AEA installed:"
                echo "  a install    - Install AEA here"
                echo "  a status     - Check installation status"
                echo "  a help       - Show help"
                echo ""
        end
    end
end
EOF
}

# Add to shell config
add_to_shell_config() {
    local shell_type="$1"
    local config_file=""
    local function_code=""

    case "$shell_type" in
        bash)
            config_file="$HOME/.bashrc"
            function_code=$(create_bash_function | sed "s|AEA_REPO_PATH_PLACEHOLDER|$AEA_REPO_PATH|g")
            ;;
        zsh)
            config_file="$HOME/.zshrc"
            function_code=$(create_bash_function | sed "s|AEA_REPO_PATH_PLACEHOLDER|$AEA_REPO_PATH|g")
            ;;
        fish)
            config_file="$HOME/.config/fish/functions/a.fish"
            mkdir -p "$HOME/.config/fish/functions"
            function_code=$(create_fish_function | sed "s|AEA_REPO_PATH_PLACEHOLDER|$AEA_REPO_PATH|g")
            ;;
        *)
            echo -e "${RED}✗ Unsupported shell: $shell_type${NC}"
            return 1
            ;;
    esac

    # Check if already configured
    if [ "$shell_type" = "fish" ]; then
        # Fish uses separate function files
        if [ -f "$config_file" ]; then
            echo -e "${YELLOW}! AEA global command already configured for fish${NC}"
            read -p "Overwrite existing configuration? (y/n): " response
            if [ "$response" != "y" ]; then
                echo "Configuration unchanged"
                return 0
            fi
        fi
        # Write directly to function file
        echo "$function_code" > "$config_file"
    else
        # Bash/Zsh
        if grep -q "# AEA Global Command" "$config_file" 2>/dev/null; then
            echo -e "${YELLOW}! AEA global command already configured in $config_file${NC}"
            read -p "Overwrite existing configuration? (y/n): " response
            if [ "$response" != "y" ]; then
                echo "Configuration unchanged"
                return 0
            fi

            # Remove old configuration using awk (safer than sed)
            local tempfile="$config_file.tmp.$$"
            awk '
                /# AEA Global Command/ { skip = 1; next }
                skip && /^}$/ { skip = 0; next }
                !skip { print }
            ' "$config_file" > "$tempfile"

            if [ -s "$tempfile" ]; then
                mv "$tempfile" "$config_file" || {
                    echo -e "${RED}Failed to update config file${NC}"
                    rm -f "$tempfile"
                    return 1
                }
            else
                echo -e "${RED}Failed to remove old configuration${NC}"
                rm -f "$tempfile"
                return 1
            fi
        fi

        # Add to config file
        echo "" >> "$config_file"
        echo "$function_code" >> "$config_file"
    fi

    echo -e "${GREEN}✓ Added AEA global command to $config_file${NC}"
}

# Interactive setup
setup_interactive() {
    echo "This will add a global 'a' command to your shell configuration."
    echo "This allows you to quickly access AEA from any directory."
    echo ""
    echo "Features:"
    echo "  • a              - Show AEA status in current directory"
    echo "  • a install      - Install AEA in current directory"
    echo "  • a check        - Check for messages"
    echo "  • a process      - Process messages"
    echo "  • a monitor      - Control background monitor"
    echo "  • a test         - Run tests"
    echo ""

    # Choose which shells to configure
    if [ ${#AVAILABLE_SHELLS[@]} -gt 1 ]; then
        echo "Multiple shell configurations detected:"
        for shell in "${AVAILABLE_SHELLS[@]}"; do
            echo "  • $shell"
        done
        echo ""
        read -p "Configure all shells? (y/n): " configure_all

        if [ "$configure_all" = "y" ]; then
            shells_to_configure=("${AVAILABLE_SHELLS[@]}")
        else
            echo "Configure for: $CURRENT_SHELL only"
            shells_to_configure=("$CURRENT_SHELL")
        fi
    else
        shells_to_configure=("$CURRENT_SHELL")
    fi

    echo ""
    read -p "Continue with setup? (y/n): " response

    if [ "$response" != "y" ] && [ "$response" != "yes" ]; then
        echo "Setup cancelled"
        exit 0
    fi

    # Add to each selected shell config
    for shell in "${shells_to_configure[@]}"; do
        add_to_shell_config "$shell"
    done

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "To activate the 'a' command:"
    echo ""
    for shell in "${shells_to_configure[@]}"; do
        case "$shell" in
            bash)
                echo "  Bash: source ~/.bashrc"
                ;;
            zsh)
                echo "  Zsh:  source ~/.zshrc"
                ;;
            fish)
                echo "  Fish: Already active (restart shell if needed)"
                ;;
        esac
    done
    echo ""
    echo "Or open a new terminal session."
    echo ""
    echo "Try it out:"
    echo "  a help           - Show help"
    echo "  a status         - Check AEA status in current directory"
    echo "  a install        - Install AEA in current directory"
}

# Automatic setup mode
setup_auto() {
    add_to_shell_config "$CURRENT_SHELL"
}

# Main
main() {
    if [ "${1:-}" = "--auto" ]; then
        setup_auto
    else
        setup_interactive
    fi
}

main "$@"
