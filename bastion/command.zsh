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
    
    # Get targets for current profile using yq
    local targets=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\") | .name" "$config_file" 2>/dev/null)
    
    if [[ -z "$targets" ]]; then
        gum style --foreground 214 "⚠️  No bastion targets found for profile: $current_profile"
        echo "Available profiles in config:"
        yq eval '.bastion_targets[].profile' "$config_file" 2>/dev/null | sort -u
        return 1
    fi
    
    # Show tunnel status table
    _cde_show_tunnel_table "$current_profile" "$config_file"
}

# Show tunnel status table with tmux session info
_cde_show_tunnel_table() {
    local current_profile="$1"
    local config_file="$2"
    
    # Create display data array
    local display_lines=()
    
    # Get all targets for current profile
    while IFS= read -r target_name; do
        if [[ -n "$target_name" ]]; then
            # Get target details
            local target_host=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\" and .name == \"$target_name\") | .host" "$config_file")
            local target_port=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\" and .name == \"$target_name\") | .port" "$config_file")
            
            # Check if tmux session exists
            local session_name="__mlnj_cde_tun_${current_profile}_${target_name}"
            local status_icon="❌"
            local status_text="Stopped"
            if tmux has-session -t "$session_name" 2>/dev/null; then
                status_icon="✅"
                status_text="Running"
            fi
            
            display_lines+=("$status_icon $status_text | 🚇 $target_name")
        fi
    done <<< "$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\") | .name" "$config_file" 2>/dev/null)"
    
    if [[ ${#display_lines[@]} -eq 0 ]]; then
        return 0
    fi
    
    # Interactive selection with filter
    gum style --foreground 86 "🚇 Select tunnel ($current_profile):"
    local selected=$(printf '%s\n' "${display_lines[@]}" | gum filter --placeholder="Type to filter tunnels..." --height=10)
    
    if [[ -z "$selected" ]]; then
        return 0
    fi
    
    # Extract target name from selected line
    local chosen_target=$(echo "$selected" | cut -d'|' -f2 | sed 's/🚇 //' | xargs)
    
    if [[ -z "$chosen_target" ]]; then
        return 0
    fi
    
    # Check if tunnel is already running
    local session_name="__mlnj_cde_tun_${current_profile}_${chosen_target}"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        _cde_manage_existing_tunnel "$chosen_target" "$session_name"
    else
        _cde_start_new_tunnel "$chosen_target" "$current_profile" "$config_file"
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
    
    # Parse port (format: remote:local)
    local remote_port="${target_port%:*}"
    local local_port="${target_port#*:}"
    
    gum style --foreground 86 "🔍 Looking for bastion instance..."
    
    # Find bastion instance
    local bastion_instance=$(_cde_find_bastion_instance "$current_profile")
    
    if [[ -z "$bastion_instance" ]]; then
        gum style --foreground 196 "❌ No bastion instance found with tag Bastion=true"
        return 1
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
    
    gum style --foreground 86 "✅ Tunnel started in detached session: $session_name"
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
            local plugin_dir=$(__mlnj_cde_get_plugin_dir)
            local ssm_command="$plugin_dir/ssm/command.zsh"
            if [[ -f "$ssm_command" ]]; then
                source "$ssm_command"
            else
                gum style --foreground 196 "❌ SSM command not found" >&2
                return 1
            fi
        fi
        
        # Run refresh
        _cde_ssm refresh >&2
        
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