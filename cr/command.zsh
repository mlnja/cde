# Container Registry Command - CDE
# Multi-cloud container registry login functionality

# Check if any cloud profile is set
__mlnj_cde_cr_check_profile() {
    if [[ -n "${AWS_PROFILE}" ]]; then
        echo "aws"
        return 0
    elif [[ -n "${GOOGLE_CLOUD_PROJECT}" || -n "${GCLOUD_PROJECT}" ]]; then
        echo "gcp"
        return 0
    elif [[ -n "${AZURE_SUBSCRIPTION_ID}" ]]; then
        echo "azure"
        return 0
    else
        gum style --foreground 196 "❌ No cloud profile set. Use 'cde.p' to select a profile first."
        return 1
    fi
}

# Get AWS account ID and region from cache (set by profile selection)
__mlnj_cde_cr_get_aws_account_info() {
    local silent="$1"
    
    # Create cache key based on AWS profile
    local cache_key="aws_account_info:${AWS_PROFILE:-default}"
    
    # Get cached info (populated when profile is selected)
    local cached_info=$(skate get "${cache_key}@__mlnj_cde" 2>/dev/null)
    if [[ -n "$cached_info" ]]; then
        echo "$cached_info"
        return 0
    fi
    
    # No cached info - user needs to select profile first
    if [[ "$silent" != "silent" ]]; then
        gum style --foreground 196 "❌ No cached AWS account information. Run 'cde.p' to select a profile first." >&2
    fi
    return 1
}

# Container registry login function
__mlnj_cde_cr_login() {
    local custom_region="$1"
    
    gum style --foreground 86 "🐳 Container Registry Login"
    
    # Check which cloud provider is active
    local provider=$(__mlnj_cde_cr_check_profile)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    case "$provider" in
        "aws")
            __mlnj_cde_cr_login_aws "$custom_region"
            ;;
        "gcp")
            gum style --foreground 214 "🌍 GCP container registry login not yet implemented"
            return 1
            ;;
        "azure")
            gum style --foreground 214 "🌍 Azure container registry login not yet implemented"
            return 1
            ;;
        *)
            gum style --foreground 196 "❌ Unknown provider: $provider"
            return 1
            ;;
    esac
}

# Get registry URL for current cloud provider (stdout only)
__mlnj_cde_cr_get_url() {
    local custom_region="$1"
    
    # Check which cloud provider is active
    local provider=$(__mlnj_cde_cr_check_profile 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "❌ No cloud profile set. Use 'cde.p' to select a profile first." >&2
        echo "" >&2
        echo "💡 Usage examples:" >&2
        echo "   docker build -t \$(cde.cr)/my/image:tag ." >&2
        echo "   docker build -t \$(cde.cr us-west-2)/my/image:tag ." >&2
        return 1
    fi
    
    case "$provider" in
        "aws")
            __mlnj_cde_cr_get_aws_url "$custom_region"
            ;;
        "gcp")
            echo "🌍 GCP container registry not yet implemented" >&2
            echo "" >&2
            echo "💡 Usage examples:" >&2
            echo "   docker build -t \$(cde.cr)/my/image:tag ." >&2
            return 1
            ;;
        "azure")
            echo "🌍 Azure container registry not yet implemented" >&2
            echo "" >&2
            echo "💡 Usage examples:" >&2
            echo "   docker build -t \$(cde.cr)/my/image:tag ." >&2
            return 1
            ;;
        *)
            echo "❌ Unknown provider: $provider" >&2
            return 1
            ;;
    esac
}

# Get AWS ECR URL (stdout only)
__mlnj_cde_cr_get_aws_url() {
    local custom_region="$1"
    
    # Check if running in command substitution (suppress stderr if so)
    local in_subshell=false
    if [[ "$ZSH_SUBSHELL" -gt 0 ]] || [[ "$BASH_SUBSHELL" -gt 0 ]]; then
        in_subshell=true
    fi
    
    # Get account info silently
    local account_info=$(__mlnj_cde_cr_get_aws_account_info silent)
    if [[ $? -ne 0 ]]; then
        if [[ "$in_subshell" == "false" ]]; then
            echo "❌ Failed to get AWS account information. Check your AWS credentials." >&2
            echo "" >&2
            echo "💡 Usage examples:" >&2
            echo "   docker build -t \$(cde.cr)/my/image:tag ." >&2
            echo "   docker build -t \$(cde.cr us-west-2)/my/image:tag ." >&2
        fi
        return 1
    fi
    
    local account_id=$(echo "$account_info" | cut -d' ' -f1)
    local region=$(echo "$account_info" | cut -d' ' -f2)
    
    # Use custom region if provided
    if [[ -n "$custom_region" ]]; then
        region="$custom_region"
        if [[ "$in_subshell" == "false" ]]; then
            echo "🌍 Using custom region: $region" >&2
        fi
    fi
    
    local ecr_url="${account_id}.dkr.ecr.${region}.amazonaws.com"
    
    # Output URL to stdout
    echo "$ecr_url"
    
    # Output helpful information to stderr only if not in subshell
    if [[ "$in_subshell" == "false" ]]; then
        echo "" >&2
        echo "💡 Usage examples:" >&2
        echo "   docker build -t \$(cde.cr)/my/image:tag ." >&2
        echo "   docker push \$(cde.cr)/my/image:tag" >&2
        echo "   docker build -t \$(cde.cr us-west-2)/my/image:tag ." >&2
        echo "" >&2
        echo "🔐 To login to this registry, run:" >&2
        echo "   cde.cr login" >&2
        if [[ -n "$custom_region" ]]; then
            echo "   cde.cr login $custom_region" >&2
        fi
    fi
}

# AWS ECR login function
__mlnj_cde_cr_login_aws() {
    local custom_region="$1"
    
    # Get account info
    local account_info=$(__mlnj_cde_cr_get_aws_account_info)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local account_id=$(echo "$account_info" | cut -d' ' -f1)
    local region=$(echo "$account_info" | cut -d' ' -f2)
    
    # Use custom region if provided
    if [[ -n "$custom_region" ]]; then
        region="$custom_region"
        gum style --foreground 214 "🌍 Using custom region: $region"
    fi
    
    local ecr_url="${account_id}.dkr.ecr.${region}.amazonaws.com"
    
    gum style --foreground 214 "🔐 Logging into ECR registry: $ecr_url"
    
    # Perform ECR login
    if aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$ecr_url"; then
        gum style --foreground 86 "✅ Successfully logged into ECR registry: $ecr_url"
    else
        gum style --foreground 196 "❌ Failed to login to ECR registry"
        return 1
    fi
}

# Main CR command function (public interface)
_cde_cr() {
    local subcommand="$1"
    
    if [[ -z "$subcommand" ]]; then
        # No arguments - output registry URL to stdout
        __mlnj_cde_cr_get_url
        return $?
    fi
    
    # Check if first argument looks like a region (no subcommand)
    if [[ "$subcommand" =~ ^[a-z]{2}-[a-z]+-[0-9]+$ ]]; then
        # First argument is a region, output URL with custom region
        __mlnj_cde_cr_get_url "$subcommand"
        return $?
    fi
    
    shift
    
    case "$subcommand" in
        "login")
            __mlnj_cde_cr_login "$@"
            ;;
        *)
            gum style --foreground 196 "❌ Unknown cr subcommand: $subcommand"
            echo "Available commands:"
            echo "  cde.cr login [region]  - Login to ECR Docker registry"
            echo "  cde.cr [region]        - Get registry URL"
            return 1
            ;;
    esac
}