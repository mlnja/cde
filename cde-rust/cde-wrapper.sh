#!/usr/bin/env bash
# CDE Bash Wrapper
# This wrapper enables the Rust binary to set environment variables in the parent shell
# by communicating through fd 3

# Function to execute CDE with fd(3) for env var communication
cde() {
    # Create a temporary named pipe for bidirectional communication
    local tmpdir=$(mktemp -d)
    local pipe="$tmpdir/cde_pipe"
    mkfifo "$pipe"

    # Run the Rust binary with fd 3 redirected to the pipe
    # The binary writes JSON commands to fd 3
    "$HOME/.local/share/cde/cde-rust/target/release/cde" "$@" 3>"$pipe" &
    local rust_pid=$!

    # Read commands from the pipe in the background
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local action=$(echo "$line" | jq -r '.action // empty')

            case "$action" in
                "set_env")
                    local key=$(echo "$line" | jq -r '.key // empty')
                    local value=$(echo "$line" | jq -r '.value // empty')
                    if [[ -n "$key" ]]; then
                        export "$key=$value"
                    fi
                    ;;
                "unset_env")
                    local key=$(echo "$line" | jq -r '.key // empty')
                    if [[ -n "$key" ]]; then
                        unset "$key"
                    fi
                    ;;
                *)
                    ;;
            esac
        fi
    done < "$pipe"

    # Wait for the Rust process to complete
    wait $rust_pid
    local exit_code=$?

    # Cleanup
    rm -rf "$tmpdir"

    return $exit_code
}

# Export the function so it's available in subshells
export -f cde