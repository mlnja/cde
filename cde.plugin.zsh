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
        echo "📦 Cached items:"
        skate list --db="__mlnj_cde"
        return
    fi

    if [[ $# -eq 1 ]]; then
        # Get value
        local value=$(skate get --db="__mlnj_cde" "$1" 2>/dev/null)
        if [[ -n "$value" ]]; then
            gum style --foreground 86 "🔑 $1: $value"
        else
            gum style --foreground 196 "❌ Key '$1' not found"
        fi
        return
    fi

    if [[ $# -eq 2 ]]; then
        # Set value
        skate set --db="__mlnj_cde" "$1" "$2"
        gum style --foreground 86 "✅ Cached: $1 = $2"
        return
    fi

    echo "Usage: cde cache [key] [value]"
}

# Clean all cache data
__mlnj_cde_cache_clean() {
    gum style --foreground 214 "🧹 Cleaning all CDE cache data..."
    
    # List current items for confirmation
    local cache_items=$(skate list --db="__mlnj_cde" 2>/dev/null)
    
    if [[ -z "$cache_items" ]]; then
        gum style --foreground 86 "✅ Cache is already empty"
        return 0
    fi
    
    echo "Current cached items:"
    echo "$cache_items"
    echo ""
    
    # Ask for confirmation
    if gum confirm "Delete all cached data?"; then
        # Delete the entire database
        skate reset --db="__mlnj_cde"
        gum style --foreground 86 "✅ All CDE cache data cleaned"
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