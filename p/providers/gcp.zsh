# GCP Provider for CDE
# Google Cloud Platform profile management functions

# Get GCP profiles for unified listing
__mlnj_cde_gcp_list_profiles() {
    if ! command -v gcloud >/dev/null 2>&1; then
        return 1
    fi
    
    # Get GCP configurations and format with icon
    gcloud config configurations list --format="value(name)" 2>/dev/null | sed 's/^/🔵 gcp:/'
}

# Check if GCP credentials are valid and login if needed
__mlnj_cde_gcp_ensure_auth() {
    if ! command -v gcloud >/dev/null 2>&1; then
        gum style --foreground 196 "❌ gcloud CLI not found"
        return 1
    fi
    
    gum style --foreground 214 "🔍 Checking GCP authentication..."
    
    # Quick auth check - try to get current account
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        gum style --foreground 86 "✅ GCP authentication valid"
        return 0
    fi
    
    gum style --foreground 214 "🔐 Logging in to GCP..."
    gcloud auth login
    
    # Verify auth worked
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        gum style --foreground 86 "✅ GCP authentication successful"
        return 0
    else
        gum style --foreground 196 "❌ GCP authentication failed"
        return 1
    fi
}

# Set GCP profile and clean other providers
__mlnj_cde_gcp_set_profile() {
    local profile="$1"
    
    # Clean all cloud provider variables
    __mlnj_cde_clean_all_profiles
    
    # Set GCP configuration
    if command -v gcloud >/dev/null 2>&1; then
        gcloud config configurations activate "$profile" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            gum style --foreground 86 "✅ GCP configuration set to: $profile"
            # Ensure authentication
            __mlnj_cde_gcp_ensure_auth
        else
            gum style --foreground 196 "❌ Failed to set GCP configuration: $profile"
        fi
    else
        gum style --foreground 196 "❌ gcloud not found"
    fi
}

# GCP profile selection (legacy - not used in unified interface)
__mlnj_cde_gcp_profile() {
    gum style --foreground 214 "🚧 GCP profile selection coming soon!"
    echo ""
    echo "Features planned:"
    echo "  - gcloud config configurations list"
    echo "  - Switch between GCP projects"
    echo "  - Service account management"
}

# GCP provider info
__mlnj_cde_gcp_info() {
    gum style --foreground 214 "🚧 GCP info coming soon!"
}