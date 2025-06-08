# AWS SSM Provider for CDE
# AWS EC2 instance connection via Session Manager

# List AWS EC2 instances available for SSM - returns JSON data
__mlnj_cde_aws_list_ssm_instances() {
    if [[ -z "$AWS_PROFILE" ]]; then
        return 1
    fi
    
    if ! command -v aws >/dev/null 2>&1; then
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        gum style --foreground 196 "❌ jq command required for data processing"
        return 1
    fi
    
    # Check if authenticated
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        gum style --foreground 196 "❌ AWS authentication required. Please run cde.p first."
        return 1
    fi
    
    # Get all running EC2 instances with comprehensive data
    local ec2_data=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].{InstanceId: InstanceId, InstanceType: InstanceType, PrivateIp: PrivateIpAddress, PublicIp: PublicIpAddress, Tags: Tags}" \
        --output json 2>/dev/null)
    
    if [[ -z "$ec2_data" ]] || [[ "$ec2_data" == "[]" ]]; then
        return 1
    fi
    
    # Get all SSM-managed instances in one call
    local ssm_instances=$(aws ssm describe-instance-information \
        --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' \
        --output json 2>/dev/null)
    
    if [[ -z "$ssm_instances" ]] || [[ "$ssm_instances" == "[]" ]]; then
        return 1
    fi
    
    # Process and output each SSM-enabled instance as single-line JSON
    echo "$ec2_data" | jq -r --argjson ssm_list "$ssm_instances" '
        flatten | .[] | 
        select(.InstanceId as $id | $ssm_list | index($id)) |
        {
            instanceId: .InstanceId,
            instanceType: .InstanceType,
            privateIp: (.PrivateIp // "N/A"),
            publicIp: (.PublicIp // "N/A"),
            name: ((.Tags // []) | map(select(.Key == "Name")) | .[0].Value // "unnamed"),
            tags: .Tags,
            bastion: ((.Tags // []) | map(select(.Key == "Bastion")) | .[0].Value // "false")
        } | @json'
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