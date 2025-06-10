# CDE - Cloud DevEx Oh My Zsh Plugin
# A collection of cloud utilities with beautiful UI

# Check if dependencies are available
if ! command -v gum >/dev/null 2>&1; then
    echo "⚠️  gum not found. Install with: go install github.com/charmbracelet/gum@latest"
fi

if ! command -v skate >/dev/null 2>&1; then
    echo "⚠️  skate not found. Install with: go install github.com/charmbracelet/skate@latest"
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "⚠️  yq not found. Install with: go install github.com/mikefarah/yq/v4@latest"
fi

# Store plugin directory when plugin loads
if [[ -n "${(%):-%N}" ]]; then
    # Get directory of current script file during load
    __MLNJ_CDE_PLUGIN_DIR="$(dirname "${(%):-%N}")"
elif [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde" ]]; then
    # Fallback to oh-my-zsh directory
    __MLNJ_CDE_PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde"
else
    # Last resort - current directory
    __MLNJ_CDE_PLUGIN_DIR="."
fi

# Get plugin directory helper
__mlnj_cde_get_plugin_dir() {
    echo "$__MLNJ_CDE_PLUGIN_DIR"
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

# Lazy load cache command when needed
__mlnj_cde_load_cache_command() {
    local plugin_dir=$(__mlnj_cde_get_plugin_dir)
    local cache_command="$plugin_dir/cache/command.zsh"
    
    if [[ -f "$cache_command" ]]; then
        source "$cache_command"
        return 0
    else
        gum style --foreground 196 "❌ Cache command not found"
        return 1
    fi
}

# Lazy load bastion command when needed
__mlnj_cde_load_bastion_command() {
    local plugin_dir=$(__mlnj_cde_get_plugin_dir)
    local bastion_command="$plugin_dir/bastion/command.zsh"
    
    if [[ -f "$bastion_command" ]]; then
        source "$bastion_command"
        return 0
    else
        gum style --foreground 196 "❌ Bastion command not found"
        return 1
    fi
}

# Lazy load cr command when needed
__mlnj_cde_load_cr_command() {
    local plugin_dir=$(__mlnj_cde_get_plugin_dir)
    local cr_command="$plugin_dir/cr/command.zsh"
    
    if [[ -f "$cr_command" ]]; then
        source "$cr_command"
        return 0
    else
        gum style --foreground 196 "❌ CR command not found"
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
            # Lazy load cache command if not already loaded
            if ! declare -f _cde_cache >/dev/null; then
                __mlnj_cde_load_cache_command || return 1
            fi
            _cde_cache "$@"
            ;;
        "cache.clean")
            # Lazy load cache command if not already loaded
            if ! declare -f _cde_cache_clean >/dev/null; then
                __mlnj_cde_load_cache_command || return 1
            fi
            _cde_cache_clean
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
    echo "  cde cache                - Show all cached data"
    echo "  cde cache.clean          - Clean all cached data"
    echo "  cde update               - Update CDE plugin"
    echo "  cde help                 - Show this help"
    echo ""
    echo "Standalone commands:"
    echo "  cde.p                    - Select cloud profile"
    echo "  cde.ssm [refresh|show]   - Connect to cloud instances"
    echo "  cde.tun                  - Connect via bastion tunnel"
    echo "  cde.cr login [region]    - Login to ECR Docker registry"
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
    
    # Capture git pull output
    local git_output=$(git pull origin main 2>&1)
    local git_exit_code=$?
    
    if [[ $git_exit_code -eq 0 ]]; then
        # Success - check if there were updates or already up to date
        if echo "$git_output" | grep -q "Already up to date"; then
            gum style --foreground 86 "✅ CDE plugin is already up to date!"
        else
            # Show only the commit range line if there were updates
            local commit_range=$(echo "$git_output" | grep -E '[a-f0-9]{7,}\.\.[a-f0-9]{7,}.*->.*origin/main')
            if [[ -n "$commit_range" ]]; then
                echo "$commit_range"
            fi
            gum style --foreground 86 "✅ CDE plugin updated successfully!"
            gum style --foreground 214 "🔄 Reload your shell: source ~/.zshrc"
        fi
    else
        # Error - show full output
        echo "$git_output"
        gum style --foreground 196 "❌ Failed to update CDE plugin"
        return 1
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

# Lazy loading alias for cde.tun
cde.tun() {
    # Lazy load bastion command if not already loaded
    if ! declare -f _cde_bastion >/dev/null; then
        __mlnj_cde_load_bastion_command || return 1
    fi
    _cde_bastion "$@"
}

# Lazy loading alias for cde.cr
cde.cr() {
    # Lazy load cr command if not already loaded
    if ! declare -f _cde_cr >/dev/null; then
        __mlnj_cde_load_cr_command || return 1
    fi
    _cde_cr "$@"
}