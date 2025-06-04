# AWS SSM Provider for CDE
# AWS EC2 instance connection via Session Manager

# List AWS EC2 instances available for SSM
__mlnj_cde_aws_list_ssm_instances() {
    if [[ -z "$AWS_PROFILE" ]]; then
        return 1
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if authenticated
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        gum style --foreground 196 "❌ AWS authentication required. Please run cde.p first."
        return 1
    fi
    
    # Get instances that are running and have SSM agent (no output during collection)
    local instances=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],InstanceType,PrivateIpAddress]' \
        --output text 2>/dev/null)
    
    if [[ -z "$instances" ]]; then
        return 1
    fi
    
    # Check which instances have SSM connectivity
    local ssm_instances=()
    while IFS=$'\t' read -r instance_id name instance_type private_ip; do
        if [[ -n "$instance_id" && "$instance_id" != "None" ]]; then
            # Check if instance is SSM-managed
            local ping_status=$(aws ssm describe-instance-information \
                --filters "Key=InstanceIds,Values=$instance_id" \
                --query 'InstanceInformationList[0].PingStatus' \
                --output text 2>/dev/null)
            
            if [[ "$ping_status" == "Online" ]]; then
                local display_name="${name:-unnamed}"
                # Truncate name to 32 chars and pad/format for table
                local formatted_name=$(printf "%-32.32s" "$display_name")
                local formatted_id=$(printf "%-19s" "$instance_id")
                local formatted_type=$(printf "%-15s" "$instance_type")
                local formatted_ip=$(printf "%-15s" "$private_ip")
                ssm_instances+=("💻 ${formatted_id} │ ${formatted_name} │ ${formatted_type} │ ${formatted_ip}")
            fi
        fi
    done <<< "$instances"
    
    if [[ ${#ssm_instances[@]} -gt 0 ]]; then
        printf '%s\n' "${ssm_instances[@]}"
    fi
}

# Connect to AWS EC2 instance via SSM
__mlnj_cde_aws_connect_ssm() {
    local instance_id="$1"
    
    if [[ -z "$instance_id" ]]; then
        gum style --foreground 196 "❌ Instance ID required"
        return 1
    fi
    
    if [[ -z "$AWS_PROFILE" ]]; then
        gum style --foreground 196 "❌ AWS profile not set"
        return 1
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        gum style --foreground 196 "❌ AWS CLI not found"
        return 1
    fi
    
    # Verify instance is SSM-accessible
    local ping_status=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$instance_id" \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null)
    
    if [[ "$ping_status" != "Online" ]]; then
        gum style --foreground 196 "❌ Instance $instance_id is not SSM-accessible (status: ${ping_status:-Unknown})"
        return 1
    fi
    
    gum style --foreground 86 "🚀 Starting SSM session to $instance_id..."
    
    # Start SSM session
    aws ssm start-session --target "$instance_id"
}

# Get SSM session history for current environment
__mlnj_cde_aws_ssm_history() {
    if [[ -z "$AWS_PROFILE" ]]; then
        gum style --foreground 196 "❌ AWS profile not set"
        return 1
    fi
    
    gum style --foreground 214 "📋 Recent SSM sessions:"
    
    aws ssm describe-sessions \
        --state-filter "Active,History" \
        --query 'Sessions[*].[SessionId,Target,Status,StartDate]' \
        --output table 2>/dev/null || gum style --foreground 196 "❌ Failed to get session history"
}