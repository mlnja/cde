# CDE - Cloud DevEx

A beautiful command-line interface for cloud operations with unified profile management, instance connections, and container registry tools.

## Features

- 🌥️ **Unified Cloud Profiles** - Switch between AWS, GCP, and Azure profiles seamlessly
- 🖥️ **Instance Connections** - Connect to cloud instances via SSM/SSH with automatic discovery
- 🚇 **Bastion Tunneling** - Secure tunneling through bastion hosts
- 🐳 **Container Registry** - Easy ECR/container registry login and management  
- 💾 **Smart Caching** - Intelligent caching for faster operations
- ⚡ **Lazy Loading** - Fast shell startup with on-demand loading

## Installation

### Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/mlnja/cde/main/install.sh | bash
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/mlnja/cde.git ~/.local/share/cde
```

2. Install dependencies:
```bash
go install github.com/charmbracelet/gum@latest
go install github.com/charmbracelet/skate@latest  
go install github.com/mikefarah/yq/v4@latest
```

3. Add to your shell configuration (~/.zshenv):
```bash
# Add CDE to your shell
source ~/.local/share/cde/cde.zsh

# Make sure Go bin is in PATH
export PATH=$PATH:$HOME/go/bin
```

4. Reload your shell:
```bash
source ~/.zshenv
```

## Requirements

- **Git** - For installation and updates
- **Go** - For installing gum, skate, and yq dependencies
- **jq** - For JSON processing
- **Zsh or Bash** - Shell support

### Cloud CLI Tools (as needed)
- **AWS CLI** - For AWS operations
- **gcloud** - For GCP operations  
- **Azure CLI** - For Azure operations

## Usage

### Core Commands

```bash
cde help                    # Show help
cde doctor                  # Check dependencies and installation
cde cache                   # Show cached data
cde cache.clean            # Clean all cached data  
cde update                 # Update CDE to latest version
```

### Cloud Profile Management

```bash
cde.p                      # Interactive profile selector
```

### Instance Connections  

```bash
cde.ssm                    # Interactive instance selector
cde.ssm refresh            # Refresh instance cache
cde.ssm show              # Show cached instances
```

### Bastion Tunneling

```bash
cde.tun                    # Interactive tunnel management
cde.tun clean             # Clean all tunnels
```

### Container Registry

```bash
cde.cr login              # Login to ECR (current region)
cde.cr login us-west-2    # Login to specific region
cde.cr                    # Get ECR URL for current profile
```

### Kubernetes Context Management

```bash
cde.k8x                   # Interactive kubernetes context selector
cde.k8x help              # Show k8x help message
```

## Configuration

CDE uses standard cloud CLI configurations:
- AWS: `~/.aws/config` and `~/.aws/credentials`
- GCP: `gcloud config` 
- Azure: `az account`

## Caching

CDE intelligently caches cloud data to improve performance:
- Instance lists are cached per profile
- Cache is automatically invalidated when switching profiles
- Manual cache cleanup with `cde cache.clean`

## Updates

Update CDE to the latest version:
```bash
cde update
```

This will pull the latest changes from the repository and reload the functions.

## Troubleshooting

### Quick Diagnosis
```bash
cde doctor                  # Check all dependencies and installation status
```

### Command not found errors
- Ensure CDE is properly sourced in your shell config (~/.zshenv)
- Verify Go bin directory is in your PATH: `echo $PATH | grep go/bin`
- Reload your shell: `source ~/.zshenv`

### Missing dependencies
- Run `cde doctor` to see what's missing
- Install missing tools: `go install github.com/charmbracelet/gum@latest`

### Cloud CLI issues
- Ensure cloud CLIs are installed and configured
- Check authentication: `aws sts get-caller-identity` (for AWS)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details.
