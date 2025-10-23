#!/bin/bash
# aea-registry.sh - Agent Registry Management
# Manages discovery and routing of AEA agents across repositories

set -euo pipefail

REGISTRY_FILE="${AEA_REGISTRY_FILE:-$HOME/.config/aea/agents.yaml}"
REGISTRY_DIR="$(dirname "$REGISTRY_FILE")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# ==============================================================================
# Registry Initialization
# ==============================================================================

init_registry() {
    if [ -f "$REGISTRY_FILE" ]; then
        log_info "Registry already exists at $REGISTRY_FILE"
        return 0
    fi

    log_info "Creating agent registry at $REGISTRY_FILE"

    mkdir -p "$REGISTRY_DIR"

    cat > "$REGISTRY_FILE" << 'EOF'
# AEA Agent Registry
# This file tracks all AEA-enabled repositories for message routing

version: "1.0"
agents: {}

# Example agent configuration:
# agents:
#   my-backend-agent:
#     path: /home/user/projects/backend
#     enabled: true
#     description: "Backend API service"
#   my-frontend-agent:
#     path: /home/user/projects/frontend
#     enabled: true
#     description: "Frontend React app"
#   remote-agent:
#     host: server.example.com
#     path: /opt/projects/api
#     method: ssh
#     user: deploy
#     enabled: true
#     description: "Remote production API"
EOF

    log_success "Created registry at $REGISTRY_FILE"
}

# ==============================================================================
# Agent Registration
# ==============================================================================

register_agent() {
    local agent_id="$1"
    local repo_path="$2"
    local description="${3:-AEA-enabled repository}"

    init_registry

    # Validate agent_id format (alphanumeric, hyphens, underscores only)
    if ! echo "$agent_id" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        log_error "Invalid agent_id: must contain only letters, numbers, hyphens, and underscores"
        log_error "Provided: $agent_id"
        return 1
    fi

    # Check agent_id length
    if [ ${#agent_id} -lt 3 ] || [ ${#agent_id} -gt 64 ]; then
        log_error "Invalid agent_id length: must be between 3 and 64 characters"
        return 1
    fi

    # Validate path exists
    if [ ! -d "$repo_path" ]; then
        log_error "Path does not exist: $repo_path"
        return 1
    fi

    # Validate has .aea directory
    if [ ! -d "$repo_path/.aea" ]; then
        log_error "Not an AEA repository (no .aea/ directory): $repo_path"
        return 1
    fi

    # Convert to absolute path
    if ! repo_path=$(cd "$repo_path" && pwd); then
        log_error "Failed to resolve absolute path for: $repo_path"
        return 1
    fi

    # Sanitize description safely (remove quotes and special YAML characters)
    description=$(printf '%s' "$description" | tr -d '"'"'"'`$\\\n\r' | head -c 200)

    # Check if already registered
    if grep -q "^  $agent_id:" "$REGISTRY_FILE" 2>/dev/null; then
        log_warning "Agent '$agent_id' already registered, updating..."
        # Remove old entry using awk (safer than sed)
        local tempfile="$REGISTRY_FILE.tmp.$$"
        awk -v agent="$agent_id" '
            BEGIN { skip = 0 }
            $0 ~ "^  " agent ":" { skip = 1; next }
            skip && /^  [a-zA-Z]/ { skip = 0 }
            !skip { print }
        ' "$REGISTRY_FILE" > "$tempfile"

        if [ -s "$tempfile" ]; then
            mv "$tempfile" "$REGISTRY_FILE" || {
                log_error "Failed to update registry"
                rm -f "$tempfile"
                return 1
            }
        else
            log_error "Failed to remove old entry"
            rm -f "$tempfile"
            return 1
        fi
    fi

    # Add agent to registry
    # Use awk to insert after "agents:" line
    local tempfile="$REGISTRY_FILE.tmp.$$"
    awk -v agent="$agent_id" -v path="$repo_path" -v desc="$description" '
    /^agents:/ {
        print
        print "  " agent ":"
        print "    path: " path
        print "    enabled: true"
        print "    description: \"" desc "\""
        next
    }
    { print }
    ' "$REGISTRY_FILE" > "$tempfile"

    if [ -s "$tempfile" ]; then
        mv "$tempfile" "$REGISTRY_FILE" || {
            log_error "Failed to update registry"
            rm -f "$tempfile"
            return 1
        }
    else
        log_error "Failed to add agent to registry"
        rm -f "$tempfile"
        return 1
    fi

    log_success "Registered agent '$agent_id' at $repo_path"
}

# ==============================================================================
# Agent Lookup
# ==============================================================================

get_agent_path() {
    local agent_id="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        log_error "Registry not found: $REGISTRY_FILE"
        log_info "Run: aea-registry.sh init"
        return 1
    fi

    # Extract path using grep and awk
    local path=$(awk -v agent="$agent_id" '
        $0 ~ "^  " agent ":" { found=1; next }
        found && /^    path:/ { print $2; exit }
        /^  [a-zA-Z]/ { found=0 }
    ' "$REGISTRY_FILE")

    if [ -z "$path" ]; then
        log_error "Agent not found in registry: $agent_id"
        return 1
    fi

    echo "$path"
}

get_agent_enabled() {
    local agent_id="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        return 1
    fi

    local enabled=$(awk -v agent="$agent_id" '
        $0 ~ "^  " agent ":" { found=1; next }
        found && /^    enabled:/ { print $2; exit }
        /^  [a-zA-Z]/ { found=0 }
    ' "$REGISTRY_FILE")

    [ "$enabled" = "true" ]
}

# ==============================================================================
# List Agents
# ==============================================================================

list_agents() {
    if [ ! -f "$REGISTRY_FILE" ]; then
        log_error "Registry not found: $REGISTRY_FILE"
        log_info "Run: aea-registry.sh init"
        return 1
    fi

    echo "Registered AEA Agents:"
    echo "====================="
    echo

    awk '
    /^  [a-zA-Z]/ && !/^  #/ {
        agent = $1
        gsub(/:/, "", agent)
        printf "Agent: %s\n", agent
    }
    /^    path:/ { printf "  Path: %s\n", $2 }
    /^    enabled:/ { printf "  Enabled: %s\n", $2 }
    /^    description:/ {
        desc = $0
        sub(/^    description: /, "", desc)
        printf "  Description: %s\n", desc
        print ""
    }
    ' "$REGISTRY_FILE"
}

# ==============================================================================
# Unregister Agent
# ==============================================================================

unregister_agent() {
    local agent_id="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        log_error "Registry not found: $REGISTRY_FILE"
        return 1
    fi

    if ! grep -q "^  $agent_id:" "$REGISTRY_FILE" 2>/dev/null; then
        log_error "Agent not registered: $agent_id"
        return 1
    fi

    # Remove agent entry using awk (safer than sed)
    local tempfile="$REGISTRY_FILE.tmp.$$"
    awk -v agent="$agent_id" '
        BEGIN { skip = 0 }
        $0 ~ "^  " agent ":" { skip = 1; next }
        skip && /^  [a-zA-Z]/ { skip = 0 }
        !skip { print }
    ' "$REGISTRY_FILE" > "$tempfile"

    if [ -s "$tempfile" ]; then
        mv "$tempfile" "$REGISTRY_FILE" || {
            log_error "Failed to update registry"
            rm -f "$tempfile"
            return 1
        }
    else
        log_error "Failed to remove agent"
        rm -f "$tempfile"
        return 1
    fi

    log_success "Unregistered agent: $agent_id"
}

# ==============================================================================
# Enable/Disable Agent
# ==============================================================================

enable_agent() {
    local agent_id="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        log_error "Registry not found"
        return 1
    fi

    awk -v agent="$agent_id" '
        $0 ~ "^  " agent ":" { found=1 }
        found && /^    enabled:/ { $2 = "true"; found=0 }
        { print }
    ' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

    log_success "Enabled agent: $agent_id"
}

disable_agent() {
    local agent_id="$1"

    if [ ! -f "$REGISTRY_FILE" ]; then
        log_error "Registry not found"
        return 1
    fi

    awk -v agent="$agent_id" '
        $0 ~ "^  " agent ":" { found=1 }
        found && /^    enabled:/ { $2 = "false"; found=0 }
        { print }
    ' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

    log_success "Disabled agent: $agent_id"
}

# ==============================================================================
# Auto-register current directory
# ==============================================================================

register_current() {
    local repo_path="$(pwd)"

    # Check if in AEA repo
    if [ ! -d ".aea" ]; then
        log_error "Not in an AEA repository (no .aea/ directory found)"
        log_info "Run this from the root of an AEA-enabled repository"
        return 1
    fi

    # Try to get agent_id from config
    local agent_id=""
    if [ -f ".aea/agent-config.yaml" ]; then
        agent_id=$(grep "^agent_id:" .aea/agent-config.yaml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
    fi

    if [ -z "$agent_id" ]; then
        # Generate from directory name
        agent_id="claude-$(basename "$repo_path")"
        log_warning "No agent_id in config, using: $agent_id"
    fi

    register_agent "$agent_id" "$repo_path" "Auto-registered from $repo_path"
}

# ==============================================================================
# Main Command Handler
# ==============================================================================

usage() {
    cat << EOF
AEA Registry Management

Usage: $(basename "$0") <command> [arguments]

Commands:
    init                        Initialize registry file
    register <id> <path> [desc] Register an agent
    register-current            Auto-register current directory
    unregister <id>             Remove agent from registry
    list                        List all registered agents
    get-path <id>               Get path for agent ID
    enable <id>                 Enable agent
    disable <id>                Disable agent

Environment Variables:
    AEA_REGISTRY_FILE          Path to registry (default: ~/.config/aea/agents.yaml)

Examples:
    # Initialize registry
    $(basename "$0") init

    # Register an agent
    $(basename "$0") register my-backend /home/user/backend "Backend API"

    # Auto-register current repo
    cd /my/repo && $(basename "$0") register-current

    # List all agents
    $(basename "$0") list

    # Get agent path
    $(basename "$0") get-path my-backend

    # Disable an agent
    $(basename "$0") disable my-backend

EOF
}

# Main entry point
main() {
    local command="${1:-}"

    case "$command" in
        init)
            init_registry
            ;;
        register)
            if [ $# -lt 3 ]; then
                log_error "Usage: register <agent_id> <path> [description]"
                return 1
            fi
            register_agent "$2" "$3" "${4:-AEA-enabled repository}"
            ;;
        register-current)
            register_current
            ;;
        unregister)
            if [ $# -lt 2 ]; then
                log_error "Usage: unregister <agent_id>"
                return 1
            fi
            unregister_agent "$2"
            ;;
        list)
            list_agents
            ;;
        get-path)
            if [ $# -lt 2 ]; then
                log_error "Usage: get-path <agent_id>"
                return 1
            fi
            get_agent_path "$2"
            ;;
        enable)
            if [ $# -lt 2 ]; then
                log_error "Usage: enable <agent_id>"
                return 1
            fi
            enable_agent "$2"
            ;;
        disable)
            if [ $# -lt 2 ]; then
                log_error "Usage: disable <agent_id>"
                return 1
            fi
            disable_agent "$2"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            usage
            return 1
            ;;
    esac
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
