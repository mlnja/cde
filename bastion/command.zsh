# CDE Bastion Tunnel Management
# Port forwarding through bastion hosts using AWS SSM

# Main bastion tunnel command
_cde_bastion() {
    local config_file="$HOME/.cde/config.yml"
    
    # Handle subcommands
    case "$1" in
        "clean")
            _cde_clean_all_tunnels
            return $?
            ;;
        "help"|"-h"|"--help")
            _cde_bastion_help
            return 0
            ;;
    esac
    
    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        gum style --foreground 196 "❌ Config file not found: $config_file"
        echo "Create it with bastion_targets configuration"
        return 1
    fi
    
    # Get current AWS profile
    local current_profile="${AWS_PROFILE:-default}"
    
    # Always show tunnel status table (it will handle the case when current profile has no targets)
    _cde_show_tunnel_table "$current_profile" "$config_file"
}

# Show tunnel status table with tmux session info
_cde_show_tunnel_table() {
    local current_profile="$1"
    local config_file="$2"
    
    # Create display data arrays
    local display_lines=()
    local tunnel_profiles=()  # Parallel array to track profile for each line
    local tunnel_targets=()   # Parallel array to track target name for each line
    
    # Get all active sessions
    local all_active_sessions=()
    while IFS= read -r session; do
        if [[ "$session" =~ ^__mlnj_cde_tun_(.+)_(.+)$ ]]; then
            local session_profile="${match[1]}"
            local session_target="${match[2]}"
            all_active_sessions+=("$session_profile:$session_target")
        fi
    done <<< "$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"
    
    # List 1: All tunnels (active + inactive) from current profile
    while IFS= read -r target_name; do
        if [[ -n "$target_name" ]]; then
            # Check if this target is active
            local is_active=false
            for session_info in "${all_active_sessions[@]}"; do
                local session_profile="${session_info%:*}"
                local session_target="${session_info#*:}"
                if [[ "$session_profile" == "$current_profile" && "$session_target" == "$target_name" ]]; then
                    is_active=true
                    break
                fi
            done
            
            # Add to display
            if [[ "$is_active" == "true" ]]; then
                display_lines+=("✅ Running | 🚇 $target_name")
            else
                display_lines+=("❌ Stopped | 🚇 $target_name")
            fi
            tunnel_profiles+=("$current_profile")
            tunnel_targets+=("$target_name")
        fi
    done <<< "$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\") | .name" "$config_file" 2>/dev/null)"
    
    # List 2: Active tunnels from other profiles (excluding current profile)
    for session_info in "${all_active_sessions[@]}"; do
        local session_profile="${session_info%:*}"
        local session_target="${session_info#*:}"
        
        # Skip if this is from current profile (already handled in List 1)
        if [[ "$session_profile" == "$current_profile" ]]; then
            continue
        fi
        
        # Verify this target exists in config (it might have been removed)
        local target_exists=$(yq eval ".bastion_targets[] | select(.profile == \"$session_profile\" and .name == \"$session_target\") | .name" "$config_file" 2>/dev/null)
        
        if [[ -n "$target_exists" ]]; then
            display_lines+=("✅ Running | 🚇 $session_target ($session_profile)")
            tunnel_profiles+=("$session_profile")
            tunnel_targets+=("$session_target")
        fi
    done
    
    if [[ ${#display_lines[@]} -eq 0 ]]; then
        # No active tunnels from any profile and no targets for current profile
        local targets=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\") | .name" "$config_file" 2>/dev/null)
        if [[ -z "$targets" ]]; then
            gum style --foreground 214 "⚠️  No bastion targets found for profile: $current_profile"
            echo "Available profiles in config:"
            yq eval '.bastion_targets[].profile' "$config_file" 2>/dev/null | sort -u
        fi
        return 0
    fi
    
    # Interactive selection with filter
    gum style --foreground 86 "🚇 Select tunnel:"
    local selected=$(printf '%s\n' "${display_lines[@]}" | gum filter --placeholder="Type to filter tunnels..." --height=10)
    
    if [[ -z "$selected" ]]; then
        return 0
    fi
    
    # Find the index of the selected line
    local selected_index=-1
    for ((i=1; i<=${#display_lines[@]}; i++)); do
        if [[ "${display_lines[i]}" == "$selected" ]]; then
            selected_index=$i
            break
        fi
    done
    
    if [[ $selected_index -eq -1 ]]; then
        return 0
    fi
    
    # Get the profile and target from the parallel arrays using the index
    local chosen_profile="${tunnel_profiles[selected_index]}"
    local chosen_target="${tunnel_targets[selected_index]}"
    
    # Check if tunnel is already running
    local session_name="__mlnj_cde_tun_${chosen_profile}_${chosen_target}"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        _cde_manage_existing_tunnel "$chosen_target" "$session_name"
    else
        _cde_start_new_tunnel "$chosen_target" "$chosen_profile" "$config_file"
    fi
}

# Manage existing tunnel
_cde_manage_existing_tunnel() {
    local target_name="$1"
    local session_name="$2"
    
    echo ""
    local action=$(echo -e "View logs\nKill tunnel" | gum choose --header "Tunnel '$target_name' is running. Choose action:")
    
    case "$action" in
        "View logs")
            local log_file="/tmp/${session_name}.log"
            if [[ -f "$log_file" ]]; then
                less +F "$log_file"
            else
                gum style --foreground 214 "⚠️  Log file not found: $log_file"
            fi
            ;;
        "Kill tunnel")
            gum style --foreground 214 "🔴 Stopping tunnel: $target_name"
            tmux kill-session -t "$session_name"
            # Clean up log file
            local log_file="/tmp/${session_name}.log"
            [[ -f "$log_file" ]] && rm "$log_file"
            gum style --foreground 86 "✅ Tunnel stopped"
            ;;
    esac
}

# Start new tunnel in detached tmux session
_cde_start_new_tunnel() {
    local target_name="$1"
    local current_profile="$2"
    local config_file="$3"
    
    # Get target details
    local target_host=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\" and .name == \"$target_name\") | .host" "$config_file")
    local target_port=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\" and .name == \"$target_name\") | .port" "$config_file")
    
    
    # Check if target details were found
    if [[ -z "$target_host" || -z "$target_port" ]]; then
        gum style --foreground 196 "❌ Target '$target_name' not found in config for profile '$current_profile'"
        echo "Available targets for this profile:"
        yq eval ".bastion_targets[] | select(.profile == \"$current_profile\") | .name + \" -> \" + .host + \":\" + .port" "$config_file" 2>/dev/null
        return 1
    fi
    
    # Parse port (format: remote:local)
    local remote_port="${target_port%:*}"
    local local_port="${target_port#*:}"
    
    gum style --foreground 86 "🔍 Looking for bastion instance..."
    
    # Find bastion instance
    local bastion_instance=$(_cde_find_bastion_instance "$current_profile")
    
    if [[ -z "$bastion_instance" ]]; then
        gum style --foreground 214 "⚠️  No bastion instance found, refreshing SSM instances..."
        
        # Load SSM command if not already loaded
        if ! declare -f _cde_ssm >/dev/null; then
            local cde_dir=$(__mlnj_cde_get_dir)
            local ssm_command="$cde_dir/ssm/command.zsh"
            if [[ -f "$ssm_command" ]]; then
                source "$ssm_command"
            else
                gum style --foreground 196 "❌ SSM command not found"
                return 1
            fi
        fi
        
        # Auto-refresh SSM instances once
        if _cde_ssm refresh; then
            # Try to find bastion again after refresh
            bastion_instance=$(_cde_find_bastion_instance "$current_profile")
            
            if [[ -n "$bastion_instance" ]]; then
                gum style --foreground 86 "✅ Found bastion after refresh: $bastion_instance"
            else
                gum style --foreground 196 "❌ No bastion instance found with tag Bastion=true even after refresh"
                return 1
            fi
        else
            gum style --foreground 196 "❌ Failed to refresh SSM instances"
            return 1
        fi
    fi
    
    gum style --foreground 86 "🚇 Found bastion: $bastion_instance"
    gum style --foreground 86 "🔗 Starting tunnel: $target_name"
    gum style --foreground 214 "📡 $target_host:$remote_port -> localhost:$local_port"
    
    # Create tmux session name and log file
    local session_name="__mlnj_cde_tun_${current_profile}_${target_name}"
    local log_file="/tmp/${session_name}.log"
    
    # Clean up any existing log file
    [[ -f "$log_file" ]] && rm "$log_file"
    
    # Start tunnel in detached tmux session with logging
    tmux new-session -d -s "$session_name" -e AWS_PROFILE="$current_profile" \
        "aws ssm start-session \
        --target '$bastion_instance' \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters 'host=\"$target_host\",portNumber=\"$remote_port\",localPortNumber=\"$local_port\"' \
        2>&1 | tee '$log_file'"
    
    # Prevent users from attaching to tunnel sessions
    # Fallback: Add hook to immediately detach any attach attempts
    tmux set-hook -t "$session_name" client-attached 'detach-client'
    
    # Monitor tunnel startup for a few seconds to detect immediate failures
    gum style --foreground 214 "⏳ Monitoring tunnel startup..."
    
    local startup_success=false
    local check_attempts=0
    local max_startup_checks=10
    
    while [[ $check_attempts -lt $max_startup_checks ]]; do
        sleep 1
        ((check_attempts++))
        
        # Check if tmux session still exists
        if ! tmux has-session -t "$session_name" 2>/dev/null; then
            gum style --foreground 196 "❌ Tunnel session terminated unexpectedly"
            
            # Check if this is due to bastion instance being invalid
            gum style --foreground 214 "🔍 Checking if bastion instance is valid..."
            
            # Load SSM command if not already loaded
            if ! declare -f _cde_ssm >/dev/null; then
                local cde_dir=$(__mlnj_cde_get_dir)
                local ssm_command="$cde_dir/ssm/command.zsh"
                if [[ -f "$ssm_command" ]]; then
                    source "$ssm_command"
                fi
            fi
            
            # Refresh SSM instances to get updated bastion list
            gum style --foreground 214 "🔄 Refreshing bastion instances..."
            if _cde_ssm refresh; then
                local new_bastion=$(_cde_find_bastion_instance "$current_profile")
                
                if [[ -n "$new_bastion" && "$new_bastion" != "$bastion_instance" ]]; then
                    gum style --foreground 86 "✅ Found new bastion: $new_bastion"
                    gum style --foreground 214 "🔄 Restarting tunnel with updated bastion..."
                    
                    # Clean up log file
                    [[ -f "$log_file" ]] && rm "$log_file"
                    
                    # Start new session with updated bastion
                    tmux new-session -d -s "$session_name" -e AWS_PROFILE="$current_profile" \
                        "aws ssm start-session \
                        --target '$new_bastion' \
                        --document-name AWS-StartPortForwardingSessionToRemoteHost \
                        --parameters 'host=\"$target_host\",portNumber=\"$remote_port\",localPortNumber=\"$local_port\"' \
                        2>&1 | tee '$log_file'"
                    
                    tmux set-hook -t "$session_name" client-attached 'detach-client'
                    
                    # Update bastion_instance variable and reset check counter
                    bastion_instance="$new_bastion"
                    check_attempts=0
                    continue
                else
                    gum style --foreground 196 "❌ No alternative bastion instance found"
                    return 1
                fi
            else
                gum style --foreground 196 "❌ Failed to refresh SSM instances"
                return 1
            fi
        fi
        
        # Check log file for connection status
        if [[ -f "$log_file" ]]; then
            if grep -q "TargetNotConnected" "$log_file"; then
                gum style --foreground 214 "🔍 Bastion instance not connected - likely terminated"
                
                # Try to find new bastion instance
                gum style --foreground 214 "🔄 Searching for updated bastion..."
                
                # Load SSM command if not already loaded
                if ! declare -f _cde_ssm >/dev/null; then
                    local cde_dir=$(__mlnj_cde_get_dir)
                    local ssm_command="$cde_dir/ssm/command.zsh"
                    if [[ -f "$ssm_command" ]]; then
                        source "$ssm_command"
                    fi
                fi
                
                # Refresh SSM instances (show errors to user)
                if ! _cde_ssm refresh; then
                    gum style --foreground 196 "❌ Failed to refresh SSM instances"
                    tmux kill-session -t "$session_name" 2>/dev/null
                    [[ -f "$log_file" ]] && rm "$log_file"
                    return 1
                fi
                
                local new_bastion=$(_cde_find_bastion_instance "$current_profile")
                
                if [[ -n "$new_bastion" && "$new_bastion" != "$bastion_instance" ]]; then
                    gum style --foreground 86 "✅ Found new bastion: $new_bastion"
                    gum style --foreground 214 "🔄 Restarting tunnel with updated bastion..."
                    
                    # Kill the failed session
                    tmux kill-session -t "$session_name" 2>/dev/null
                    [[ -f "$log_file" ]] && rm "$log_file"
                    
                    # Start new session with updated bastion
                    tmux new-session -d -s "$session_name" -e AWS_PROFILE="$current_profile" \
                        "aws ssm start-session \
                        --target '$new_bastion' \
                        --document-name AWS-StartPortForwardingSessionToRemoteHost \
                        --parameters 'host=\"$target_host\",portNumber=\"$remote_port\",localPortNumber=\"$local_port\"' \
                        2>&1 | tee '$log_file'"
                    
                    tmux set-hook -t "$session_name" client-attached 'detach-client'
                    
                    # Reset check counter for new session
                    check_attempts=0
                    continue
                else
                    gum style --foreground 196 "❌ No alternative bastion instance found"
                    tmux kill-session -t "$session_name" 2>/dev/null
                    [[ -f "$log_file" ]] && rm "$log_file"
                    return 1
                fi
            elif grep -q "Starting session with SessionId" "$log_file" || grep -q "Port forwarding started" "$log_file"; then
                startup_success=true
                break
            elif grep -q "An error occurred" "$log_file"; then
                gum style --foreground 196 "❌ Tunnel startup failed with error:"
                tail -3 "$log_file" | gum style --foreground 196
                tmux kill-session -t "$session_name" 2>/dev/null
                [[ -f "$log_file" ]] && rm "$log_file"
                return 1
            fi
        fi
    done
    
    if [[ "$startup_success" == "true" ]]; then
        gum style --foreground 86 "✅ Tunnel started successfully in detached session: $session_name"
    else
        gum style --foreground 214 "⚠️  Tunnel started but connection status unclear"
        gum style --foreground 214 "💡 Check logs if experiencing issues"
    fi
    
    echo ""
    gum style --foreground 214 "💡 Use 'cde.tun' again to view logs or stop the tunnel"
}

# Clean all tunnel sessions across all profiles
_cde_clean_all_tunnels() {
    gum style --foreground 214 "🔍 Searching for active tunnel sessions..."
    
    # Find all tmux sessions that match the tunnel naming pattern
    local tunnel_sessions=()
    while IFS= read -r session; do
        if [[ "$session" =~ ^__mlnj_cde_tun_ ]]; then
            tunnel_sessions+=("$session")
        fi
    done <<< "$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"
    
    if [[ ${#tunnel_sessions[@]} -eq 0 ]]; then
        gum style --foreground 86 "✅ No active tunnel sessions found"
        return 0
    fi
    
    gum style --foreground 214 "🚇 Found ${#tunnel_sessions[@]} active tunnel session(s):"
    for session in "${tunnel_sessions[@]}"; do
        # Extract profile and target from session name
        local session_info="${session#__mlnj_cde_tun_}"
        local profile="${session_info%%_*}"
        local target="${session_info#*_}"
        echo "  • $profile → $target"
    done
    
    echo ""
    local confirm=$(echo -e "Yes\nNo" | gum choose --header "Kill all ${#tunnel_sessions[@]} tunnel sessions?")
    
    if [[ "$confirm" != "Yes" ]]; then
        gum style --foreground 214 "ℹ️  Operation cancelled"
        return 0
    fi
    
    # Kill all tunnel sessions and clean up log files
    local killed_count=0
    for session in "${tunnel_sessions[@]}"; do
        gum style --foreground 214 "🔴 Stopping: $session"
        if tmux kill-session -t "$session" 2>/dev/null; then
            ((killed_count++))
            # Clean up log file
            local log_file="/tmp/${session}.log"
            [[ -f "$log_file" ]] && rm "$log_file"
        fi
    done
    
    if [[ $killed_count -eq ${#tunnel_sessions[@]} ]]; then
        gum style --foreground 86 "✅ Successfully cleaned all $killed_count tunnel sessions"
    else
        gum style --foreground 214 "⚠️  Cleaned $killed_count of ${#tunnel_sessions[@]} tunnel sessions"
    fi
}

# Find bastion instance with Bastion=true tag
_cde_find_bastion_instance() {
    local profile="$1"
    local env_key="aws:${profile}"
    
    # Get cached SSM instances for current environment
    local cache_key="ssm_instances:${env_key}"
    local cached_data=$(skate get "${cache_key}@__mlnj_cde" 2>/dev/null)
    
    if [[ -z "$cached_data" ]]; then
        gum style --foreground 214 "⚠️  No cached SSM instances found. Running 'cde.ssm refresh'..." >&2
        
        # Load SSM command if not already loaded
        if ! declare -f _cde_ssm >/dev/null; then
            local cde_dir=$(__mlnj_cde_get_dir)
            local ssm_command="$cde_dir/ssm/command.zsh"
            if [[ -f "$ssm_command" ]]; then
                source "$ssm_command"
            else
                gum style --foreground 196 "❌ SSM command not found" >&2
                return 1
            fi
        fi
        
        # Run refresh
        if ! _cde_ssm refresh >&2; then
            gum style --foreground 196 "❌ Failed to refresh SSM instances" >&2
            return 1
        fi
        
        # Try to get cached data again
        cached_data=$(skate get "${cache_key}@__mlnj_cde" 2>/dev/null)
        
        if [[ -z "$cached_data" ]]; then
            gum style --foreground 196 "❌ Failed to cache SSM instances" >&2
            return 1
        fi
    fi
    
    # Parse cached JSON data to find bastion instance
    local bastion_id=""
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Check if bastion tag is true using jq
            local is_bastion=$(echo "$line" | jq -r '.bastion // "false"')
            if [[ "$is_bastion" == "true" ]]; then
                bastion_id=$(echo "$line" | jq -r '.instanceId')
                break
            fi
        fi
    done <<< "$cached_data"
    
    echo "$bastion_id"
}

# Help function for bastion command
_cde_bastion_help() {
    gum style \
        --foreground 86 --border-foreground 86 --border double \
        --align center --width 60 --margin "1 2" --padding "2 4" \
        'CDE Bastion Tunnel' 'Secure port forwarding through bastion hosts'

    echo ""
    echo "Usage:"
    echo "  cde.tun                  - Interactive tunnel management"
    echo "  cde.tun clean            - Stop all active tunnel sessions"
    echo "  cde.tun help             - Show this help"
    echo ""
    echo "Features:"
    echo "  • Select from configured bastion targets"
    echo "  • Real-time tunnel status display"
    echo "  • Background tmux sessions for persistence"
    echo "  • View logs and manage connections"
    echo "  • Auto-discovery of bastion instances"
    echo ""
    echo "Configuration: ~/.cde/config.yml"
    echo "Documentation: See docs/bastion.md"
}