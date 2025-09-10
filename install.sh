#!/bin/bash

# CDE - Cloud DevEx Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/mlnja/cde/main/install.sh | bash

set -e

CDE_DIR="$HOME/.local/share/cde"
REPO_URL="https://github.com/mlnja/cde.git"

echo "🌥️  Installing CDE (Cloud DevEx)..."

# Create .local/share directory if it doesn't exist
mkdir -p "$HOME/.local/share"

# Check if Git is installed
if ! command -v git >/dev/null 2>&1; then
    echo "❌ Git is not installed. Please install Git first."
    exit 1
fi

# Check if Go is installed
if ! command -v go >/dev/null 2>&1; then
    echo "❌ Go is not installed. Please install Go first: https://golang.org/doc/install"
    exit 1
fi

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq is not installed. Please install jq first:"
    echo "   macOS: brew install jq"
    echo "   Ubuntu/Debian: sudo apt-get install jq"
    echo "   CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# Clone or update the repository
if [[ -d "$CDE_DIR" ]]; then
    echo "📥 Updating existing CDE installation..."
    cd "$CDE_DIR"
    git pull origin main
else
    echo "📥 Cloning CDE..."
    git clone "$REPO_URL" "$CDE_DIR"
fi

# Install dependencies via Go
echo "📦 Installing gum, skate, and yq via Go..."
go install github.com/charmbracelet/gum@latest
go install github.com/charmbracelet/skate@latest
go install github.com/mikefarah/yq/v4@latest

# Ensure Go bin is in PATH
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    echo "⚠️  Make sure $HOME/go/bin is in your PATH"
    echo "   Add this to your ~/.zshenv: export PATH=\$PATH:\$HOME/go/bin"
fi

echo "✅ CDE installed!"
echo ""
echo "📝 To activate, add this line to your ~/.zshenv:"
echo "   source ~/.local/share/cde/cde.zsh"
echo ""
echo "🔄 Then reload your shell: source ~/.zshenv"