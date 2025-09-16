# Kubernetes Context Command - CDE
# Kubernetes context selection functionality

# Clean kubernetes environment variables
__mlnj_cde_clean_k8s_context() {
    unset KUBECONFIG
}

# List available kubernetes contexts
__mlnj_cde_k8x_list_contexts() {
    local contexts=()

    # Check if kubectl is available
    if ! command -v kubectl >/dev/null 2>&1; then
        return 1
    fi

    # Check if kubeconfig exists
    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    if [[ ! -f "$kubeconfig" ]]; then
        return 1
    fi

    # Get current context
    local current_context=$(yq eval '.current-context' "$kubeconfig" 2>/dev/null)

    # List all contexts with simple icons
    yq eval '.contexts[] | .name' "$kubeconfig" 2>/dev/null | while IFS= read -r context; do
        if [[ "$context" == "$current_context" ]]; then
            echo "✓ $context"
        else
            echo "* $context"
        fi
    done
}

# Set kubernetes context using yq
__mlnj_cde_k8x_set_context() {
    local context="$1"

    if [[ -z "$context" ]]; then
        gum style --foreground 196 "❌ No context specified"
        return 1
    fi

    # Check if kubectl and yq are available
    if ! command -v kubectl >/dev/null 2>&1; then
        gum style --foreground 196 "❌ kubectl not found"
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        gum style --foreground 196 "❌ yq not found"
        return 1
    fi

    local kubeconfig="${KUBECONFIG:-$HOME/.kube/config}"
    if [[ ! -f "$kubeconfig" ]]; then
        gum style --foreground 196 "❌ Kubeconfig not found: $kubeconfig"
        return 1
    fi

    # Verify context exists
    if ! yq eval '.contexts[] | select(.name == "'$context'") | .name' "$kubeconfig" >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Context not found: $context"
        return 1
    fi

    # Set current context using yq
    if yq eval -i '.current-context = "'$context'"' "$kubeconfig" 2>/dev/null; then
        gum style --foreground 86 "✅ Switched to kubernetes context: $context"

        # Show current context info
        local cluster=$(yq eval '.contexts[] | select(.name == "'$context'") | .context.cluster' "$kubeconfig" 2>/dev/null)
        local namespace=$(yq eval '.contexts[] | select(.name == "'$context'") | .context.namespace // "default"' "$kubeconfig" 2>/dev/null)

        echo "   Cluster: $cluster"
        echo "   Namespace: $namespace"
    else
        gum style --foreground 196 "❌ Failed to switch context"
        return 1
    fi
}

# Unified kubernetes context selection
__mlnj_cde_k8x_unified() {
    local contexts=$(__mlnj_cde_k8x_list_contexts 2>/dev/null)

    if [[ -z "$contexts" ]]; then
        gum style --foreground 196 "❌ No kubernetes contexts found"
        gum style --foreground 214 "   Make sure kubectl is installed and ~/.kube/config exists"
        return 1
    fi

    # Show unified selection with fuzzy filter
    gum style --foreground 86 "☸️  Select Kubernetes Context:"
    local selected=$(echo "$contexts" | gum filter --placeholder="Type to filter contexts..." --height=15)

    if [[ -n "$selected" ]]; then
        # Parse selection (format: "✓ context" or "* context")
        local context=$(echo "$selected" | sed 's/^[✓*] //')
        __mlnj_cde_k8x_set_context "$context"
    else
        # No context selected (includes Ctrl+C)
        gum style --foreground 214 "⚠️  No context selected"
        __mlnj_cde_clean_k8s_context
    fi
}

# Kubernetes context management function (public interface)
__mlnj_cde_k8x() {
    case "${1:-}" in
        "help"|"-h"|"--help")
            echo "Usage: cde.k8x [help]"
            echo ""
            echo "Interactive kubernetes context selection"
            echo ""
            echo "Options:"
            echo "  help    Show this help message"
            ;;
        *)
            __mlnj_cde_k8x_unified
            ;;
    esac
}