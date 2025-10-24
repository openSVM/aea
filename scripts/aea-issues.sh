#!/usr/bin/env bash
# AEA Protocol - GitHub Issues Checker
# Checks GitHub issues and suggests relevant ones based on current context

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/aea-common.sh" ]; then
    source "$SCRIPT_DIR/aea-common.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ==============================================================================
# Configuration
# ==============================================================================

load_config() {
    local config_file="${1:-.aea/agent-config.yaml}"

    if [ ! -f "$config_file" ]; then
        echo ""
        return 1
    fi

    # Extract GitHub repo from config
    GITHUB_REPO=$(awk '/github_integration:/,/^[^ ]/ {
        if ($1 == "repository:") {
            gsub(/"/, "", $2)
            print $2
            exit
        }
    }' "$config_file")

    # Extract enabled status
    ENABLED=$(awk '/github_integration:/,/^[^ ]/ {
        if ($1 == "enabled:") {
            print $2
            exit
        }
    }' "$config_file")

    # Extract labels to monitor
    LABELS=$(awk '/github_integration:/,/^[^ ]/ {
        if ($1 == "labels:") {
            getline
            while ($0 ~ /^[[:space:]]+-/) {
                gsub(/^[[:space:]]+-[[:space:]]+/, "")
                gsub(/"/, "")
                printf "%s,", $0
                getline
            }
        }
    }' "$config_file" | sed 's/,$//')

    # Extract check interval (minutes)
    CHECK_INTERVAL=$(awk '/github_integration:/,/^[^ ]/ {
        if ($1 == "check_interval_minutes:") {
            print $2
            exit
        }
    }' "$config_file")

    # Defaults
    ENABLED="${ENABLED:-false}"
    CHECK_INTERVAL="${CHECK_INTERVAL:-60}"

    return 0
}

# ==============================================================================
# GitHub CLI Validation
# ==============================================================================

check_gh_cli() {
    if ! command -v gh &>/dev/null; then
        echo -e "${YELLOW}⚠ GitHub CLI (gh) not installed${NC}"
        echo ""
        echo "To enable GitHub issues integration:"
        echo "  • Install: https://cli.github.com/"
        echo "  • macOS: brew install gh"
        echo "  • Linux: See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        echo ""
        return 1
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        echo -e "${YELLOW}⚠ GitHub CLI not authenticated${NC}"
        echo ""
        echo "Run: gh auth login"
        echo ""
        return 1
    fi

    return 0
}

# ==============================================================================
# Issue Fetching
# ==============================================================================

fetch_issues() {
    local repo="$1"
    local labels="$2"
    local limit="${3:-10}"

    if [ -z "$repo" ]; then
        echo -e "${RED}Error: No GitHub repository configured${NC}" >&2
        return 1
    fi

    # Build gh issue list command
    local gh_cmd="gh issue list --repo $repo --limit $limit --state open"

    # Add label filter if specified
    if [ -n "$labels" ]; then
        gh_cmd="$gh_cmd --label \"$labels\""
    fi

    # Fetch issues
    eval "$gh_cmd" 2>/dev/null || {
        echo -e "${RED}Error: Failed to fetch issues from $repo${NC}" >&2
        return 1
    }

    return 0
}

# ==============================================================================
# Context Matching
# ==============================================================================

get_current_context() {
    local pwd_path="$(pwd)"
    local git_root=""

    # Try to get git root
    if git rev-parse --git-dir &>/dev/null; then
        git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
    fi

    # Get current files being worked on (last 10 git status files)
    local current_files=""
    if [ -n "$git_root" ]; then
        current_files=$(cd "$git_root" && git status --short 2>/dev/null | head -10 | awk '{print $2}' || echo "")
    fi

    # Return context info
    echo "pwd:$pwd_path"
    echo "git_root:$git_root"
    echo "files:$current_files"
}

match_issue_to_context() {
    local issue_title="$1"
    local issue_labels="$2"
    local context="$3"

    # Extract context components
    local pwd=$(echo "$context" | grep "^pwd:" | cut -d: -f2-)
    local files=$(echo "$context" | grep "^files:" | cut -d: -f2-)

    # Simple keyword matching
    local score=0

    # Match file paths in issue title
    if [ -n "$files" ]; then
        while IFS= read -r file; do
            if echo "$issue_title" | grep -qi "$(basename "$file")"; then
                ((score+=10))
            fi
        done <<< "$files"
    fi

    # Match directory name
    local dir_name=$(basename "$pwd")
    if echo "$issue_title" | grep -qi "$dir_name"; then
        ((score+=5))
    fi

    # Priority labels
    if echo "$issue_labels" | grep -qi "bug\|critical\|high"; then
        ((score+=3))
    fi

    echo "$score"
}

# ==============================================================================
# Display Functions
# ==============================================================================

display_issues() {
    local context="$1"
    shift
    local issues=("$@")

    if [ ${#issues[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No open issues${NC}"
        return 0
    fi

    echo -e "${CYAN}📋 Open GitHub Issues:${NC}"
    echo ""

    # Parse and display issues with relevance scoring
    local issue_data=""
    while IFS=$'\t' read -r number title labels assignees; do
        local score=$(match_issue_to_context "$title" "$labels" "$context")

        # Format issue line
        local prefix="  •"
        if [ $score -gt 10 ]; then
            prefix="${GREEN}  ★${NC}"  # Highly relevant
        elif [ $score -gt 5 ]; then
            prefix="${YELLOW}  •${NC}"  # Somewhat relevant
        fi

        echo -e "$prefix Issue #$number: $title"

        if [ -n "$labels" ]; then
            echo -e "    ${BLUE}Labels:${NC} $labels"
        fi

        if [ $score -gt 5 ]; then
            echo -e "    ${MAGENTA}Relevance: High (score: $score)${NC}"
        fi

        echo ""
    done <<< "$issues"

    echo -e "${CYAN}View all:${NC} gh issue list --repo $GITHUB_REPO"
    echo ""
}

# ==============================================================================
# Cache Management
# ==============================================================================

CACHE_DIR="${HOME}/.cache/aea"
CACHE_FILE="${CACHE_DIR}/github-issues.cache"

should_check_cache() {
    local check_interval="$1"

    if [ ! -f "$CACHE_FILE" ]; then
        return 0  # No cache, should check
    fi

    local cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
    local interval_seconds=$((check_interval * 60))

    if [ $cache_age -gt $interval_seconds ]; then
        return 0  # Cache expired
    fi

    return 1  # Cache still valid
}

save_to_cache() {
    mkdir -p "$CACHE_DIR"
    cat > "$CACHE_FILE"
}

read_from_cache() {
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        return 0
    fi
    return 1
}

# ==============================================================================
# Main Logic
# ==============================================================================

main() {
    local config_file=".aea/agent-config.yaml"
    local force_check=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                force_check=true
                shift
                ;;
            --config|-c)
                config_file="$2"
                shift 2
                ;;
            --help|-h)
                cat << EOF
AEA GitHub Issues Checker

USAGE:
    bash aea-issues.sh [OPTIONS]

OPTIONS:
    --force, -f         Force check (ignore cache)
    --config FILE       Use specific config file
    --help, -h          Show this help

DESCRIPTION:
    Checks GitHub issues for the repository and displays relevant ones
    based on your current work context.

CONFIGURATION:
    Add to agent-config.yaml:

    github_integration:
      enabled: true
      repository: "owner/repo"
      labels:
        - bug
        - enhancement
      check_interval_minutes: 60

EOF
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done

    # Load configuration
    if ! load_config "$config_file"; then
        echo -e "${YELLOW}⚠ GitHub integration not configured${NC}"
        echo ""
        echo "Add to $config_file:"
        echo ""
        cat << 'EOF'
github_integration:
  enabled: true
  repository: "owner/repo"  # e.g., "openSVM/aea"
  labels:
    - bug
    - enhancement
  check_interval_minutes: 60
EOF
        echo ""
        exit 0
    fi

    # Check if enabled
    if [ "$ENABLED" != "true" ]; then
        # Silently exit if disabled
        exit 0
    fi

    # Check for gh CLI
    if ! check_gh_cli; then
        exit 1
    fi

    # Check cache unless forced
    local issues=""
    if ! $force_check && ! should_check_cache "$CHECK_INTERVAL"; then
        issues=$(read_from_cache)
    else
        # Fetch fresh issues
        issues=$(fetch_issues "$GITHUB_REPO" "$LABELS" 10)

        if [ $? -eq 0 ] && [ -n "$issues" ]; then
            echo "$issues" | save_to_cache
        fi
    fi

    # Get current context
    local context=$(get_current_context)

    # Display issues
    if [ -n "$issues" ]; then
        display_issues "$context" "$issues"
    else
        echo -e "${GREEN}✓ No open issues${NC}"
    fi
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
