# AWS Provider for CDE
# AWS profile management functions

# Get AWS profiles for unified listing
__mlnj_cde_aws_list_profiles() {
    local aws_config="$HOME/.aws/config"
    
    if [[ ! -f "$aws_config" ]]; then
        return 1
    fi
    
    # Extract AWS profiles and format with icon
    sed -n "s/\[profile \(.*\)\]/🟠 aws:\1/gp" "$aws_config"
}

# Check if AWS credentials are valid and login if needed
__mlnj_cde_aws_ensure_auth() {
    if [[ -z "${AWS_PROFILE}" ]]; then
        return 1
    fi
    
    gum style --foreground 214 "🔍 Checking AWS authentication..."
    
    # Quick auth check and cache account info
    local caller_info=$(aws sts get-caller-identity --output text 2>/dev/null)
    if [[ $? -eq 0 && -n "$caller_info" ]]; then
        gum style --foreground 86 "✅ AWS authentication valid"
        
        # Cache account info for other commands to use
        local account_id=$(echo "$caller_info" | awk '{print $1}')
        if [[ -n "$account_id" ]]; then
            local region="${AWS_REGION:-${AWS_DEFAULT_REGION}}"
            if [[ -z "$region" ]]; then
                region=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null)
            fi
            if [[ -n "$region" ]]; then
                local cache_key="aws_account_info:${AWS_PROFILE}"
                skate set "${cache_key}@__mlnj_cde" "$account_id $region" 2>/dev/null
            fi
        fi
        
        return 0
    fi
    
    # Check if this is an SSO profile
    local aws_config="$HOME/.aws/config"
    if [[ -f "$aws_config" ]] && grep -q "sso_start_url\|sso_session" "$aws_config"; then
        gum style --foreground 214 "🔐 Logging in to AWS SSO..."
        aws sso login --profile "$AWS_PROFILE"
    else
        gum style --foreground 196 "❌ AWS credentials invalid. Please check your configuration."
        return 1
    fi
    
    # Verify auth worked and cache account info
    local caller_info=$(aws sts get-caller-identity --output text 2>/dev/null)
    if [[ $? -eq 0 && -n "$caller_info" ]]; then
        gum style --foreground 86 "✅ AWS authentication successful"
        
        # Cache account info for other commands to use
        local account_id=$(echo "$caller_info" | awk '{print $1}')
        if [[ -n "$account_id" ]]; then
            local region="${AWS_REGION:-${AWS_DEFAULT_REGION}}"
            if [[ -z "$region" ]]; then
                region=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null)
            fi
            if [[ -n "$region" ]]; then
                local cache_key="aws_account_info:${AWS_PROFILE}"
                skate set "${cache_key}@__mlnj_cde" "$account_id $region" 2>/dev/null
            fi
        fi
        
        return 0
    else
        gum style --foreground 196 "❌ AWS authentication failed"
        return 1
    fi
}

# Set AWS profile and clean other providers
__mlnj_cde_aws_set_profile() {
    local profile="$1"
    
    # Clean all cloud provider variables
    __mlnj_cde_clean_all_profiles
    
    # Set AWS profile
    export AWS_PROFILE="$profile"
    gum style --foreground 86 "✅ AWS_PROFILE set to: $profile"
    
    # Ensure authentication
    __mlnj_cde_aws_ensure_auth
}

# AWS profile selection (legacy - not used in unified interface)
__mlnj_cde_aws_profile() {
    local aws_config="$HOME/.aws/config"
    
    if [[ ! -f "$aws_config" ]]; then
        gum style --foreground 196 "❌ AWS config file not found at $aws_config"
        return 1
    fi
    
    # Extract AWS profiles
    local profiles=($(sed -n "s/\[profile \(.*\)\]/\1/gp" "$aws_config"))
    
    if [[ ${#profiles[@]} -eq 0 ]]; then
        gum style --foreground 196 "❌ No AWS profiles found in $aws_config"
        return 1
    fi
    
    # Use gum to select profile
    gum style --foreground 86 "🔍 Select AWS Profile:"
    local selected_profile=$(printf '%s\n' "${profiles[@]}" | gum choose --height=10 --cursor="→ ")
    
    if [[ -n "$selected_profile" ]]; then
        export AWS_PROFILE="$selected_profile"
        gum style --foreground 86 "✅ AWS_PROFILE set to: $selected_profile"
        
        # Call SSO login if function exists
        if declare -f __mlnj_sso_login_if_needed >/dev/null; then
            __mlnj_sso_login_if_needed
        fi
    else
        gum style --foreground 214 "⚠️  No profile selected"
    fi
}
