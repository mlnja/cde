#!/bin/bash

# CDE - Cloud DevEx Oh My Zsh Plugin Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/username/cde/main/install.sh | bash

set -e

PLUGIN_NAME="cde"
PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$PLUGIN_NAME"
REPO_URL="https://github.com/username/cde.git"

echo "🌥️  Installing CDE (Cloud DevEx) plugin..."

# Check if oh-my-zsh is installed
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "❌ Oh My Zsh is not installed. Please install it first: https://ohmyz.sh"
    exit 1
fi

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

# Clone or update the repository
if [[ -d "$PLUGIN_DIR" ]]; then
    echo "📥 Updating existing CDE plugin..."
    cd "$PLUGIN_DIR"
    git pull origin main
else
    echo "📥 Cloning CDE plugin..."
    git clone "$REPO_URL" "$PLUGIN_DIR"
fi

# Install dependencies via Go
echo "📦 Installing gum and skate via Go..."
go install github.com/charmbracelet/gum@latest
go install github.com/charmbracelet/skate@latest

# Ensure Go bin is in PATH
if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
    echo "⚠️  Make sure $HOME/go/bin is in your PATH"
    echo "   Add this to your ~/.zshrc: export PATH=\$PATH:\$HOME/go/bin"
fi

echo "✅ CDE plugin installed!"
echo ""
echo "📝 To activate, add 'cde' to your plugins in ~/.zshrc:"
echo "   plugins=(... cde)"
echo ""
echo "🔄 Then reload your shell: source ~/.zshrc"