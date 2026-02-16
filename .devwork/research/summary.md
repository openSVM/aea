# Research Summary

## Prompt
# PR #4: Add desktop notifications with anti-spam throttling to AEA monitor

## Description
The AEA monitor logs message arrivals to the terminal but provides no notification when the terminal is not in focus.

## Changes

**`scripts/aea-monitor.sh`** (+31 lines)

- Added `send_notification()` helper that conditionally calls `notify-send` if available
- Integrated notification call in `check_project_messages()` when unprocessed messages are detected
- **Added intelligent throttling to prevent notification spam**

## Implementation

```bash
send_notification() {
    local title="$1"
    local message="$2"
    
    # Optional: Send desktop notification if available
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message" -i dialog-information -t 10000 2>/dev/null || true
    fi
}

# Throttling logic - only notify when message count increases
local notif_state_file="$CONFIG_DIR/.notification_state_$(echo "$project_path" | md5sum | cut -d' ' -f1)"
local last_notified_count=0

if [ -f "$notif_state_file" ]; then
    last_notified_count=$(cat "$notif_state_file" 2>/dev/null || echo 0)
fi

# Only notify if message count increased (new messages arrived)
if [ "$unprocessed_count" -gt "$last_notified_count" ]; then
    send_notification "AEA Monitor" "New messages in $project_name"
    echo "$unprocessed_count" > "$notif_state_file"
fi
```

Notification displays for 10 seconds with `dialog-information` icon. Gracefully no-ops if `notify-send` unavailable.

## Anti-Spam Throttling

The notification system includes intelligent throttling to prevent spam:

- **State tracking**: Stores last notified message count per project in `~/.config/aea/.notification_state_<hash>`
- **Conditional alerts**: Only sends notification when message count increases (new messages arrive)
- **Automatic cleanup**: Clears state when all messages are processed

**Example behavior:**
- 3 messages detected → ✅ Notification sent
- Same 3 messages (5 min later) → ⏭️ No notification
- 5 messages now (2 new arrived) → ✅ Notification sent
- All processed → State cleared
- 1 new message → ✅ Notif
... (truncated)

## Diff
```diff
diff --git a/scripts/aea-monitor.sh b/scripts/aea-monitor.sh
index d67205a..3040595 100755
--- a/scripts/aea-monitor.sh
+++ b/scripts/aea-monitor.sh
@@ -54,6 +54,16 @@ info() {
     echo -e "${BLUE}[AEA Monitor]${NC} $1"
 }
 
+send_notification() {
+    local title="$1"
+    local message="$2"
+    
+    # Optional: Send desktop notification if available
+    if command -v notify-send &> /dev/null; then
+        notify-send "$title" "$message" -i dialog-information -t 10000 2>/dev/null || true
+    fi
+}
+
 #===============================================================================
 # PID Management
 #===============================================================================
@@ -347,10 +357,29 @@ check_project_messages() {
             echo "[$timestamp] Monitor found $unprocessed_count unprocessed messages" >> ".aea/agent.log"
         fi
 
+        # Send desktop notification only if message count has increased
+        # Track notification state to avoid spam
+        local notif_state_file="$CONFIG_DIR/.notification_state_$(echo "$project_path" | md5sum | cut -d' ' -f1)"
+        local last_notified_count=0
+        
+        if [ -f "$notif_state_file" ]; then
+            last_notified_count=$(cat "$notif_state_file" 2>/dev/null || echo 0)
+        fi
+        
+        # Only notify if message count increased (new messages arrived)
+        if [ "$unprocessed_count" -gt "$last_notified_count" ]; then
+            send_notification "AEA Monitor" "New messages in $project_name"
+            echo "$unprocessed_count" > "$notif_state_file"
+        fi
+
         # TODO: In future, this would trigger Claude via API
         # For now, just log that messages are waiting
         warn "⏳ Messages waiting for Claude processing in $project_name"
         warn "   Run: cd $project_path && /aea"
+    else
+        # Clear notification state when all messages are processed
+        local notif_state_file="$CONFIG_DIR/.notification_state_$(echo "$project_path" | md5sum | cut -d' ' -f1)"
+        rm -f "$notif_state_file" 2>/dev/null
     fi
 }
 
```

## Task
The AEA monitor logs message arrivals to the terminal but provides no notification when the terminal is not in focus.

## Changes

**`scripts/aea-monitor.sh`** (+31 lines)

- Added `send_notification()` helper that conditionally calls `notify-send` if available
- Integrated notification call in `check_project_messages()` when unprocessed messages are detected
- **Added intelligent throttling to prevent notification spam**

## Implementation

```bash
send_notification() {
    local title="$1"
    local message="$2"
    
    # Optional: Send desktop notification if available
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message" -i dialog-information -t 10000 2>/dev/null || true
    fi
}

# Throttling logic - only notify when message count increases
local notif_state_file="$CONFIG_DIR/.notification_state_$(echo "$project_path" | md5sum | cut -d' ' -f1)"
local last_notified_count=0

if [ -f "$notif_state_file" ]; then
    last_notified_count=$(cat "$notif_state_file" 2>/dev/null || echo 0)
fi

# Only notify if message count increased (new messages arrived)
if [ "$unprocessed_count" -gt "$last_notified_count" ]; then
    send_notification "AEA Monitor" "New messages in $project_name"
    echo "$unprocessed_count" > "$notif_state_file"
fi
```

Notification displays for 10 seconds with `dialog-information` icon. Gracefully no-ops if `notify-send` unavailable.

## Anti-Spam Throttling

The notification system includes intelligent throttling to prevent spam:

- **State tracking**: Stores last notified message count per project in `~/.config/aea/.notification_state_<hash>`
- **Conditional alerts**: Only sends notification when message count increases (new messages arrive)
- **Automatic cleanup**: Clears state when all messages are processed

**Example behavior:**
- 3 messages detected → ✅ Notification sent
- Same 3 messages (5 min later) → ⏭️ No notification
- 5 messages now (2 new arrived) → ✅ Notification sent
- All processed → State cleared
- 1 new message → ✅ Notification sent

Ready for extension to macOS/Windows notification systems.

- Fixes openSVM/aea#3

<!-- START COPILOT CODING AGENT SUFFIX -->



<details>

<summary>Original prompt</summary>

> 
> ----
> 
> *This section details on the original issue you should resolve*
> 
> <issue_title>Enhancement: Add desktop notifications to AEA monitor script</issue_title>
> <issue_description>## Enhancement Description
> 
> The AEA monitor script currently only logs messages to the terminal when new messages are detected. Adding desktop notification support would greatly improve the user experience by providing visual alerts even when the terminal is not in focus.
> 
> ## Proposed Changes
> 
> Add optional desktop notification support to `scripts/aea-monitor.sh` when new AEA messages are detected:
> 
> ```bash
> # Optional: Send desktop notification if available
> if command -v notify-send &> /dev/null; then
>     notify-send "AEA Monitor" "New messages in $project_name" -i dialog-information -t 10000
> fi
> ```
> 
> ## Benefits
> 
> 1. **Improved User Experience**: Users get immediate visual feedback about new messages without constantly watching the terminal
> 2. **Non-intrusive**: Only triggers if `notify-send` is available (Linux desktop environments)
> 3. **Configurable**: Can be easily disabled or customized
> 4. **Cross-platform potential**: Could be extended to support macOS (`osascript`) and Windows notifications
> 
> ## Implementation Details
> 
> The enhancement has been tested in a production environment and works reliably. The notification:
> - Shows for 10 seconds (configurable)
> - Displays the project name where messages are waiting
> - Uses standard dialog-information icon
> - Only triggers when `notify-send` command is available
> 
> ## Additional Considerations
> 
> Future enhancements could include:
> - Configuration option to enable/disable notifications
> - Custom notification icons for different message types
> - Sound alerts for urgent messages
> - Integration with other notification systems (Growl, Windows Toast, etc.)
> 
> ## Testing
> 
> Tested on Ubuntu 22.04 with GNOME desktop environment. The notification appears correctly and doesn't interfere with the monitor's core functionality.
> 
> Would you like me to submit a pull request with this enhancement?</issue_description>
> 
> ## Comments on the Issue (you are @copilot in this section)
> 
> <comments>
> </comments>
> 


</details>

- Fixes openSVM/aea#3

<!-- START COPILOT CODING AGENT TIPS -->
---

💬 We'd love your input! Share your thoughts on Copilot coding agent in our [2 minute survey](https://gh.io/copilot-coding-agent-survey).



## Findings
## Research Summary: PR #4 - Desktop Notifications with Anti-Spam Throttling

### Project Structure
- **Working Directory**: `/tmp/claudev-pr-19260`
- **Target File**: `scripts/aea-monitor.sh` (bash script)
- **Configuration Directory**: `$HOME/.config/aea/`

### Changes Implemented

The PR adds desktop notification support with intelligent throttling to prevent spam:

#### 1. `send_notification()` Helper Function (lines 55-62)
```bash
send_notification() {
    local title="$1"
    local message="$2"
    
    # Optional: Send desktop notification if available
    if command -v notify-send &> /dev/null; then
        notify-send "$title" "$message" -i dialog-information -t 10000 2>/dev/null || true
    fi
}
```
- Uses `notify-send` command (standard Linux desktop notification tool)
- Gracefully no-ops if `notify-send` is unavailable
- Uses `-i dialog-information` icon and `-t 10000` (10 second display time)
- Errors are suppressed with `2>/dev/null || true`

#### 2. Anti-Spam Throttling Logic (lines 358-385)
The throttling mechanism:
- **State tracking**: Creates a file `~/.config/aea/.notification_state_<hash>` per project
- **Hash generation**: Uses `md5sum` on the project path for unique identification
- **Conditional alerts**: Only notifies when `unprocessed_count > last_notified_count`
- **Automatic cleanup**: Clears state file when all messages are processed (in the `else` block)

#### 3. Key Implementation Details
- **State file path**: `$CONFIG_DIR/.notification_state_$(echo "$project_path" | md5sum | cut -d' ' -f1)`
- **Message count comparison**: Compares current unprocessed count against previously stored count
- **Cleanup in else block**: Removes notification state when messages are processed

### Git History
```
5156e7b Add notification throttling to prevent spam  <- Current PR
2fac318 Add desktop notification support to AEA monitor script  <- Previous commit
```

### Technology Stack
- **Language**: Bash (POSIX-compatible)
- **Notification Tool**: `notify-send` (part of libnotify on Linux)
- **No external package managers required**: Uses only standard Linux utilities (`md5sum`, `grep`, `awk`)

### No External Libraries Needed
This task uses only standard system tools:
- `notify-send` - Linux desktop notifications (libnotify)
- `md5sum` - Hash generation
- Standard bash string manipulation

### Gotchas & Notes
1. The `send_notification()` function already exists in the current codebase
2. The throttling logic was added in commit `5156e7b` to prevent notification spam
3. The notification state file uses project path hashing to distinguish between multiple monitored projects
4. The `-t 10000` flag sets notification timeout to 10 seconds
5. The `|| true` at the end ensures the function never fails even if notify-send encounters errors
6. Cross-platform support (macOS/Windows) is mentioned as future enhancement in the PR description
