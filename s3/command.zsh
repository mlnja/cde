# CDE S3 View
# Copies an S3 path into a local temp dir via rclone, opens it in an editor,
# and deletes the temp dir when the editor closes.

__mlnj_cde_s3view() {
    local s3_path=""
    local editor_arg=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            "help"|"-h"|"--help")
                __mlnj_cde_s3view_help
                return 0
                ;;
            s3://*)
                s3_path="$1"
                shift
                ;;
            "code"|"zed"|"vim")
                editor_arg="$1"
                shift
                ;;
            *)
                gum style --foreground 196 "❌ Unknown argument: $1"
                __mlnj_cde_s3view_help
                return 1
                ;;
        esac
    done

    if [[ -z "$s3_path" ]]; then
        gum style --foreground 196 "❌ S3 path required (e.g., s3://my-bucket/path)"
        __mlnj_cde_s3view_help
        return 1
    fi

    # Check dependencies
    if ! command -v rclone >/dev/null 2>&1; then
        gum style --foreground 196 "❌ rclone not found"
        echo "   Install: brew install rclone"
        return 1
    fi

    # Resolve editor (default: code)
    local editor="${editor_arg:-code}"
    if ! command -v "$editor" >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Editor not found: $editor"
        return 1
    fi

    # Convert s3://bucket/path  →  :s3:bucket/path  (rclone on-the-fly S3 backend)
    local rclone_path=":s3:${s3_path#s3://}"

    # Temp dir for local copy
    local safe_name="${s3_path//[^a-zA-Z0-9_-]/_}"
    local local_dir="/tmp/__mlnj_cde_s3view_${safe_name}"

    # Clean up any previous run
    [[ -d "$local_dir" ]] && rm -rf "$local_dir"
    mkdir -p "$local_dir"

    gum style --foreground 86 "📥 Copying $s3_path"
    gum style --foreground 214 "📁 $local_dir"
    gum style --foreground 214 "👤 Profile: ${AWS_PROFILE:-default}"

    # Copy from S3 — show spinner, forward AWS credentials
    AWS_PROFILE="$AWS_PROFILE" \
    AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
    AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
    AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}" \
    gum spin --spinner dot --title "Downloading from S3..." -- \
        rclone copy "${rclone_path}" "${local_dir}" \
            --s3-env-auth --s3-provider AWS 2>&1

    if [[ $? -ne 0 ]]; then
        gum style --foreground 196 "❌ rclone copy failed — check AWS credentials for profile: ${AWS_PROFILE:-default}"
        rm -rf "$local_dir"
        return 1
    fi

    local file_count=$(find "$local_dir" -type f | wc -l | tr -d ' ')
    gum style --foreground 86 "✅ Downloaded $file_count files"

    # Open editor — blocks until closed
    gum style --foreground 86 "🖊  Opening $editor (close it to clean up)..."
    case "$editor" in
        vim)
            "$editor" "$local_dir"
            ;;
        code)
            # --new-window forces a dedicated window; --wait blocks until that window closes
            "$editor" --new-window --wait "$local_dir"
            ;;
        zed)
            "$editor" --wait "$local_dir"
            ;;
    esac

    # Editor closed — delete local copy
    gum style --foreground 214 "🗑  Cleaning up $local_dir..."
    rm -rf "$local_dir"
    gum style --foreground 86 "✅ Done"
}

__mlnj_cde_s3view_help() {
    gum style \
        --foreground 86 --border-foreground 86 --border double \
        --align center --width 60 --margin "1 2" --padding "2 4" \
        'CDE S3 View' 'Copy S3 path locally and open in editor'

    echo ""
    echo "Usage:"
    echo "  cde.s3view s3://<bucket>[/path]          - Open with VS Code (default)"
    echo "  cde.s3view s3://<bucket>[/path] zed      - Open with Zed"
    echo "  cde.s3view s3://<bucket>[/path] vim      - Open with Vim"
    echo "  cde.s3view help                          - Show this help"
    echo ""
    echo "Flow:"
    echo "  1. Copies S3 path to a local temp dir via rclone"
    echo "  2. Opens the editor — blocks until you close it"
    echo "  3. Deletes the local copy on editor close"
    echo ""
    echo "Examples:"
    echo "  cde.s3view s3://my-bucket"
    echo "  cde.s3view s3://my-bucket/logs/2024"
    echo "  cde.s3view s3://my-bucket/configs zed"
    echo ""
    echo "Requirements:"
    echo "  rclone (brew install rclone)  +  AWS credentials via cde.p"
    echo "  code / zed / vim"
}
