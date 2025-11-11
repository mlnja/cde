# Bitwarden Command - CDE
# Bitwarden CLI wrapper with PGP-encrypted password storage

# Get PGP key ID from config
__mlnj_cde_bw_get_pgp_key() {
    local config_file="${HOME}/.cde/config.yml"

    if [[ ! -f "$config_file" ]]; then
        gum style --foreground 196 "❌ Config file not found: $config_file"
        echo "" >&2
        echo "Create the config file with:" >&2
        echo "  mkdir -p ~/.cde" >&2
        echo "  echo 'pgp_key_id: YOUR_GPG_KEY_ID' > ~/.cde/config.yml" >&2
        return 1
    fi

    local pgp_key=$(yq eval '.pgp_key_id' "$config_file" 2>/dev/null)

    if [[ -z "$pgp_key" || "$pgp_key" == "null" ]]; then
        gum style --foreground 196 "❌ pgp_key_id not configured in $config_file"
        echo "" >&2
        echo "Add to your config file:" >&2
        echo "  pgp_key_id: YOUR_GPG_KEY_ID" >&2
        echo "" >&2
        echo "List your GPG keys with: gpg --list-keys" >&2
        return 1
    fi

    echo "$pgp_key"
}

# Encrypt password with GPG
__mlnj_cde_bw_encrypt_password() {
    local password="$1"
    local pgp_key="$2"

    # Encrypt password using GPG
    local encrypted=$(echo -n "$password" | gpg --encrypt --armor --recipient "$pgp_key" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        gum style --foreground 196 "❌ Failed to encrypt password with GPG key: $pgp_key"
        echo "" >&2
        echo "Make sure the GPG key exists and is trusted:" >&2
        echo "  gpg --list-keys" >&2
        return 1
    fi

    echo "$encrypted"
}

# Decrypt password with GPG
__mlnj_cde_bw_decrypt_password() {
    local encrypted="$1"

    # Decrypt password using GPG
    local decrypted=$(echo -n "$encrypted" | gpg --decrypt --quiet 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        gum style --foreground 196 "❌ Failed to decrypt password with GPG"
        echo "" >&2
        echo "Make sure you have access to the private key." >&2
        return 1
    fi

    echo "$decrypted"
}

# Store encrypted password in skate
__mlnj_cde_bw_store_password() {
    local encrypted_password="$1"
    local cache_key="bw_master_password"

    # Store in skate
    echo "$encrypted_password" | skate set "${cache_key}@__mlnj_cde" 2>/dev/null

    if [[ $? -ne 0 ]]; then
        gum style --foreground 196 "❌ Failed to store password in skate"
        return 1
    fi
}

# Retrieve encrypted password from skate (silent mode)
__mlnj_cde_bw_get_stored_password() {
    local cache_key="bw_master_password"
    local encrypted=$(skate get "${cache_key}@__mlnj_cde" 2>/dev/null)
    echo "$encrypted"
}

# Prompt user for password and store it
__mlnj_cde_bw_prompt_and_store() {
    # Get PGP key from config
    local pgp_key=$(__mlnj_cde_bw_get_pgp_key)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Prompt for master password
    local master_password
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 214 "🔐 No stored password found. Please enter your Bitwarden master password."
        master_password=$(gum input --password --placeholder "Master password")
    else
        echo "No stored password found."
        echo -n "Enter your Bitwarden master password: "
        read -s master_password
        echo ""
    fi

    if [[ -z "$master_password" ]]; then
        gum style --foreground 196 "❌ Password cannot be empty"
        return 1
    fi

    # Encrypt and store password
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 214 "🔒 Encrypting and storing master password..."
    fi

    local encrypted=$(__mlnj_cde_bw_encrypt_password "$master_password" "$pgp_key")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    __mlnj_cde_bw_store_password "$encrypted"
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 86 "✅ Password stored securely"
    fi

    echo "$master_password"
}

# Get or prompt for password
__mlnj_cde_bw_get_password() {
    # Try to get stored password
    local encrypted=$(__mlnj_cde_bw_get_stored_password)

    if [[ -n "$encrypted" ]]; then
        # Decrypt and return
        local decrypted=$(__mlnj_cde_bw_decrypt_password "$encrypted")
        if [[ $? -eq 0 ]]; then
            echo "$decrypted"
            return 0
        else
            # Decryption failed, prompt for new password
            gum style --foreground 214 "⚠️  Failed to decrypt stored password."
            __mlnj_cde_bw_prompt_and_store
            return $?
        fi
    else
        # No stored password, prompt user
        __mlnj_cde_bw_prompt_and_store
        return $?
    fi
}

# Reset stored password
__mlnj_cde_bw_reset() {
    local cache_key="bw_master_password"

    # Check if password exists
    local encrypted=$(__mlnj_cde_bw_get_stored_password)
    if [[ -z "$encrypted" ]]; then
        gum style --foreground 214 "⚠️  No stored password found"
        return 0
    fi

    # Delete from skate
    skate delete "${cache_key}@__mlnj_cde" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        gum style --foreground 86 "✅ Stored password cleared"
    else
        gum style --foreground 196 "❌ Failed to clear stored password"
        return 1
    fi
}

# Proxy command to bw with auto-decrypted password
__mlnj_cde_bw_proxy() {
    # Check if bw is installed
    if ! command -v bw >/dev/null 2>&1; then
        gum style --foreground 196 "❌ Bitwarden CLI (bw) not found"
        echo "" >&2
        echo "Install with: npm install -g @bitwarden/cli" >&2
        return 1
    fi

    # Special cases: login, unlock, lock - tell user to use bw directly
    if [[ "$1" == "login" ]]; then
        gum style --foreground 214 "💡 For login, use: bw login"
        echo ""
        echo "After logging in, use cde.bw for other commands with auto-decrypted password."
        return 1
    fi

    if [[ "$1" == "unlock" ]]; then
        gum style --foreground 214 "💡 For unlock, use: bw unlock"
        echo ""
        echo "Then use cde.bw for other commands with auto-decrypted password."
        return 1
    fi

    if [[ "$1" == "lock" ]]; then
        gum style --foreground 214 "💡 For lock, use: bw lock"
        return 1
    fi

    # For all other commands, get/prompt for password
    local master_password=$(__mlnj_cde_bw_get_password)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Run bw command with BW_PASSWORD set
    BW_PASSWORD="$master_password" bw "$@"
}

# Main BW command function (public interface)
__mlnj_cde_bw() {
    local subcommand="$1"

    if [[ -z "$subcommand" ]]; then
        # No arguments - show help
        echo "Bitwarden CLI wrapper with encrypted password storage"
        echo ""
        echo "Usage:"
        echo "  cde.bw <command>         - Run any bw command with auto-decrypted password"
        echo "  cde.bw.reset             - Clear stored password from cache"
        echo ""
        echo "Examples:"
        echo "  cde.bw list items"
        echo "  cde.bw get item 'Item Name'"
        echo "  cde.bw sync"
        echo "  cde.bw status"
        echo ""
        echo "Note: For login/unlock/lock, use the original bw commands:"
        echo "  bw login [email]"
        echo "  bw unlock"
        echo "  bw lock"
        echo ""
        echo "First time you run a cde.bw command, you'll be prompted for your"
        echo "master password. It will be encrypted with GPG and stored securely."
        return 0
    fi

    # All commands are proxied
    __mlnj_cde_bw_proxy "$@"
}
