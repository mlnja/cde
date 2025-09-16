# CDE - Cloud DevEx Oh My Zsh Plugin
# A collection of cloud utilities with beautiful UI


# Store CDE directory when script loads
if [[ -n "${(%):-%N}" ]]; then
    # Get directory of current script file during load
    __MLNJ_CDE_DIR="$(dirname "${(%):-%N}")"
elif [[ -d "$HOME/.local/share/cde" ]]; then
    # Standard location
    __MLNJ_CDE_DIR="$HOME/.local/share/cde"
elif [[ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde" ]]; then
    # Fallback to oh-my-zsh directory for backward compatibility
    __MLNJ_CDE_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/cde"
else
    # Last resort - current directory
    __MLNJ_CDE_DIR="."
fi

# Get CDE directory helper
__mlnj_cde_get_dir() {
    echo "$__MLNJ_CDE_DIR"
}

# Lazy load p command when needed
__mlnj_cde_load_p_command() {
    local cde_dir=$(__mlnj_cde_get_dir)
    local p_command="$cde_dir/p/command.zsh"
    
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
    local cde_dir=$(__mlnj_cde_get_dir)
    local ssm_command="$cde_dir/ssm/command.zsh"
    
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
    local cde_dir=$(__mlnj_cde_get_dir)
    local cache_command="$cde_dir/cache/command.zsh"
    
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
    local cde_dir=$(__mlnj_cde_get_dir)
    local bastion_command="$cde_dir/bastion/command.zsh"
    
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
    local cde_dir=$(__mlnj_cde_get_dir)
    local cr_command="$cde_dir/cr/command.zsh"

    if [[ -f "$cr_command" ]]; then
        source "$cr_command"
        return 0
    else
        gum style --foreground 196 "❌ CR command not found"
        return 1
    fi
}

# Lazy load k8x command when needed
__mlnj_cde_load_k8x_command() {
    local cde_dir=$(__mlnj_cde_get_dir)
    local k8x_command="$cde_dir/k8x/command.zsh"

    if [[ -f "$k8x_command" ]]; then
        source "$k8x_command"
        return 0
    else
        gum style --foreground 196 "❌ K8X command not found"
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
            if ! declare -f __mlnj_cde_cache >/dev/null; then
                __mlnj_cde_load_cache_command || return 1
            fi
            __mlnj_cde_cache "$@"
            ;;
        "cache.clean")
            # Lazy load cache command if not already loaded
            if ! declare -f __mlnj_cde_cache_clean >/dev/null; then
                __mlnj_cde_load_cache_command || return 1
            fi
            __mlnj_cde_cache_clean
            ;;
        "update")
            __mlnj_cde_update
            ;;
        "doctor")
            __mlnj_cde_doctor
            ;;
        *)
            echo "Unknown command: $1"
            __mlnj_cde_help
            ;;
    esac
}

# Doctor function to check dependencies
__mlnj_cde_doctor() {
    echo "🩺 CDE Doctor - Checking dependencies..."
    echo ""
    
    local all_good=true
    
    # Check gum
    if command -v gum >/dev/null 2>&1; then
        echo "✅ gum: $(gum --version | head -n1)"
    else
        echo "❌ gum: not found"
        echo "   Install with: go install github.com/charmbracelet/gum@latest"
        all_good=false
    fi
    
    # Check skate
    if command -v skate >/dev/null 2>&1; then
        echo "✅ skate: $(skate --version 2>/dev/null || echo "installed")"
    else
        echo "❌ skate: not found"
        echo "   Install with: go install github.com/charmbracelet/skate@latest"
        all_good=false
    fi
    
    # Check yq
    if command -v yq >/dev/null 2>&1; then
        echo "✅ yq: $(yq --version | head -n1)"
    else
        echo "❌ yq: not found"
        echo "   Install with: go install github.com/mikefarah/yq/v4@latest"
        all_good=false
    fi
    
    # Check tmux
    if command -v tmux >/dev/null 2>&1; then
        echo "✅ tmux: $(tmux -V)"
    else
        echo "❌ tmux: not found"
        echo "   Install with: brew install tmux (macOS) or apt install tmux (Linux)"
        all_good=false
    fi
    
    # Check AWS CLI
    if command -v aws >/dev/null 2>&1; then
        echo "✅ aws: $(aws --version | head -n1)"
    else
        echo "⚠️  aws: not found (optional for AWS features)"
        echo "   Install with: https://aws.amazon.com/cli/"
    fi
    
    # Check gcloud CLI
    if command -v gcloud >/dev/null 2>&1; then
        echo "✅ gcloud: $(gcloud version --format="value(Google Cloud SDK)" 2>/dev/null | head -n1)"
    else
        echo "⚠️  gcloud: not found (optional for GCP features)"
        echo "   Install with: https://cloud.google.com/sdk/docs/install"
    fi
    
    # Check az CLI
    if command -v az >/dev/null 2>&1; then
        echo "✅ az: $(az version --output tsv --query '"azure-cli"' 2>/dev/null)"
    else
        echo "⚠️  az: not found (optional for Azure features)"
        echo "   Install with: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    fi
    
    echo ""
    if [[ $all_good == true ]]; then
        echo "🎉 All required dependencies are installed!"
    else
        echo "⚠️  Some required dependencies are missing. Please install them to use all CDE features."
    fi
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
    echo "  cde doctor               - Check dependencies"
    echo "  cde update               - Update CDE plugin"
    echo "  cde help                 - Show this help"
    echo ""
    echo "Standalone commands:"
    echo "  cde.p                    - Select cloud profile"
    echo "  cde.ssm [refresh|show]   - Connect to cloud instances"
    echo "  cde.tun [clean]          - Connect via bastion tunnel"
    echo "  cde.cr login [region]    - Login to ECR Docker registry"
    echo "  cde.k8x                  - Switch kubernetes contexts"
}

# Update function
__mlnj_cde_update() {
    local cde_dir=$(__mlnj_cde_get_dir)
    
    if [[ ! -d "$cde_dir" ]]; then
        gum style --foreground 196 "❌ CDE directory not found: $cde_dir"
        return 1
    fi
    
    if [[ ! -d "$cde_dir/.git" ]]; then
        gum style --foreground 196 "❌ CDE directory is not a git repository"
        return 1
    fi
    
    gum style --foreground 86 "🔄 Updating CDE..."

    cd "$cde_dir"

    # Clean any uncommitted changes and untracked files
    gum style --foreground 214 "🧹 Cleaning local changes..."
    git reset --hard HEAD 2>/dev/null
    git clean -fd 2>/dev/null

    # Fetch latest changes
    git fetch origin main 2>/dev/null

    # Capture git pull output
    local git_output=$(git pull origin main 2>&1)
    local git_exit_code=$?
    
    if [[ $git_exit_code -eq 0 ]]; then
        # Success - check if there were updates or already up to date
        if [[ "$git_output" == *"Already up to date"* ]]; then
            gum style --foreground 86 "✅ CDE is already up to date!"
        else
            # Show only the commit range line if there were updates
            local commit_range=$(echo "$git_output" | grep -E '[a-f0-9]{7,}\.\.[a-f0-9]{7,}.*->.*origin/main')
            if [[ -n "$commit_range" ]]; then
                echo "$commit_range"
            fi
            gum style --foreground 86 "✅ CDE updated successfully!"
            gum style --foreground 214 "🔄 Reload your shell: source ~/.zshrc"
        fi
    else
        # Error - show full output
        echo "$git_output"
        gum style --foreground 196 "❌ Failed to update CDE"
        return 1
    fi
}


# Lazy loading alias for cde.p
cde.p() {
    # Lazy load p command if not already loaded
    if ! declare -f __mlnj_cde_profile >/dev/null; then
        __mlnj_cde_load_p_command || return 1
    fi
    __mlnj_cde_profile "$@"
}

# Lazy loading alias for cde.ssm
cde.ssm() {
    # Lazy load ssm command if not already loaded
    if ! declare -f __mlnj_cde_ssm >/dev/null; then
        __mlnj_cde_load_ssm_command || return 1
    fi
    __mlnj_cde_ssm "$@"
}

# Lazy loading alias for cde.tun
cde.tun() {
    # Lazy load bastion command if not already loaded
    if ! declare -f __mlnj_cde_bastion >/dev/null; then
        __mlnj_cde_load_bastion_command || return 1
    fi
    __mlnj_cde_bastion "$@"
}

# Lazy loading alias for cde.cr
cde.cr() {
    # Lazy load cr command if not already loaded
    if ! declare -f __mlnj_cde_cr >/dev/null; then
        __mlnj_cde_load_cr_command || return 1
    fi
    __mlnj_cde_cr "$@"
}

# Lazy loading alias for cde.k8x
cde.k8x() {
    # Lazy load k8x command if not already loaded
    if ! declare -f __mlnj_cde_k8x >/dev/null; then
        __mlnj_cde_load_k8x_command || return 1
    fi
    __mlnj_cde_k8x "$@"
}