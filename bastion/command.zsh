# CDE Bastion Tunnel Management
# Port forwarding through bastion hosts using AWS SSM

# Main bastion tunnel command
_cde_bastion() {
    local config_file="$HOME/.cde/config.yml"
    
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
    
    # Convert to array for gum choose
    local target_array=()
    while IFS= read -r target; do
        if [[ -n "$target" ]]; then
            target_array+=("$target")
        fi
    done <<< "$targets"
    
    if [[ ${#target_array[@]} -eq 0 ]]; then
        gum style --foreground 214 "⚠️  No targets available"
        return 1
    fi
    
    # Let user choose target
    local chosen_target
    if [[ ${#target_array[@]} -eq 1 ]]; then
        chosen_target="${target_array[1]}"
        gum style --foreground 86 "🎯 Using only available target: $chosen_target"
    else
        chosen_target=$(printf '%s\n' "${target_array[@]}" | gum choose --header "🚇 Select bastion target:")
    fi
    
    if [[ -z "$chosen_target" ]]; then
        gum style --foreground 214 "⚠️  No target selected"
        return 1
    fi
    
    # Get target details
    local target_host=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\" and .name == \"$chosen_target\") | .host" "$config_file")
    local target_port=$(yq eval ".bastion_targets[] | select(.profile == \"$current_profile\" and .name == \"$chosen_target\") | .port" "$config_file")
    
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
    gum style --foreground 86 "🔗 Connecting to: $chosen_target"
    gum style --foreground 214 "📡 $target_host:$remote_port -> localhost:$local_port"
    
    # Start the SSM session
    echo ""
    gum style --foreground 214 "🚀 Starting tunnel... (Press Ctrl+C to stop)"
    echo ""
    
    AWS_PROFILE="$current_profile" aws ssm start-session \
        --target "$bastion_instance" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "host=\"$target_host\",portNumber=\"$remote_port\",localPortNumber=\"$local_port\""
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