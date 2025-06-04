# CDE - Cloud DevEx Oh My Zsh Plugin
# A collection of cloud utilities with beautiful UI

# Check if dependencies are available
if ! command -v gum >/dev/null 2>&1; then
    echo "⚠️  gum not found. Install with: go install github.com/charmbracelet/gum@latest"
fi

if ! command -v skate >/dev/null 2>&1; then
    echo "⚠️  skate not found. Install with: go install github.com/charmbracelet/skate@latest"
fi

# Get plugin directory helper
__mlnj_cde_get_plugin_dir() {
    if [[ -n "${(%):-%N}" ]]; then
        # Get directory of current script file
        echo "$(dirname "${(%):-%N}")"
    elif [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde" ]]; then
        # Fallback to oh-my-zsh directory
        echo "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde"
    else
        # Last resort - current directory
        echo "."
    fi
}

# Lazy load p command when needed
__mlnj_cde_load_p_command() {
    local plugin_dir=$(__mlnj_cde_get_plugin_dir)
    local p_command="$plugin_dir/p/command.zsh"
    
    if [[ -f "$p_command" ]]; then
        source "$p_command"
        return 0
    else
        gum style --foreground 196 "❌ Profile command not found"
        return 1
    fi
}

# Lazy load ssm command when needed
__mlnj_cde_load_ssm_command() {
    local plugin_dir=$(__mlnj_cde_get_plugin_dir)
    local ssm_command="$plugin_dir/ssm/command.zsh"
    
    if [[ -f "$ssm_command" ]]; then
        source "$ssm_command"
        return 0
    else
        gum style --foreground 196 "❌ SSM command not found"
        return 1
    fi
}

# Main CDE function
cde() {
    if [[ $# -eq 0 ]]; then
        __mlnj_cde_help
        return
    fi

    case "$1" in
        "help"|"-h"|"--help")
            __mlnj_cde_help
            ;;
        "cache")
            shift
            __mlnj_cde_cache "$@"
            ;;
        "cache.clean")
            __mlnj_cde_cache_clean
            ;;
        "update")
            __mlnj_cde_update
            ;;
        *)
            echo "Unknown command: $1"
            __mlnj_cde_help
            ;;
    esac
}

# Help function
__mlnj_cde_help() {
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "2 4" \
        'CDE - Cloud DevEx' 'Beautiful cloud utilities'

    echo ""
    echo "Available commands:"
    echo "  cde cache [key] [value]  - Manage cached data"
    echo "  cde cache.clean          - Clean all cached data"
    echo "  cde update               - Update CDE plugin"
    echo "  cde help                 - Show this help"
    echo ""
    echo "Standalone commands:"
    echo "  cde.p                    - Select cloud profile"
    echo "  cde.ssm [refresh|show]   - Connect to cloud instances"
}

# Update function
__mlnj_cde_update() {
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde"
    
    if [[ ! -d "$plugin_dir" ]]; then
        gum style --foreground 196 "❌ CDE plugin directory not found"
        return 1
    fi
    
    if [[ ! -d "$plugin_dir/.git" ]]; then
        gum style --foreground 196 "❌ CDE plugin is not a git repository"
        return 1
    fi
    
    gum style --foreground 86 "🔄 Updating CDE plugin..."
    
    cd "$plugin_dir"
    if git pull origin main; then
        gum style --foreground 86 "✅ CDE plugin updated successfully!"
        gum style --foreground 214 "🔄 Reload your shell: source ~/.zshrc"
    else
        gum style --foreground 196 "❌ Failed to update CDE plugin"
        return 1
    fi
}

# Cache management using skate
__mlnj_cde_cache() {
    if [[ $# -eq 0 ]]; then
        # Get current environment key
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
        
        if [[ -n "$env_key" ]]; then
            echo "📦 Cached items for environment: $env_key"
            
            # Get all keys and filter for current environment
            local env_keys=$(skate list @__mlnj_cde -k | grep "^ssm_instances:${env_key}")
            local global_keys=$(skate list @__mlnj_cde -k | grep -v "^ssm_instances:")
            
            if [[ -n "$env_keys" ]]; then
                echo "Environment-specific cache:"
                echo "$env_keys"
            fi
            
            if [[ -n "$global_keys" ]]; then
                echo "Global cache:"
                echo "$global_keys"
            fi
            
            if [[ -z "$env_keys" && -z "$global_keys" ]]; then
                echo "No cache items found."
            fi
        else
            echo "📦 All cached items (no environment set):"
            skate list @__mlnj_cde -k
        fi
        return
    fi

    if [[ $# -eq 1 ]]; then
        # Get value
        local value=$(skate get "$1@__mlnj_cde" 2>/dev/null)
        if [[ -n "$value" ]]; then
            gum style --foreground 86 "🔑 $1: $value"
        else
            gum style --foreground 196 "❌ Key '$1' not found"
        fi
        return
    fi

    if [[ $# -eq 2 ]]; then
        # Set value
        skate set "$1@__mlnj_cde" "$2"
        gum style --foreground 86 "✅ Cached: $1 = $2"
        return
    fi

    echo "Usage: cde cache [key] [value]"
}

# Clean cache data for current environment
__mlnj_cde_cache_clean() {
    # Get current environment key
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
    
    if [[ -z "$env_key" ]]; then
        gum style --foreground 214 "🧹 No environment detected. Cleaning ALL cache data..."
        
        # List all current items for confirmation (keys only)
        local all_cache_items=$(skate list @__mlnj_cde -k 2>/dev/null)
        
        if [[ -z "$all_cache_items" ]]; then
            gum style --foreground 86 "✅ Cache is already empty"
            return 0
        fi
        
        echo "All cached items:"
        echo "$all_cache_items"
        echo ""
        
        # Ask for confirmation to delete everything
        if gum confirm "Delete ALL cached data?"; then
            # Delete each key individually
            while IFS= read -r key; do
                if [[ -n "$key" ]]; then
                    skate delete "${key}@__mlnj_cde" 2>/dev/null
                    echo "Deleted: $key"
                fi
            done <<< "$all_cache_items"
            gum style --foreground 86 "✅ All CDE cache data cleaned"
        else
            gum style --foreground 214 "⚠️  Cache cleaning cancelled"
        fi
        return 0
    fi
    
    gum style --foreground 214 "🧹 Cleaning cache data for environment: $env_key"
    
    # Get environment-specific cache keys
    local env_keys=$(skate list @__mlnj_cde -k | grep "^ssm_instances:${env_key}")
    
    if [[ -z "$env_keys" ]]; then
        gum style --foreground 86 "✅ No cache items found for this environment"
        return 0
    fi
    
    echo "Cache items to delete for $env_key:"
    echo "$env_keys"
    echo ""
    
    # Ask for confirmation
    if gum confirm "Delete cache for this environment?"; then
        # Delete each environment-specific key
        while IFS= read -r key; do
            if [[ -n "$key" ]]; then
                skate delete "${key}@__mlnj_cde" 2>/dev/null
                echo "Deleted: $key"
            fi
        done <<< "$env_keys"
        gum style --foreground 86 "✅ Environment cache cleaned"
    else
        gum style --foreground 214 "⚠️  Cache cleaning cancelled"
    fi
}

# Lazy loading alias for cde.p
cde.p() {
    # Lazy load p command if not already loaded
    if ! declare -f _cde_profile >/dev/null; then
        __mlnj_cde_load_p_command || return 1
    fi
    _cde_profile "$@"
}

# Lazy loading alias for cde.ssm
cde.ssm() {
    # Lazy load ssm command if not already loaded
    if ! declare -f _cde_ssm >/dev/null; then
        __mlnj_cde_load_ssm_command || return 1
    fi
    _cde_ssm "$@"
}