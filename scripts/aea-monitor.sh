#!/usr/bin/env bash
#
# AEA Background Monitor
# Sophisticated daemon for autonomous inter-agent message processing
#
# Features:
# - Auto-registers current directory to ~/.config/aea/projects.yaml
# - PID management with health checks
# - Graceful shutdown of existing instances
# - Calls /aea command in Claude for each monitored project
# - Runs as background service
#
# Usage:
#   bash .aea/scripts/aea-monitor.sh        # Start monitoring
#   bash .aea/scripts/aea-monitor.sh stop   # Stop monitoring
#   bash .aea/scripts/aea-monitor.sh status # Check status
#

set -e

# Configuration
CONFIG_DIR="$HOME/.config/aea"
CONFIG_FILE="$CONFIG_DIR/projects.yaml"
CHECK_INTERVAL=300  # 5 minutes

# Get absolute path of current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_NAME="$(basename "$CURRENT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

#===============================================================================
# Utility Functions
#===============================================================================

log() {
    echo -e "${GREEN}[AEA Monitor]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AEA Monitor]${NC} $1"
}

error() {
    echo -e "${RED}[AEA Monitor]${NC} $1"
}

info() {
    echo -e "${BLUE}[AEA Monitor]${NC} $1"
}

#===============================================================================
# PID Management
#===============================================================================

get_monitor_pid() {
    local project_path="$1"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        return
    fi

    # Parse YAML to get job_pid for this project
    # Simple parsing - assumes format: "  job_pid: 12345"
    local pid=$(grep -A 10 "path: \"$project_path\"" "$CONFIG_FILE" 2>/dev/null | grep "job_pid:" | head -1 | awk '{print $2}')

    # Filter out "null" values
    if [ "$pid" = "null" ] || [ -z "$pid" ]; then
        echo ""
    else
        echo "$pid"
    fi
}

is_process_alive() {
    local pid="$1"
    if [ -z "$pid" ]; then
        return 1
    fi
    kill -0 "$pid" 2>/dev/null
    return $?
}

send_healthcheck() {
    local pid="$1"
    if [ -z "$pid" ]; then
        echo "ERROR"
        return 1
    fi

    # Try to send SIGUSR1 (health check signal)
    # If process responds, it's healthy
    if kill -USR1 "$pid" 2>/dev/null; then
        # Check if process still alive after signal
        sleep 0.1
        if is_process_alive "$pid"; then
            echo "OK"
            return 0
        fi
    fi

    echo "ERROR"
    return 1
}

terminate_process() {
    local pid="$1"
    local max_wait=10
    log "Terminating existing monitor (PID: $pid)..."

    # Try graceful shutdown first (SIGTERM)
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait up to 10 seconds for graceful shutdown
        local waited=0
        while [ $waited -lt $max_wait ]; do
            if ! is_process_alive "$pid"; then
                log "Process terminated gracefully"
                return 0
            fi
            sleep 1
            waited=$((waited + 1))
        done
    fi

    # Still alive after SIGTERM - try SIGKILL as last resort
    if is_process_alive "$pid"; then
        warn "Process did not respond to SIGTERM after ${max_wait}s"
        warn "Sending SIGKILL (this may prevent cleanup)..."
        if kill -KILL "$pid" 2>/dev/null; then
            sleep 1
            if ! is_process_alive "$pid"; then
                warn "Process killed forcefully"
                return 0
            else
                error "Failed to kill process $pid"
                return 1
            fi
        else
            error "Failed to send SIGKILL to process $pid"
            return 1
        fi
    fi

    return 0
}

update_pid_in_config() {
    local project_path="$1"
    local new_pid="$2"

    # Ensure config exists
    ensure_config_exists

    # Use flock for atomic updates to prevent race conditions
    local lockfile="$CONFIG_DIR/config.lock"
    local tempfile="$CONFIG_FILE.tmp.$$"

    # Acquire lock (wait up to 5 seconds)
    (
        if ! flock -w 5 200; then
            warn "Could not acquire config lock, skipping PID update"
            return 1
        fi

        # Check if project exists in config using awk for safer YAML parsing
        if grep -q "path: \"$project_path\"" "$CONFIG_FILE" 2>/dev/null; then
            # Update existing PID using awk for safer processing
            awk -v path="$project_path" -v pid="$new_pid" '
                BEGIN { in_project = 0 }
                /^  - name:/ { in_project = 0 }
                $0 ~ "path: \"" path "\"" { in_project = 1 }
                in_project && /job_pid:/ { print "    job_pid: " pid; next }
                { print }
            ' "$CONFIG_FILE" > "$tempfile"

            if [ -s "$tempfile" ]; then
                mv "$tempfile" "$CONFIG_FILE" || {
                    warn "Failed to update config file"
                    rm -f "$tempfile"
                    return 1
                }
            else
                warn "Failed to generate updated config"
                rm -f "$tempfile"
                return 1
            fi
        else
            # Add new project entry
            cat >> "$CONFIG_FILE" <<EOF

  - name: "$PROJECT_NAME"
    path: "$project_path"
    enabled: true
    check_interval: $CHECK_INTERVAL
    job_pid: $new_pid
    agent_id: "claude-$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
    last_check: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EOF
        fi

        log "Updated PID in config: $new_pid"
    ) 200>"$lockfile"

    # Cleanup lock file on exit
    local exit_status=$?
    rm -f "$lockfile"
    return $exit_status
}

remove_pid_from_config() {
    local project_path="$1"

    if [ -f "$CONFIG_FILE" ]; then
        local lockfile="$CONFIG_DIR/config.lock"
        local tempfile="$CONFIG_FILE.tmp.$$"

        # Acquire lock for safe update
        (
            if ! flock -w 5 200; then
                warn "Could not acquire config lock, skipping PID removal"
                return 1
            fi

            # Use awk for safer YAML processing
            awk -v path="$project_path" '
                BEGIN { in_project = 0 }
                /^  - name:/ { in_project = 0 }
                $0 ~ "path: \"" path "\"" { in_project = 1 }
                in_project && /job_pid:/ { print "    job_pid: null"; next }
                { print }
            ' "$CONFIG_FILE" > "$tempfile"

            if [ -s "$tempfile" ]; then
                mv "$tempfile" "$CONFIG_FILE" || {
                    warn "Failed to update config file"
                    rm -f "$tempfile"
                    return 1
                }
            else
                rm -f "$tempfile"
                return 1
            fi
        ) 200>"$lockfile"

        rm -f "$lockfile"
        log "Removed PID from config"
    fi
}

#===============================================================================
# Config Management
#===============================================================================

ensure_config_exists() {
    mkdir -p "$CONFIG_DIR"

    if [ ! -f "$CONFIG_FILE" ]; then
        log "Creating config file: $CONFIG_FILE"
        cat > "$CONFIG_FILE" <<'EOF'
# AEA Background Monitor Configuration
# Manages autonomous inter-agent communication monitoring

version: "1.0"
check_interval_default: 300  # 5 minutes

# Monitored projects
projects:
EOF
    fi
}

register_current_project() {
    ensure_config_exists

    # Check if already registered
    if grep -q "path: \"$CURRENT_DIR\"" "$CONFIG_FILE" 2>/dev/null; then
        info "Project already registered: $PROJECT_NAME"
        return 0
    fi

    log "Registering project: $PROJECT_NAME"
    log "Path: $CURRENT_DIR"

    cat >> "$CONFIG_FILE" <<EOF

  - name: "$PROJECT_NAME"
    path: "$CURRENT_DIR"
    enabled: true
    check_interval: $CHECK_INTERVAL
    job_pid: null
    agent_id: "claude-$(echo $PROJECT_NAME | tr '[:upper:]' '[:lower:]')"
    last_check: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EOF

    log "✅ Project registered"
}

get_all_projects() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo ""
        return
    fi

    # Extract all project paths
    grep "path: " "$CONFIG_FILE" | sed 's/.*path: "\(.*\)"/\1/' || echo ""
}

#===============================================================================
# Monitoring Logic
#===============================================================================

check_project_messages() {
    local project_path="$1"
    local project_name="$(basename "$project_path")"

    info "Checking: $project_name"

    # Change to project directory
    cd "$project_path" || return 1

    # Check for unprocessed messages
    local unprocessed_count=0
    if [ -d ".aea" ]; then
        mkdir -p ".aea/.processed"

        for msg in .aea/message-*.json; do
            [ -e "$msg" ] || continue
            basename_msg=$(basename "$msg")

            if [ ! -f ".aea/.processed/$basename_msg" ]; then
                unprocessed_count=$((unprocessed_count + 1))
            fi
        done
    fi

    if [ $unprocessed_count -gt 0 ]; then
        log "📬 Found $unprocessed_count unprocessed message(s) in $project_name"

        # Log to project's AEA log
        if [ -d ".aea" ]; then
            timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            echo "[$timestamp] Monitor found $unprocessed_count unprocessed messages" >> ".aea/agent.log"
        fi

        # TODO: In future, this would trigger Claude via API
        # For now, just log that messages are waiting
        warn "⏳ Messages waiting for Claude processing in $project_name"
        warn "   Run: cd $project_path && /aea"
    fi
}

monitor_loop() {
    log "🚀 Starting AEA background monitor"
    log "PID: $$"
    log "Check interval: ${CHECK_INTERVAL}s"

    # Update PID in config
    update_pid_in_config "$CURRENT_DIR" "$$"

    # Set up signal handlers
    trap 'cleanup_and_exit' SIGTERM SIGINT
    trap 'handle_healthcheck' SIGUSR1

    # Main monitoring loop
    while true; do
        # Get all registered projects
        local projects=$(get_all_projects)

        if [ -n "$projects" ]; then
            while IFS= read -r project_path; do
                [ -n "$project_path" ] || continue

                # Check if project directory exists
                if [ -d "$project_path" ]; then
                    check_project_messages "$project_path"
                else
                    warn "Project path not found: $project_path"
                fi
            done <<< "$projects"
        fi

        # Update last check time using awk for safer processing
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local tempfile="$CONFIG_FILE.tmp.$$"

        awk -v path="$CURRENT_DIR" -v ts="$timestamp" '
            BEGIN { in_project = 0 }
            /^  - name:/ { in_project = 0 }
            $0 ~ "path: \"" path "\"" { in_project = 1 }
            in_project && /last_check:/ { print "    last_check: \"" ts "\""; next }
            { print }
        ' "$CONFIG_FILE" > "$tempfile" 2>/dev/null

        if [ -s "$tempfile" ]; then
            mv "$tempfile" "$CONFIG_FILE" 2>/dev/null || {
                warn "Failed to update last_check timestamp in config"
                rm -f "$tempfile"
            }
        else
            warn "Failed to generate updated config for last_check"
            rm -f "$tempfile"
        fi

        # Sleep until next check
        sleep "$CHECK_INTERVAL"
    done
}

handle_healthcheck() {
    # Respond to health check signal
    # Process is still alive if this handler runs
    :
}

cleanup_and_exit() {
    log "Shutting down monitor..."
    remove_pid_from_config "$CURRENT_DIR"
    exit 0
}

#===============================================================================
# Command Handlers
#===============================================================================

start_monitor() {
    log "Starting AEA monitor for: $PROJECT_NAME"

    # Register project if not already registered
    register_current_project

    # Check for existing monitor
    existing_pid=$(get_monitor_pid "$CURRENT_DIR")

    if [ -n "$existing_pid" ]; then
        info "Found existing monitor (PID: $existing_pid)"

        # Health check
        health_status=$(send_healthcheck "$existing_pid")

        if [ "$health_status" = "OK" ]; then
            log "✅ Existing monitor is healthy"
            log "Shutting down - another instance is already running"
            exit 0
        else
            warn "⚠️ Existing monitor is not responding"
            terminate_process "$existing_pid"
        fi
    fi

    # Start new monitor in background
    log "🚀 Launching new monitor..."

    # Fork to background
    nohup bash "$0" __monitor_loop >> "$HOME/.config/aea/monitor.log" 2>&1 &
    new_pid=$!

    # Wait a moment to ensure it started
    sleep 1

    if is_process_alive "$new_pid"; then
        update_pid_in_config "$CURRENT_DIR" "$new_pid"
        log "✅ Monitor started successfully (PID: $new_pid)"
        log "📝 Logs: $HOME/.config/aea/monitor.log"
    else
        error "❌ Failed to start monitor"
        exit 1
    fi
}

stop_monitor() {
    log "Stopping AEA monitor for: $PROJECT_NAME"

    existing_pid=$(get_monitor_pid "$CURRENT_DIR")

    if [ -z "$existing_pid" ]; then
        warn "No monitor running for this project"
        exit 0
    fi

    if ! is_process_alive "$existing_pid"; then
        warn "Monitor PID $existing_pid is not running"
        remove_pid_from_config "$CURRENT_DIR"
        exit 0
    fi

    terminate_process "$existing_pid"
    remove_pid_from_config "$CURRENT_DIR"
    log "✅ Monitor stopped"
}

show_status() {
    log "AEA Monitor Status for: $PROJECT_NAME"
    echo ""

    existing_pid=$(get_monitor_pid "$CURRENT_DIR")

    if [ -z "$existing_pid" ]; then
        echo -e "  Status: ${RED}Not running${NC}"
        exit 0
    fi

    if is_process_alive "$existing_pid"; then
        health_status=$(send_healthcheck "$existing_pid")

        if [ "$health_status" = "OK" ]; then
            echo -e "  Status: ${GREEN}Running${NC}"
            echo "  PID: $existing_pid"

            # Get last check time
            if [ -f "$CONFIG_FILE" ]; then
                last_check=$(grep -A 10 "path: \"$CURRENT_DIR\"" "$CONFIG_FILE" | grep "last_check:" | head -1 | sed 's/.*last_check: "\(.*\)"/\1/')
                echo "  Last check: $last_check"
            fi
        else
            echo -e "  Status: ${YELLOW}Unhealthy${NC}"
            echo "  PID: $existing_pid (not responding)"
        fi
    else
        echo -e "  Status: ${RED}Dead${NC}"
        echo "  PID: $existing_pid (process not found)"
    fi

    echo ""
}

#===============================================================================
# Main
#===============================================================================

main() {
    case "${1:-start}" in
        start)
            start_monitor
            ;;
        stop)
            stop_monitor
            ;;
        status)
            show_status
            ;;
        __monitor_loop)
            # Internal use only - actual monitoring loop
            monitor_loop
            ;;
        *)
            echo "Usage: $0 {start|stop|status}"
            echo ""
            echo "Commands:"
            echo "  start   - Start background monitoring (default)"
            echo "  stop    - Stop background monitoring"
            echo "  status  - Show monitor status"
            exit 1
            ;;
    esac
}

main "$@"
