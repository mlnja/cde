# Azure SSH Provider for CDE
# Azure Virtual Machine connection via SSH

# List Azure VMs available for SSH
__mlnj_cde_azure_list_ssm_instances() {
    if ! command -v az >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if authenticated
    if ! az account show >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Azure authentication required. Please run cde.p first."
        return 1
    fi
    
    # Get running VMs (no output during collection)
    local vms=$(az vm list \
        --show-details \
        --query "[?powerState=='VM running'].[name,resourceGroup,vmSize,privateIps]" \
        --output tsv 2>/dev/null)
    
    if [[ -z "$vms" ]]; then
        return 1
    fi
    
    # Format VMs for display
    local azure_instances=()
    while IFS=$'\t' read -r name resource_group vm_size private_ips; do
        if [[ -n "$name" ]]; then
            local private_ip=$(echo "$private_ips" | tr ',' ' ' | awk '{print $1}')
            # Truncate name to 32 chars and pad/format for table
            local formatted_name=$(printf "%-32.32s" "$name")
            local formatted_id=$(printf "%-19s" "$name")
            local formatted_type=$(printf "%-15s" "$vm_size")
            local formatted_rg=$(printf "%-15s" "$resource_group")
            local formatted_ip=$(printf "%-15s" "$private_ip")
            azure_instances+=("💻 ${formatted_id} │ ${formatted_name} │ ${formatted_type} │ ${formatted_rg} │ ${formatted_ip}")
        fi
    done <<< "$vms"
    
    if [[ ${#azure_instances[@]} -gt 0 ]]; then
        printf '%s\n' "${azure_instances[@]}"
    fi
}

# Connect to Azure VM via SSH
__mlnj_cde_azure_connect_ssm() {
    local vm_name="$1"
    
    if [[ -z "$vm_name" ]]; then
        gum style --foreground 196 "❌ VM name required"
        return 1
    fi
    
    if ! command -v az >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Azure CLI not found"
        return 1
    fi
    
    # Get VM details
    local vm_info=$(az vm show --name "$vm_name" \
        --query "[resourceGroup,name]" \
        --output tsv 2>/dev/null)
    
    if [[ -z "$vm_info" ]]; then
        gum style --foreground 196 "❌ VM $vm_name not found"
        return 1
    fi
    
    local resource_group=$(echo "$vm_info" | cut -f1)
    
    gum style --foreground 86 "🚀 Connecting to $vm_name in resource group $resource_group..."
    
    # Check if VM has public IP
    local public_ip=$(az vm list-ip-addresses \
        --name "$vm_name" \
        --resource-group "$resource_group" \
        --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
        --output tsv 2>/dev/null)
    
    if [[ -n "$public_ip" && "$public_ip" != "null" ]]; then
        # Use Azure CLI SSH (requires Azure CLI 2.21.0+)
        if az ssh vm --name "$vm_name" --resource-group "$resource_group" 2>/dev/null; then
            return 0
        else
            gum style --foreground 214 "⚠️  Azure CLI SSH not available, trying direct SSH to public IP..."
            gum style --foreground 214 "💡 You may need to configure SSH keys and security groups"
            
            # Prompt for username
            local username
            username=$(gum input --placeholder "Enter SSH username (e.g., azureuser)")
            
            if [[ -n "$username" ]]; then
                ssh "${username}@${public_ip}"
            else
                gum style --foreground 214 "⚠️  No username provided"
                return 1
            fi
        fi
    else
        gum style --foreground 196 "❌ VM $vm_name has no public IP address"
        gum style --foreground 214 "💡 Consider using Azure Bastion or configuring a public IP"
        return 1
    fi
}

# List Azure VM connection options
__mlnj_cde_azure_ssh_history() {
    gum style --foreground 214 "📋 Azure VM connections:"
    echo "• Use 'az ssh vm' for direct SSH (requires Azure CLI 2.21.0+)"
    echo "• Use Azure Bastion for secure connections without public IPs"
    echo "• Use 'az serial-console connect' for serial console access"
}