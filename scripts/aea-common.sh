#!/bin/bash
# aea-common.sh - Common utilities for AEA scripts
# Source this file in other scripts: source "$(dirname "$0")/aea-common.sh"

# ==============================================================================
# Timestamp Functions
# ==============================================================================

# Get timestamp for filenames (compact with milliseconds)
# Format: 20251022T085436123Z
get_timestamp_compact() {
    # Try to get milliseconds (not all systems support %N)
    if date --version &>/dev/null; then
        # GNU date
        date -u +%Y%m%dT%H%M%S%3NZ 2>/dev/null || date -u +%Y%m%dT%H%M%SZ
    else
        # BSD date (macOS)
        date -u +%Y%m%dT%H%M%SZ
    fi
}

# Get timestamp for JSON/logs (ISO 8601 with milliseconds)
# Format: 2025-10-22T08:54:36.123Z
get_timestamp_iso8601() {
    # Try to get milliseconds (not all systems support %N)
    if date --version &>/dev/null; then
        # GNU date
        date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ
    else
        # BSD date (macOS) - no milliseconds
        date -u +%Y-%m-%dT%H:%M:%SZ
    fi
}

# Get timestamp for logs (human-readable)
# Format: 2025-10-22 08:54:36 UTC
get_timestamp_log() {
    date -u '+%Y-%m-%d %H:%M:%S UTC'
}

# Get Unix timestamp (seconds since epoch)
get_timestamp_unix() {
    date +%s
}

# ==============================================================================
# Path Resolution Functions
# ==============================================================================

# Resolve the real path of a script (handles symlinks)
# Usage: SCRIPT_PATH=$(resolve_script_path "${BASH_SOURCE[0]}")
resolve_script_path() {
    local script_path="$1"

    if command -v readlink &>/dev/null; then
        readlink -f "$script_path" 2>/dev/null || {
            echo "$(cd "$(dirname "$script_path")" && pwd)/$(basename "$script_path")"
        }
    elif command -v realpath &>/dev/null; then
        realpath "$script_path" 2>/dev/null || {
            echo "$(cd "$(dirname "$script_path")" && pwd)/$(basename "$script_path")"
        }
    else
        # Fallback
        echo "$(cd "$(dirname "$script_path")" && pwd)/$(basename "$script_path")"
    fi
}

# Find the .aea directory from a script location
# Usage: AEA_DIR=$(find_aea_directory "$SCRIPT_DIR")
find_aea_directory() {
    local script_dir="$1"

    # If script is in scripts/ subdirectory, go up one level
    if [ "$(basename "$script_dir")" = "scripts" ]; then
        dirname "$script_dir"
    else
        echo "$script_dir"
    fi
}

# ==============================================================================
# Validation Functions
# ==============================================================================

# Check if jq is installed
require_jq() {
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required but not installed" >&2
        echo "Install: apt-get install jq (Debian/Ubuntu) or brew install jq (Mac)" >&2
        return 1
    fi
    return 0
}

# Validate agent ID format
# Returns 0 if valid, 1 if invalid
validate_agent_id() {
    local agent_id="$1"

    # Must be alphanumeric with hyphens/underscores
    if ! echo "$agent_id" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        return 1
    fi

    # Length check (3-64 characters)
    if [ ${#agent_id} -lt 3 ] || [ ${#agent_id} -gt 64 ]; then
        return 1
    fi

    return 0
}

# Validate path for security (checks for path traversal)
# Returns 0 if valid, 1 if invalid
validate_path() {
    local path="$1"

    # Check for path traversal
    case "$path" in
        *..*)
            return 1
            ;;
        *$'\n'*|*$'\0'*)
            return 1
            ;;
    esac

    return 0
}

# ==============================================================================
# Logging Functions
# ==============================================================================

# Log levels
declare -r LOG_LEVEL_ERROR=0
declare -r LOG_LEVEL_WARN=1
declare -r LOG_LEVEL_INFO=2
declare -r LOG_LEVEL_DEBUG=3

# Current log level (default: INFO)
AEA_LOG_LEVEL=${AEA_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Colors
if [ -t 1 ]; then
    # Terminal supports colors
    declare -r COLOR_RED='\033[0;31m'
    declare -r COLOR_GREEN='\033[0;32m'
    declare -r COLOR_YELLOW='\033[1;33m'
    declare -r COLOR_BLUE='\033[0;34m'
    declare -r COLOR_CYAN='\033[0;36m'
    declare -r COLOR_NC='\033[0m'
else
    # No color support
    declare -r COLOR_RED=''
    declare -r COLOR_GREEN=''
    declare -r COLOR_YELLOW=''
    declare -r COLOR_BLUE=''
    declare -r COLOR_CYAN=''
    declare -r COLOR_NC=''
fi

log_error() {
    [ $AEA_LOG_LEVEL -ge $LOG_LEVEL_ERROR ] && \
        echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1" >&2
}

log_warn() {
    [ $AEA_LOG_LEVEL -ge $LOG_LEVEL_WARN ] && \
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1" >&2
}

log_info() {
    [ $AEA_LOG_LEVEL -ge $LOG_LEVEL_INFO ] && \
        echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1"
}

log_debug() {
    [ $AEA_LOG_LEVEL -ge $LOG_LEVEL_DEBUG ] && \
        echo -e "${COLOR_CYAN}[DEBUG]${COLOR_NC} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $1"
}

# ==============================================================================
# File Operations
# ==============================================================================

# Safely write to a file with atomic rename
# Usage: atomic_write "/path/to/file" "content"
atomic_write() {
    local file_path="$1"
    local content="$2"
    local temp_file="${file_path}.tmp.$$"

    # Validate file path doesn't contain path traversal
    case "$file_path" in
        *..*)
            log_error "Path contains '..' (path traversal attempt)"
            return 1
            ;;
    esac

    # Write to temp file
    if ! printf '%s' "$content" > "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi

    # Atomic rename
    if ! mv "$temp_file" "$file_path"; then
        rm -f "$temp_file"
        return 1
    fi

    return 0
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir_path="$1"
    mkdir -p "$dir_path" 2>/dev/null || return 1
    return 0
}

# ==============================================================================
# String Operations
# ==============================================================================

# Sanitize string for use in filenames
# Removes special characters, limits length
sanitize_filename() {
    local input="$1"
    local max_length="${2:-200}"

    # Remove special characters, keep alphanumeric, hyphens, underscores, dots
    local sanitized=$(echo "$input" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c "$max_length")
    echo "$sanitized"
}

# Escape string for safe use in shell
escape_shell() {
    local input="$1"
    printf '%q' "$input"
}

# ==============================================================================
# Performance Optimization
# ==============================================================================

# Get basename without spawning subprocess
# Usage: basename=$(get_basename "/path/to/file.txt")
get_basename() {
    local path="$1"
    echo "${path##*/}"
}

# Get dirname without spawning subprocess
# Usage: dirname=$(get_dirname "/path/to/file.txt")
get_dirname() {
    local path="$1"
    echo "${path%/*}"
}

# Get file extension
# Usage: ext=$(get_extension "file.tar.gz")
get_extension() {
    local filename="$1"
    echo "${filename##*.}"
}

# ==============================================================================
# Version Information
# ==============================================================================

AEA_COMMON_VERSION="1.0.0"

# Print library version
print_version() {
    echo "AEA Common Utilities v${AEA_COMMON_VERSION}"
}

# ==============================================================================
# Initialization
# ==============================================================================

# This file can be sourced multiple times safely
if [ -z "${AEA_COMMON_LOADED:-}" ]; then
    export AEA_COMMON_LOADED=1

    # Debug: Log that common utilities were loaded
    if [ "${AEA_DEBUG:-0}" = "1" ]; then
        log_debug "Loaded aea-common.sh v${AEA_COMMON_VERSION}"
    fi
fi
