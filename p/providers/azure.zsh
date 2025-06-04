# Azure Provider for CDE
# Microsoft Azure profile management functions

# Get Azure profiles for unified listing
__mlnj_cde_azure_list_profiles() {
    if ! command -v az >/dev/null 2>&1; then
        return 1
    fi
    
    # Get Azure subscriptions and format with icon
    az account list --query "[].name" -o tsv 2>/dev/null | sed 's/^/🔷 azure:/'
}

# Check if Azure credentials are valid and login if needed
__mlnj_cde_azure_ensure_auth() {
    if ! command -v az >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Azure CLI not found"
        return 1
    fi
    
    gum style --foreground 214 "🔍 Checking Azure authentication..."
    
    # Quick auth check - try to get current account
    if az account show >/dev/null 2>&1; then
        gum style --foreground 86 "✅ Azure authentication valid"
        return 0
    fi
    
    gum style --foreground 214 "🔐 Logging in to Azure..."
    az login
    
    # Verify auth worked
    if az account show >/dev/null 2>&1; then
        gum style --foreground 86 "✅ Azure authentication successful"
        return 0
    else
        gum style --foreground 196 "❌ Azure authentication failed"
        return 1
    fi
}

# Set Azure profile and clean other providers
__mlnj_cde_azure_set_profile() {
    local profile="$1"
    
    # Clean all cloud provider variables
    __mlnj_cde_clean_all_profiles
    
    # Set Azure subscription
    if command -v az >/dev/null 2>&1; then
        az account set --subscription "$profile" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            gum style --foreground 86 "✅ Azure subscription set to: $profile"
            # Ensure authentication
            __mlnj_cde_azure_ensure_auth
        else
            gum style --foreground 196 "❌ Failed to set Azure subscription: $profile"
        fi
    else
        gum style --foreground 196 "❌ az CLI not found"
    fi
}

# Azure profile selection (legacy - not used in unified interface)
__mlnj_cde_azure_profile() {
    gum style --foreground 214 "🚧 Azure profile selection coming soon!"
    echo ""
    echo "Features planned:"
    echo "  - az account list"
    echo "  - Switch between subscriptions"
    echo "  - Service principal management"
}

# Azure provider info
__mlnj_cde_azure_info() {
    gum style --foreground 214 "🚧 Azure info coming soon!"
}