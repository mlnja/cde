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

# Get AWS account ID and region from current AWS profile
__mlnj_cde_cr_get_aws_account_info() {
    gum style --foreground 214 "🔍 Getting AWS account information..." >&2
    
    # Get account ID
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [[ -z "$account_id" || "$account_id" == "None" ]]; then
        gum style --foreground 196 "❌ Failed to get AWS account ID. Check your AWS credentials." >&2
        return 1
    fi
    
    # Get region (prefer AWS_REGION, fallback to AWS_DEFAULT_REGION, then aws configure)
    local region="${AWS_REGION:-${AWS_DEFAULT_REGION}}"
    if [[ -z "$region" ]]; then
        region=$(aws configure get region --profile "$AWS_PROFILE" 2>/dev/null)
    fi
    if [[ -z "$region" ]]; then
        gum style --foreground 196 "❌ No AWS region configured. Set AWS_REGION or configure default region." >&2
        return 1
    fi
    
    echo "$account_id $region"
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
        echo "Available commands:"
        echo "  cde.cr login [region]  - Login to ECR Docker registry"
        return 1
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
            return 1
            ;;
    esac
}