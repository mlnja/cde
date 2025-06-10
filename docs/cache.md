# Cache Management

## Overview

The cache commands (`cde cache` and `cde cache.clean`) provide persistent data storage and management using the `skate` key-value store. Cache data is organized by cloud environment for efficient management.

## Usage

### View Cache Contents
```bash
# Show cached items for current environment
cde cache
```

### Clean Cache Data
```bash
# Clean cache for current environment  
cde cache.clean
```

## Features

- **Environment-aware Caching**: Separate cache per cloud profile/environment
- **Multi-cloud Support**: Works with AWS, GCP, and Azure environments
- **Interactive Cleanup**: Confirmation prompts before deleting data
- **Organized Storage**: Clear separation between environment-specific and global cache

## Cache Organization

### Environment Keys
Cache keys are prefixed with environment identifiers:
- **AWS**: `aws:{AWS_PROFILE}`
- **GCP**: `gcp:{PROJECT_ID}`  
- **Azure**: `azure:{SUBSCRIPTION_NAME}`

### Cache Types
- **SSM Instances**: `ssm_instances:{env_key}` - Cached cloud instance data
- **Global Cache**: Other application data not tied to specific environments

## Environment Detection

The cache system automatically detects your current cloud environment:

1. **AWS**: Uses `$AWS_PROFILE` environment variable
2. **GCP**: Uses active project from `gcloud config get-value project`
3. **Azure**: Uses active subscription from `az account show`

## Use Cases

### SSM Instance Caching
Most commonly used for caching cloud instance metadata:
```bash
# Cache is populated when running
cde.ssm refresh

# View cached instances
cde cache

# Clean instance cache when switching environments
cde cache.clean
```

### Development Workflow
```bash
# Switch to production profile
cde.p  # Select production AWS profile

# Refresh and cache production instances
cde.ssm refresh

# View production cache
cde cache
# Output: 📦 Cached items for environment: aws:production

# Switch to staging
cde.p  # Select staging profile

# Cache is automatically separated
cde cache  
# Output: 📦 Cached items for environment: aws:staging
```

### Cache Cleanup Scenarios

#### Environment-specific Cleanup
```bash
# Clean only current environment cache
cde cache.clean
# Shows: 🧹 Cleaning cache data for environment: aws:production
# Prompts: Delete cache for this environment? (y/N)
```

#### Global Cleanup (No Environment Set)
```bash
# If no cloud profile is active
cde cache.clean
# Shows: 🧹 No environment detected. Cleaning ALL cache data...
# Prompts: Delete ALL cached data? (y/N)
```

## Storage Backend

### Skate Integration
Uses `skate` for persistent key-value storage:
- **Namespace**: All CDE cache uses `@__mlnj_cde` namespace
- **Persistence**: Data survives terminal sessions and system restarts
- **Cross-session**: Cache accessible across all shell instances

### Data Format
- **Keys**: Namespaced with environment and data type
- **Values**: JSON or text data depending on use case
- **Metadata**: Automatic timestamping and organization

## Command Details

### `cde cache`
- Lists all cache items for current environment
- Shows both environment-specific and global cache
- No-argument command - just displays information
- Returns empty message if no cache exists

### `cde cache.clean`
- Interactive cleanup with confirmation prompts
- Environment-aware - only cleans current environment by default
- Falls back to global cleanup if no environment detected
- Individual key deletion for precise cleanup

## Requirements

- `skate` command-line tool for key-value storage
- Cloud CLI tools for environment detection (aws/gcloud/az)
- `gum` for interactive prompts and styling

## Troubleshooting

### No Cache Items Found
- Cache is empty for current environment
- Run `cde.ssm refresh` to populate instance cache
- Check if correct cloud profile is active

### Environment Not Detected  
- Ensure cloud profile is set with `cde.p`
- Verify cloud CLI tools are installed and configured
- Check environment variables are exported properly

### Cleanup Issues
- Confirm deletion prompts require explicit 'y' response
- Individual key failures won't stop overall cleanup process
- Global cleanup affects all CDE cache data across environments