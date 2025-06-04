# GCP SSH Provider for CDE
# GCP Compute Engine instance connection via SSH

# List GCP Compute Engine instances available for SSH
__mlnj_cde_gcp_list_ssm_instances() {
    if ! command -v gcloud >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "@"; then
        gum style --foreground 196 "❌ GCP authentication required. Please run cde.p first."
        return 1
    fi
    
    local project=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$project" ]]; then
        gum style --foreground 196 "❌ No GCP project set"
        return 1
    fi
    
    # Get running instances (no output during collection)
    local instances=$(gcloud compute instances list \
        --filter="status=RUNNING" \
        --format="value(name,zone,machineType.basename(),networkInterfaces[0].networkIP)" 2>/dev/null)
    
    if [[ -z "$instances" ]]; then
        return 1
    fi
    
    # Format instances for display
    local gcp_instances=()
    while IFS=$'\t' read -r name zone machine_type internal_ip; do
        if [[ -n "$name" ]]; then
            # Truncate name to 32 chars and pad/format for table
            local formatted_name=$(printf "%-32.32s" "$name")
            local formatted_id=$(printf "%-19s" "$name")
            local formatted_type=$(printf "%-15s" "$machine_type")
            local formatted_zone=$(printf "%-15s" "$(basename "$zone")")
            local formatted_ip=$(printf "%-15s" "$internal_ip")
            gcp_instances+=("💻 ${formatted_id} │ ${formatted_name} │ ${formatted_type} │ ${formatted_zone} │ ${formatted_ip}")
        fi
    done <<< "$instances"
    
    if [[ ${#gcp_instances[@]} -gt 0 ]]; then
        printf '%s\n' "${gcp_instances[@]}"
    fi
}

# Connect to GCP Compute Engine instance via SSH
__mlnj_cde_gcp_connect_ssm() {
    local instance_name="$1"
    
    if [[ -z "$instance_name" ]]; then
        gum style --foreground 196 "❌ Instance name required"
        return 1
    fi
    
    if ! command -v gcloud >/dev/null 2>&1; then
        gum style --foreground 196 "❌ gcloud CLI not found"
        return 1
    fi
    
    local project=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$project" ]]; then
        gum style --foreground 196 "❌ No GCP project set"
        return 1
    fi
    
    # Get instance zone
    local zone=$(gcloud compute instances list \
        --filter="name=$instance_name AND status=RUNNING" \
        --format="value(zone)" 2>/dev/null | head -1)
    
    if [[ -z "$zone" ]]; then
        gum style --foreground 196 "❌ Instance $instance_name not found or not running"
        return 1
    fi
    
    # Extract zone name (remove full path)
    zone=$(basename "$zone")
    
    gum style --foreground 86 "🚀 Connecting to $instance_name in zone $zone..."
    
    # Start SSH session
    gcloud compute ssh "$instance_name" --zone="$zone"
}

# List active SSH connections (placeholder)
__mlnj_cde_gcp_ssh_history() {
    gum style --foreground 214 "📋 GCP SSH connections are managed through gcloud compute ssh"
    echo "Use 'gcloud compute ssh --help' for more options"
}