# CDE - Cloud DevEx

Beautiful cloud utilities for your terminal with oh-my-zsh integration.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/mlnja/cde/main/install.sh | bash
```

Then add `cde` to your plugins in `~/.zshrc`:
```bash
plugins=(... cde)
```

Reload your shell:
```bash
source ~/.zshrc
```

## Requirements

- oh-my-zsh
- Git
- Go (for gum and skate dependencies)

## Usage

### Cache Management
```bash
# List all cached items
cde cache

# Clean cache
cde cache.clean
```

### Plugin Management
```bash
# Update CDE plugin
cde update

# Show help
cde help
```

## Features

- 🎨 Beautiful UI with [gum](https://github.com/charmbracelet/gum)
- 💾 Persistent caching with [skate](https://github.com/charmbracelet/skate)
- 📄 YAML processing with [yq](https://github.com/mikefarah/yq)
- 🔄 Git-based updates
- 🌈 Colorful terminal output

## Development

This plugin uses:
- **gum** for beautiful terminal UI components
- **skate** for key-value storage and caching
- **yq** for YAML/JSON processing
- **oh-my-zsh** plugin architecture
