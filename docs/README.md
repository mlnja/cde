# CDE Documentation

## Overview

CDE (Cloud DevEx) is a beautiful collection of cloud utilities for your terminal with oh-my-zsh integration. It provides unified interfaces for managing cloud profiles, connecting to instances, and working with container registries across AWS, GCP, and Azure.

## Quick Reference

| Command | Description | Usage |
|---------|-------------|-------|
| `cde.p` | Select cloud profile | Interactive profile selection |
| `cde.ssm` | Connect to cloud instances | Instance connection with caching |
| `cde.tun` | Bastion tunnel management | Port forwarding through bastions |
| `cde.cr` | Container registry login | ECR/GCR/ACR authentication |
| `cde cache` | View cache contents | Show cached data by environment |
| `cde cache.clean` | Clean cache data | Remove cached data for environment |

## Command Documentation

### Core Commands

#### [Profile Management (`cde.p`)](./profile-management.md)
Unified cloud profile selection across AWS, GCP, and Azure with automatic authentication and environment variable management.

```bash
cde.p  # Interactive profile selection
```

#### [SSM Connections (`cde.ssm`)](./ssm-connections.md)
Connect to cloud instances using secure, cloud-native methods with intelligent caching and multi-cloud support.

```bash
cde.ssm           # Connect to instance
cde.ssm refresh   # Refresh instance cache
cde.ssm show      # Show instances table
```

#### [Bastion Tunnels (`cde.tun`)](./bastion.md)
Secure port forwarding through bastion hosts with persistent tmux sessions and automatic instance discovery.

```bash
cde.tun  # Interactive tunnel management
```

#### [Container Registry (`cde.cr`)](./container-registry.md)
Automated login to cloud container registries with profile-aware authentication.

```bash
cde.cr login         # Login to current profile's registry
cde.cr login region  # Login to specific region
```

#### [Cache Management (`cde cache`)](./cache.md)
Persistent data storage and management with environment-aware organization.

```bash
cde cache        # Show cached data
cde cache.clean  # Clean cache for environment
```

## Workflow Examples

### Daily Development Setup
```bash
# 1. Select development profile
cde.p  # Choose: 🟠 aws:development

# 2. Connect to development instance
cde.ssm  # Select: web-server-dev

# 3. Login to container registry
cde.cr login
```

### Multi-Environment Deployment
```bash
# Deploy to staging
cde.p  # Select: 🟠 aws:staging
cde.cr login
docker push staging-registry/app:latest

# Deploy to production
cde.p  # Select: 🟠 aws:production  
cde.cr login
docker push prod-registry/app:latest
```

### Infrastructure Debugging
```bash
# Set profile and refresh instance cache
cde.p  # Select environment
cde.ssm refresh  # Get latest instances

# View all instances
cde.ssm show

# Connect to problematic instance
cde.ssm  # Interactive selection

# Setup tunnel for database access
cde.tun  # Select database tunnel
```

## Features

### 🎨 Beautiful UI
- Interactive selection with fuzzy filtering
- Colorful terminal output with icons
- Formatted tables and status displays
- Consistent visual design across commands

### 💾 Intelligent Caching
- Environment-aware data organization
- Persistent storage across sessions
- Automatic cache refresh when needed
- Easy cache management and cleanup

### 🌥️ Multi-Cloud Support
- **AWS**: Full support for EC2, SSM, ECR
- **GCP**: Planned support for Compute Engine, GCR
- **Azure**: Planned support for VMs, ACR
- Unified interface across all providers

### 🔒 Secure Connections
- Cloud-native authentication methods
- No SSH key management required
- Audit trail through cloud providers
- Network isolation compatible

### ⚡ Performance Optimized
- Lazy loading of commands
- Efficient caching strategies
- Minimal API calls
- Fast interactive responses

## Architecture

### Plugin Structure
```
cde/
├── cde.plugin.zsh           # Main plugin entry point
├── bastion/
│   └── command.zsh          # Tunnel management
├── cache/
│   └── command.zsh          # Cache operations
├── cr/
│   └── command.zsh          # Container registry
├── p/
│   ├── command.zsh          # Profile management
│   └── providers/
│       ├── aws.zsh          # AWS profile provider
│       ├── gcp.zsh          # GCP profile provider
│       └── azure.zsh        # Azure profile provider
├── ssm/
│   ├── command.zsh          # Instance connections
│   └── providers/
│       ├── aws.zsh          # AWS SSM provider
│       ├── gcp.zsh          # GCP SSH provider
│       └── azure.zsh        # Azure SSH provider
└── docs/                    # Documentation
```

### Lazy Loading
Commands are loaded on-demand for optimal shell startup performance:
- Plugin initialization is minimal
- Individual commands loaded when first used
- Provider modules loaded per cloud type
- Efficient memory usage

### Provider System
Extensible architecture for cloud providers:
- Consistent interface across providers
- Independent implementation per cloud
- Easy addition of new cloud providers
- Shared utilities and caching

## Requirements

### Core Dependencies
- **oh-my-zsh**: Plugin framework
- **gum**: Beautiful terminal UI components
- **skate**: Key-value storage for caching
- **yq**: YAML processing for configuration

### Cloud CLI Tools
- **AWS**: `aws` CLI with Session Manager plugin
- **GCP**: `gcloud` CLI (planned)
- **Azure**: `az` CLI (planned)

### System Tools
- **tmux**: Session management for tunnels
- **jq**: JSON processing
- **docker**: Container operations

## Installation

```bash
# Install CDE plugin
curl -fsSL https://raw.githubusercontent.com/mlnja/cde/main/install.sh | bash

# Add to oh-my-zsh plugins
# Edit ~/.zshrc
plugins=(... cde)

# Reload shell
source ~/.zshrc
```

## Configuration

### AWS Setup
Configure AWS profiles in `~/.aws/config`:
```ini
[profile production]
region = us-east-1
sso_start_url = https://company.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = PowerUserAccess
```

### Bastion Configuration
Create `~/.cde/config.yml` for tunnel targets:
```yaml
bastion_targets:
  - profile: "production"
    name: "database"
    host: "prod-db.internal"
    port: "5432:5432"
```

## Support

- **Documentation**: Individual command docs in this directory
- **Issues**: Report bugs and feature requests on GitHub
- **Updates**: Use `cde update` to get latest version

## Roadmap

### Current Features (✅)
- AWS profile management with SSO support
- AWS EC2 instance connections via SSM
- AWS ECR container registry login
- Bastion tunnel management for AWS
- Intelligent caching system
- Beautiful terminal UI

### Planned Features (🚧)
- GCP profile and instance support
- Azure profile and VM support
- GCP Container Registry support
- Azure Container Registry support
- Configuration file management
- Plugin marketplace integration

### Future Enhancements (💭)
- Multi-cluster Kubernetes support
- Database connection management
- Secret management integration
- Infrastructure as Code integration
- Team collaboration features