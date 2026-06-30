# CDE S3 View
# Mount an S3 path read-only via rclone in a background tmux session,
# open it in an editor, and unmount when the editor closes.

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
    if ! command -v tmux >/dev/null 2>&1; then
        gum style --foreground 196 "❌ tmux not found"
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

    # Build stable names from the path
    local safe_name="${s3_path//[^a-zA-Z0-9_-]/_}"
    local mount_dir="/tmp/__mlnj_cde_s3view_${safe_name}"
    local session_name="__mlnj_cde_s3view_${safe_name}"

    # Tear down any leftover session / stale mount
    if tmux has-session -t "$session_name" 2>/dev/null; then
        gum style --foreground 214 "⚠️  Existing session found — restarting..."
        tmux kill-session -t "$session_name" 2>/dev/null
        sleep 1
    fi
    __mlnj_cde_s3view_unmount "$mount_dir"

    mkdir -p "$mount_dir"

    gum style --foreground 86 "📦 Mounting $s3_path"
    gum style --foreground 214 "📁 $mount_dir"
    gum style --foreground 214 "👤 Profile: ${AWS_PROFILE:-default}"

    # Start rclone in a detached tmux session, forwarding the AWS profile
    tmux new-session -d -s "$session_name" \
        -e AWS_PROFILE="$AWS_PROFILE" \
        -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}" \
        -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}" \
        -e AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}" \
        "rclone mount '${rclone_path}' '${mount_dir}' --read-only --vfs-cache-mode reads 2>&1"
    tmux set-hook -t "$session_name" client-attached 'detach-client'

    # Wait for the FUSE mount to appear (up to 15 s)
    gum style --foreground 214 "⏳ Waiting for mount..."
    local ready=false
    for i in {1..15}; do
        sleep 1
        if ! tmux has-session -t "$session_name" 2>/dev/null; then
            gum style --foreground 196 "❌ rclone exited early — check your rclone config and AWS credentials"
            rmdir "$mount_dir" 2>/dev/null
            return 1
        fi
        if __mlnj_cde_s3view_is_mounted "$mount_dir"; then
            ready=true
            break
        fi
    done

    if [[ "$ready" != "true" ]]; then
        gum style --foreground 214 "⚠️  Mount not confirmed yet, opening anyway..."
    else
        gum style --foreground 86 "✅ Mounted"
    fi

    # Open editor — blocks until closed
    gum style --foreground 86 "🖊  Opening $editor (close it to unmount)..."
    if [[ "$editor" == "vim" ]]; then
        "$editor" "$mount_dir"
    else
        "$editor" --wait "$mount_dir" 2>/dev/null
    fi

    # Editor closed — clean up
    gum style --foreground 214 "🔌 Editor closed, unmounting..."
    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux kill-session -t "$session_name" 2>/dev/null
        sleep 1
    fi
    __mlnj_cde_s3view_unmount "$mount_dir"
    rmdir "$mount_dir" 2>/dev/null
    gum style --foreground 86 "✅ Done"
}

# Cross-platform mount check (macOS lacks `mountpoint`)
__mlnj_cde_s3view_is_mounted() {
    local dir="$1"
    if command -v mountpoint >/dev/null 2>&1; then
        mountpoint -q "$dir" 2>/dev/null
    else
        mount 2>/dev/null | grep -q " on ${dir} \| on ${dir}$\|${dir} type\|${dir},"
    fi
}

# Cross-platform unmount
__mlnj_cde_s3view_unmount() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    __mlnj_cde_s3view_is_mounted "$dir" || return 0
    if command -v diskutil >/dev/null 2>&1; then
        diskutil unmount force "$dir" 2>/dev/null || true
    else
        fusermount -u "$dir" 2>/dev/null || umount -f "$dir" 2>/dev/null || true
    fi
}

__mlnj_cde_s3view_help() {
    gum style \
        --foreground 86 --border-foreground 86 --border double \
        --align center --width 60 --margin "1 2" --padding "2 4" \
        'CDE S3 View' 'Mount S3 read-only and open in editor'

    echo ""
    echo "Usage:"
    echo "  cde.s3view s3://<bucket>[/path]          - Open with VS Code (default)"
    echo "  cde.s3view s3://<bucket>[/path] zed      - Open with Zed"
    echo "  cde.s3view s3://<bucket>[/path] vim      - Open with Vim"
    echo "  cde.s3view help                          - Show this help"
    echo ""
    echo "Flow:"
    echo "  1. Mounts the S3 path read-only via rclone (background tmux session)"
    echo "  2. Opens the editor — blocks until you close it"
    echo "  3. Unmounts and cleans up automatically"
    echo ""
    echo "Examples:"
    echo "  cde.s3view s3://my-bucket"
    echo "  cde.s3view s3://my-bucket/logs/2024"
    echo "  cde.s3view s3://my-bucket/configs zed"
    echo ""
    echo "Requirements:"
    echo "  rclone (brew install rclone)  +  rclone configured with AWS credentials"
    echo "  tmux  +  code / zed / vim"
}
