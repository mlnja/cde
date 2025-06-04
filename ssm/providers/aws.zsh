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
    
    if ! command -v yq >/dev/null 2>&1; then
        gum style --foreground 196 "❌ yq command required for data processing"
        return 1
    fi
    
    # Check if authenticated
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        gum style --foreground 196 "❌ AWS authentication required. Please run cde.p first."
        return 1
    fi
    
    # Query 1: Get all running EC2 instances with comprehensive data
    local ec2_data=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].{InstanceId: InstanceId, InstanceType: InstanceType, PrivateIp: PrivateIpAddress, PublicIp: PublicIpAddress, Tags: Tags}" \
        --output yaml 2>/dev/null)
    
    if [[ -z "$ec2_data" ]]; then
        return 1
    fi
    
    # Query 2: Get all SSM-managed instances in one call
    local ssm_data=$(aws ssm describe-instance-information \
        --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' \
        --output yaml 2>/dev/null)
    
    if [[ -z "$ssm_data" ]]; then
        return 1
    fi
    
    # Convert SSM data to newline-separated list for easy lookup
    local ssm_instances_list=$(echo "$ssm_data" | yq eval '.[]' - 2>/dev/null)
    
    # Use a simple approach: loop through EC2 instances and check SSM connectivity
    local ssm_instances=()
    
    # Convert EC2 YAML to individual instance records and process each
    local current_instance=""
    local instance_id=""
    local instance_type=""
    local private_ip=""
    local instance_name=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*-[[:space:]]*InstanceId: ]]; then
            # New instance starting, process previous if exists
            if [[ -n "$instance_id" ]] && echo "$ssm_instances_list" | grep -q "^$instance_id$"; then
                local display_name="${instance_name:-unnamed}"
                local formatted_name=$(printf "%-32.32s" "$display_name")
                local formatted_id=$(printf "%-19s" "$instance_id")
                local formatted_type=$(printf "%-15s" "$instance_type")
                local formatted_ip=$(printf "%-15s" "$private_ip")
                ssm_instances+=("💻 ${formatted_id} │ ${formatted_name} │ ${formatted_type} │ ${formatted_ip}")
            fi
            
            # Reset for new instance
            instance_id=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*-[[:space:]]*InstanceId:[[:space:]]*//')
            instance_type=""
            private_ip=""
            instance_name=""
        elif [[ "$line" =~ ^[[:space:]]*InstanceType: ]]; then
            instance_type=$(echo "$line" | sed 's/^[[:space:]]*InstanceType:[[:space:]]*//')
        elif [[ "$line" =~ ^[[:space:]]*PrivateIp: ]]; then
            private_ip=$(echo "$line" | sed 's/^[[:space:]]*PrivateIp:[[:space:]]*//')
            [[ "$private_ip" == "null" ]] && private_ip="N/A"
        elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*Key:[[:space:]]*Name$ ]]; then
            # Next line should be the Value
            read -r value_line
            if [[ "$value_line" =~ ^[[:space:]]*Value: ]]; then
                instance_name=$(echo "$value_line" | sed 's/^[[:space:]]*Value:[[:space:]]*//')
            fi
        fi
    done <<< "$ec2_data"
    
    # Process the last instance
    if [[ -n "$instance_id" ]] && echo "$ssm_instances_list" | grep -q "^$instance_id$"; then
        local display_name="${instance_name:-unnamed}"
        local formatted_name=$(printf "%-32.32s" "$display_name")
        local formatted_id=$(printf "%-19s" "$instance_id")
        local formatted_type=$(printf "%-15s" "$instance_type")
        local formatted_ip=$(printf "%-15s" "$private_ip")
        ssm_instances+=("💻 ${formatted_id} │ ${formatted_name} │ ${formatted_type} │ ${formatted_ip}")
    fi
    
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