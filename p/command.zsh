# Profile Command - CDE
# Unified cloud profile selection functionality

# Load cloud provider modules for p command
__mlnj_cde_p_load_providers() {
    # Use the stored CDE directory from main script
    local cde_dir="$__MLNJ_CDE_DIR"
    
    local providers_dir="$cde_dir/p/providers"
    
    if [[ -d "$providers_dir" ]]; then
        for provider_file in "$providers_dir"/*.zsh; do
            if [[ -f "$provider_file" ]]; then
                source "$provider_file"
            fi
        done
    fi
}

# Clean all cloud provider environment variables
__mlnj_cde_clean_all_profiles() {
    # AWS variables
    unset AWS_PROFILE
    unset AWS_DEFAULT_PROFILE
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    unset AWS_REGION
    unset AWS_DEFAULT_REGION
    
    # GCP variables
    unset GOOGLE_APPLICATION_CREDENTIALS
    unset GCLOUD_PROJECT
    unset GOOGLE_CLOUD_PROJECT
    
    # Azure variables
    unset AZURE_SUBSCRIPTION_ID
    unset AZURE_TENANT_ID
    unset AZURE_CLIENT_ID
    unset AZURE_CLIENT_SECRET
}

# Unified profile selection
__mlnj_cde_profile_unified() {
    local all_profiles=()
    
    # Collect profiles from all providers
    if declare -f __mlnj_cde_aws_list_profiles >/dev/null; then
        local aws_profiles=$(__mlnj_cde_aws_list_profiles 2>/dev/null)
        if [[ -n "$aws_profiles" ]]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && all_profiles+=("$line")
            done <<< "$aws_profiles"
        fi
    fi
    
    if declare -f __mlnj_cde_gcp_list_profiles >/dev/null; then
        local gcp_profiles=$(__mlnj_cde_gcp_list_profiles 2>/dev/null)
        if [[ -n "$gcp_profiles" ]]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && all_profiles+=("$line")
            done <<< "$gcp_profiles"
        fi
    fi
    
    if declare -f __mlnj_cde_azure_list_profiles >/dev/null; then
        local azure_profiles=$(__mlnj_cde_azure_list_profiles 2>/dev/null)
        if [[ -n "$azure_profiles" ]]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && all_profiles+=("$line")
            done <<< "$azure_profiles"
        fi
    fi
    
    if [[ ${#all_profiles[@]} -eq 0 ]]; then
        gum style --foreground 196 "❌ No cloud profiles found"
        return 1
    fi
    
    # Show unified selection with fuzzy filter
    gum style --foreground 86 "🌥️  Select Cloud Profile:"
    local selected=$(printf '%s\n' "${all_profiles[@]}" | gum filter --placeholder="Type to filter profiles..." --height=15)
    
    if [[ -n "$selected" ]]; then
        # Parse selection (format: "icon provider:profile")
        local provider=$(echo "$selected" | sed 's/^[^ ]* \([^:]*\):.*/\1/')
        local profile=$(echo "$selected" | sed 's/^[^ ]* [^:]*:\(.*\)/\1/')
        
        # Call appropriate provider function
        case "$provider" in
            "aws")
                __mlnj_cde_aws_set_profile "$profile"
                ;;
            "gcp")
                __mlnj_cde_gcp_set_profile "$profile"
                ;;
            "azure")
                __mlnj_cde_azure_set_profile "$profile"
                ;;
            *)
                gum style --foreground 196 "❌ Unknown provider: $provider"
                ;;
        esac
    else
        # No profile selected (includes Ctrl+C) - clean all profiles
        gum style --foreground 214 "⚠️  No profile selected - cleaning all profiles"
        __mlnj_cde_clean_all_profiles
    fi
}

# Profile management function (public interface)
__mlnj_cde_profile() {
    # Always show unified selection
    __mlnj_cde_profile_unified
}

# Load providers for p command
__mlnj_cde_p_load_providers