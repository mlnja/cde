# SSM Command - CDE
# Unified cloud instance connection functionality

# Load cloud provider modules for ssm command
__mlnj_cde_ssm_load_providers() {
    # Use the stored plugin directory from main plugin
    local plugin_dir="$__MLNJ_CDE_PLUGIN_DIR"
    
    local providers_dir="$plugin_dir/ssm/providers"
    
    if [[ -d "$providers_dir" ]]; then
        for provider_file in "$providers_dir"/*.zsh; do
            if [[ -f "$provider_file" ]]; then
                source "$provider_file"
            fi
        done
    fi
}

# Get current environment key for caching
__mlnj_cde_ssm_get_env_key() {
    local env_key=""
    
    if [[ -n "$AWS_PROFILE" ]]; then
        env_key="aws:${AWS_PROFILE}"
    elif command -v gcloud >/dev/null 2>&1; then
        local gcp_project=$(gcloud config get-value project 2>/dev/null)
        if [[ -n "$gcp_project" ]]; then
            env_key="gcp:${gcp_project}"
        fi
    elif command -v az >/dev/null 2>&1; then
        local azure_sub=$(az account show --query "name" -o tsv 2>/dev/null)
        if [[ -n "$azure_sub" ]]; then
            env_key="azure:${azure_sub}"
        fi
    fi
    
    echo "$env_key"
}

# Refresh SSM instances for current environment
__mlnj_cde_ssm_refresh() {
    local env_key=$(__mlnj_cde_ssm_get_env_key)
    
    if [[ -z "$env_key" ]]; then
        gum style --foreground 196 "❌ No cloud environment detected. Please set a profile first with cde.p"
        return 1
    fi
    
    gum style --foreground 214 "🔄 Refreshing SSM instances for environment: $env_key"
    
    local instances=()
    
    # Get instances from appropriate provider
    if [[ "$env_key" =~ ^aws: ]]; then
        if declare -f __mlnj_cde_aws_list_ssm_instances >/dev/null; then
            local aws_instances=$(__mlnj_cde_aws_list_ssm_instances 2>/dev/null)
            if [[ -n "$aws_instances" ]]; then
                while IFS= read -r line; do
                    [[ -n "$line" ]] && instances+=("$line")
                done <<< "$aws_instances"
            fi
        fi
    elif [[ "$env_key" =~ ^gcp: ]]; then
        if declare -f __mlnj_cde_gcp_list_ssm_instances >/dev/null; then
            local gcp_instances=$(__mlnj_cde_gcp_list_ssm_instances 2>/dev/null)
            if [[ -n "$gcp_instances" ]]; then
                while IFS= read -r line; do
                    [[ -n "$line" ]] && instances+=("$line")
                done <<< "$gcp_instances"
            fi
        fi
    elif [[ "$env_key" =~ ^azure: ]]; then
        if declare -f __mlnj_cde_azure_list_ssm_instances >/dev/null; then
            local azure_instances=$(__mlnj_cde_azure_list_ssm_instances 2>/dev/null)
            if [[ -n "$azure_instances" ]]; then
                while IFS= read -r line; do
                    [[ -n "$line" ]] && instances+=("$line")
                done <<< "$azure_instances"
            fi
        fi
    fi
    
    # Validate JSON data before caching
    local valid_instances=()
    local invalid_count=0
    
    for instance in "${instances[@]}"; do
        if echo "$instance" | jq empty 2>/dev/null; then
            valid_instances+=("$instance")
        else
            ((invalid_count++))
        fi
    done
    
    # Only cache if we have valid instances
    if [[ ${#valid_instances[@]} -gt 0 ]]; then
        local cache_data=$(printf '%s\n' "${valid_instances[@]}")
        skate set "ssm_instances:${env_key}@__mlnj_cde" "$cache_data"
        gum style --foreground 86 "✅ Found and cached ${#valid_instances[@]} instances"
        
        if [[ $invalid_count -gt 0 ]]; then
            gum style --foreground 214 "⚠️  Skipped $invalid_count instances with invalid JSON"
        fi
    else
        # Don't update cache if no valid instances found
        if [[ ${#instances[@]} -gt 0 ]]; then
            gum style --foreground 196 "❌ All ${#instances[@]} instances had invalid JSON format"
            gum style --foreground 214 "💡 Cache not updated - previous data preserved"
            return 1
        else
            skate delete "ssm_instances:${env_key}@__mlnj_cde" 2>/dev/null
            gum style --foreground 214 "⚠️  No SSM instances found for this environment"
        fi
    fi
}

# Get cached SSM instances for current environment
__mlnj_cde_ssm_get_cached_instances() {
    local env_key=$(__mlnj_cde_ssm_get_env_key)
    
    if [[ -z "$env_key" ]]; then
        return 1
    fi
    
    local cached_data=$(skate get "ssm_instances:${env_key}@__mlnj_cde" 2>/dev/null)
    if [[ -n "$cached_data" ]]; then
        echo "$cached_data"
        return 0
    else
        return 1
    fi
}

# Connect to SSM instance
__mlnj_cde_ssm_connect() {
    local env_key=$(__mlnj_cde_ssm_get_env_key)
    
    if [[ -z "$env_key" ]]; then
        gum style --foreground 196 "❌ No cloud environment detected. Please set a profile first with cde.p"
        return 1
    fi
    
    # Get cached instances
    local cached_instances=$(__mlnj_cde_ssm_get_cached_instances)
    
    if [[ -z "$cached_instances" ]]; then
        gum style --foreground 214 "📭 No cached instances found. Refreshing..."
        __mlnj_cde_ssm_refresh
        cached_instances=$(__mlnj_cde_ssm_get_cached_instances)
        
        if [[ -z "$cached_instances" ]]; then
            gum style --foreground 196 "❌ No SSM instances available in this environment"
            return 1
        fi
    fi
    
    # Convert cached JSON data to display format and create instances array
    local instances=()
    local json_data=()
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            json_data+=("$line")
            # Create display format using jq (filter out bastion tag for regular SSM list)
            local display_line=$(echo "$line" | jq -r '
                "💻 " + (.instanceId | . + (" " * (19 - length))) + " │ " + 
                ((.name | . + (" " * (32 - length))) | .[:32]) + " │ " + 
                ((.instanceType | . + (" " * (15 - length))) | .[:15]) + " │ " + 
                ((.privateIp | . + (" " * (15 - length))) | .[:15])
            ')
            instances+=("$display_line")
        fi
    done <<< "$cached_instances"
    
    # Show selection with fuzzy filter
    gum style --foreground 86 "🖥️  Select SSM Instance (${env_key}):"
    local selected=$(printf '%s\n' "${instances[@]}" | gum filter --placeholder="Type to filter instances..." --height=15)
    
    if [[ -n "$selected" ]]; then
        # Parse selection to get instance ID and provider
        local provider=$(echo "$env_key" | cut -d: -f1)
        # Extract instance ID from the formatted table (first column after icon)
        local instance_id=$(echo "$selected" | sed 's/^💻 \([^ ]*\) │.*/\1/' | xargs)
        
        gum style --foreground 214 "🔌 Connecting to: $instance_id"
        
        # Connect using appropriate provider
        case "$provider" in
            "aws")
                if declare -f __mlnj_cde_aws_connect_ssm >/dev/null; then
                    __mlnj_cde_aws_connect_ssm "$instance_id"
                else
                    gum style --foreground 196 "❌ AWS SSM provider not available"
                    return 1
                fi
                ;;
            "gcp")
                if declare -f __mlnj_cde_gcp_connect_ssm >/dev/null; then
                    __mlnj_cde_gcp_connect_ssm "$instance_id"
                else
                    gum style --foreground 196 "❌ GCP SSH provider not available"
                    return 1
                fi
                ;;
            "azure")
                if declare -f __mlnj_cde_azure_connect_ssm >/dev/null; then
                    __mlnj_cde_azure_connect_ssm "$instance_id"
                else
                    gum style --foreground 196 "❌ Azure SSH provider not available"
                    return 1
                fi
                ;;
            *)
                gum style --foreground 196 "❌ Unknown provider: $provider"
                return 1
                ;;
        esac
        
        # Check connection result
        if [[ $? -ne 0 ]]; then
            echo ""
            gum style --foreground 214 "💡 Connection failed. Try refreshing the instance list:"
            gum style --foreground 86 "   cde.ssm refresh"
        fi
    else
        gum style --foreground 214 "⚠️  No instance selected"
    fi
}

# Show SSM instances in a beautiful table
__mlnj_cde_ssm_show() {
    local env_key=$(__mlnj_cde_ssm_get_env_key)
    
    if [[ -z "$env_key" ]]; then
        gum style --foreground 196 "❌ No cloud environment detected. Please set a profile first with cde.p"
        return 1
    fi
    
    # Get cached instances
    local cached_instances=$(__mlnj_cde_ssm_get_cached_instances)
    
    if [[ -z "$cached_instances" ]]; then
        gum style --foreground 214 "📭 No cached instances found. Run 'cde.ssm refresh' first."
        return 1
    fi
    
    # Convert cached JSON data to display format for table
    local instances=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Create display format using jq (filter out bastion tag for regular SSM list)
            local display_line=$(echo "$line" | jq -r '
                "💻 " + (.instanceId | . + (" " * (19 - length))) + " │ " + 
                ((.name | . + (" " * (32 - length))) | .[:32]) + " │ " + 
                ((.instanceType | . + (" " * (15 - length))) | .[:15]) + " │ " + 
                ((.privateIp | . + (" " * (15 - length))) | .[:15])
            ')
            instances+=("$display_line")
        fi
    done <<< "$cached_instances"
    
    if [[ ${#instances[@]} -eq 0 ]]; then
        gum style --foreground 214 "📭 No instances available in this environment"
        return 1
    fi
    
    # Display custom fancy table
    local provider=$(echo "$env_key" | cut -d: -f1)
    
    # Header with title
    gum style --foreground 86 --bold "🖥️  Cloud Instances - ${env_key}"
    echo ""
    
    # Create fancy border and header
    case "$provider" in
        "aws")
            echo "┌─────────────────────┬──────────────────────────────────┬─────────────────┬─────────────────┐"
            gum style --foreground 214 --bold "│ Instance ID         │ Name                             │ Type            │ Private IP      │"
            echo "├─────────────────────┼──────────────────────────────────┼─────────────────┼─────────────────┤"
            ;;
        "gcp")
            echo "┌─────────────────────┬──────────────────────────────────┬─────────────────┬─────────────────┬─────────────────┐"
            gum style --foreground 214 --bold "│ Instance Name       │ Display Name                     │ Type            │ Zone            │ Private IP      │"
            echo "├─────────────────────┼──────────────────────────────────┼─────────────────┼─────────────────┼─────────────────┤"
            ;;
        "azure")
            echo "┌─────────────────────┬──────────────────────────────────┬─────────────────┬─────────────────┬─────────────────┐"
            gum style --foreground 214 --bold "│ VM Name             │ Display Name                     │ Size            │ Resource Group  │ Private IP      │"
            echo "├─────────────────────┼──────────────────────────────────┼─────────────────┼─────────────────┼─────────────────┤"
            ;;
    esac
    
    # Display data rows
    for instance in "${instances[@]}"; do
        # Remove icon and add border characters
        local row=$(echo "$instance" | sed 's/💻 /│ /' | sed 's/ │ / │ /g')
        echo "${row} │"
    done
    
    # Bottom border
    case "$provider" in
        "aws")
            echo "└─────────────────────┴──────────────────────────────────┴─────────────────┴─────────────────┘"
            ;;
        "gcp"|"azure")
            echo "└─────────────────────┴──────────────────────────────────┴─────────────────┴─────────────────┴─────────────────┘"
            ;;
    esac
    
    echo ""
    gum style --foreground 86 "Found ${#instances[@]} instances"
}

# SSM management function (public interface)
_cde_ssm() {
    local action="${1:-connect}"
    
    case "$action" in
        "refresh")
            __mlnj_cde_ssm_refresh
            ;;
        "show")
            __mlnj_cde_ssm_show
            ;;
        "connect"|"")
            __mlnj_cde_ssm_connect
            ;;
        *)
            gum style --foreground 196 "❌ Unknown action: $action"
            echo "Available actions:"
            echo "  cde.ssm          - Connect to instance"
            echo "  cde.ssm refresh  - Refresh instance list"
            echo "  cde.ssm show     - Show instances table"
            ;;
    esac
}

# Load providers for ssm command
__mlnj_cde_ssm_load_providers