# CDE Cache Management Functions
# Cache functionality using skate for persistent storage

# Main cache command dispatcher
__mlnj_cde_cache() {
    if [[ $# -eq 0 ]]; then
        # Get current environment key
        local env_key=""
        if [[ -n "$AWS_PROFILE" ]]; then
            env_key="aws:${AWS_PROFILE}"
        elif command -v gcloud >/dev/null 2>&1; then
            local gcp_project=$(gcloud config get-value project 2>/dev/null)
            if [[ -n "$gcp_project" ]]; then
                env_key="gcp:${gcp_project}"
            fi
        elif command -v az >/dev/null 2>&1; then
            local azure_sub=$(az account show --query "name" -o tsv 2>/dev/null)
            if [[ -n "$azure_sub" ]]; then
                env_key="azure:${azure_sub}"
            fi
        fi
        
        if [[ -n "$env_key" ]]; then
            echo "📦 Cached items for environment: $env_key"
            
            # Get all keys and filter for current environment
            local env_keys=$(skate list @__mlnj_cde -k | grep "^ssm_instances:${env_key}")
            local global_keys=$(skate list @__mlnj_cde -k | grep -v "^ssm_instances:")
            
            if [[ -n "$env_keys" ]]; then
                echo "Environment-specific cache:"
                echo "$env_keys"
            fi
            
            if [[ -n "$global_keys" ]]; then
                echo "Global cache:"
                echo "$global_keys"
            fi
            
            if [[ -z "$env_keys" && -z "$global_keys" ]]; then
                echo "No cache items found."
            fi
        else
            echo "📦 All cached items (no environment set):"
            skate list @__mlnj_cde -k
        fi
        return
    fi

    if [[ $# -gt 0 ]]; then
        echo "Usage: cde cache - show all cached items"
        return 1
    fi
}

# Clean cache data for current environment
__mlnj_cde_cache_clean() {
    # Get current environment key
    local env_key=""
    if [[ -n "$AWS_PROFILE" ]]; then
        env_key="aws:${AWS_PROFILE}"
    elif command -v gcloud >/dev/null 2>&1; then
        local gcp_project=$(gcloud config get-value project 2>/dev/null)
        if [[ -n "$gcp_project" ]]; then
            env_key="gcp:${gcp_project}"
        fi
    elif command -v az >/dev/null 2>&1; then
        local azure_sub=$(az account show --query "name" -o tsv 2>/dev/null)
        if [[ -n "$azure_sub" ]]; then
            env_key="azure:${azure_sub}"
        fi
    fi
    
    if [[ -z "$env_key" ]]; then
        gum style --foreground 214 "🧹 No environment detected. Cleaning ALL cache data..."
        
        # List all current items for confirmation (keys only)
        local all_cache_items=$(skate list @__mlnj_cde -k 2>/dev/null)
        
        if [[ -z "$all_cache_items" ]]; then
            gum style --foreground 86 "✅ Cache is already empty"
            return 0
        fi
        
        echo "All cached items:"
        echo "$all_cache_items"
        echo ""
        
        # Ask for confirmation to delete everything
        if gum confirm "Delete ALL cached data?"; then
            # Delete each key individually
            while IFS= read -r key; do
                if [[ -n "$key" ]]; then
                    skate delete "${key}@__mlnj_cde" 2>/dev/null
                    echo "Deleted: $key"
                fi
            done <<< "$all_cache_items"
            gum style --foreground 86 "✅ All CDE cache data cleaned"
        else
            gum style --foreground 214 "⚠️  Cache cleaning cancelled"
        fi
        return 0
    fi
    
    gum style --foreground 214 "🧹 Cleaning cache data for environment: $env_key"
    
    # Get environment-specific cache keys
    local env_keys=$(skate list @__mlnj_cde -k | grep "^ssm_instances:${env_key}")
    
    if [[ -z "$env_keys" ]]; then
        gum style --foreground 86 "✅ No cache items found for this environment"
        return 0
    fi
    
    echo "Cache items to delete for $env_key:"
    echo "$env_keys"
    echo ""
    
    # Ask for confirmation
    if gum confirm "Delete cache for this environment?"; then
        # Delete each environment-specific key
        while IFS= read -r key; do
            if [[ -n "$key" ]]; then
                skate delete "${key}@__mlnj_cde" 2>/dev/null
                echo "Deleted: $key"
            fi
        done <<< "$env_keys"
        gum style --foreground 86 "✅ Environment cache cleaned"
    else
        gum style --foreground 214 "⚠️  Cache cleaning cancelled"
    fi
}