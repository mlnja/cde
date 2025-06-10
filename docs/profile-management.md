# Profile Management

## Overview

The profile command (`cde.p`) provides unified cloud profile selection across AWS, GCP, and Azure. It automatically detects available profiles and manages environment variables for seamless multi-cloud operations.

## Usage

```bash
# Interactive profile selection
cde.p
```

## Features

- **Unified Interface**: Single command for all cloud providers
- **Interactive Selection**: Fuzzy filtering for quick profile discovery
- **Environment Isolation**: Automatic cleanup of conflicting cloud variables
- **Auto-Authentication**: Handles SSO login for AWS profiles
- **Profile Detection**: Scans configuration files for available profiles

## Supported Cloud Providers

### AWS
- **Configuration**: `~/.aws/config` profiles
- **Format**: `[profile profile-name]`
- **Authentication**: Automatic SSO login for SSO-enabled profiles
- **Variables**: Sets `AWS_PROFILE` environment variable

### GCP (Planned)
- **Configuration**: `gcloud` configurations
- **Authentication**: Service account or user authentication
- **Variables**: Sets `GOOGLE_CLOUD_PROJECT` environment variables

### Azure (Planned)
- **Configuration**: `az` subscriptions
- **Authentication**: Service principal or user authentication  
- **Variables**: Sets `AZURE_SUBSCRIPTION_ID` environment variables

## Profile Selection Flow

1. **Profile Discovery**: Scans all cloud provider configurations
2. **Unified Display**: Shows all profiles with provider icons
3. **Interactive Filter**: Type to filter profiles by name or provider
4. **Selection**: Choose profile or press Ctrl+C to clear all profiles
5. **Environment Setup**: Sets appropriate environment variables
6. **Authentication**: Handles provider-specific authentication

## Display Format

Profiles are displayed with provider icons and consistent formatting:
```
🟠 aws:production-east
🟠 aws:staging-west  
🔵 gcp:my-project-dev
🔵 gcp:my-project-prod
🟣 azure:subscription-1
🟣 azure:subscription-2
```

## AWS Profile Management

### Configuration Detection
Reads profiles from `~/.aws/config`:
```ini
[profile production]
region = us-east-1
sso_start_url = https://company.awsapps.com/start
sso_region = us-east-1
sso_account_id = 123456789012
sso_role_name = PowerUserAccess

[profile staging]
region = us-west-2
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

### SSO Authentication
For SSO-enabled profiles:
1. **Detection**: Checks for `sso_start_url` or `sso_session` in profile
2. **Login Prompt**: Runs `aws sso login --profile {profile}`
3. **Verification**: Confirms authentication with `aws sts get-caller-identity`
4. **Browser Integration**: Opens browser for SSO authentication

### Environment Variables Set
- `AWS_PROFILE`: Selected profile name
- Cleanup of other cloud provider variables

## Use Cases

### Development Environment Setup
```bash
# Start of work day - select development profile
cde.p
# Choose: 🟠 aws:development

# Work with AWS resources
aws s3 ls
cde.ssm  # Connect to dev instances
cde.cr login  # Login to ECR
```

### Multi-Environment Workflows
```bash
# Deploy to staging
cde.p  # Select: 🟠 aws:staging
./deploy.sh staging

# Deploy to production  
cde.p  # Select: 🟠 aws:production
./deploy.sh production
```

### Profile Switching
```bash
# Current work in development
export AWS_PROFILE=development

# Quick switch for admin task
cde.p  # Select: 🟠 aws:admin
aws iam list-users

# Return to development work
cde.p  # Select: 🟠 aws:development
```

### Clear All Profiles
```bash
# Press Ctrl+C during selection to clear all profiles
cde.p
# [Ctrl+C pressed]
# Output: ⚠️ No profile selected - cleaning all profiles

# Verify all cloud variables are cleared
env | grep -E "(AWS|GOOGLE|AZURE)"
# No output - all cleared
```

## Environment Variable Management

### Cleanup Process
Before setting new profile, cleans all cloud provider variables:

**AWS Variables Cleared:**
- `AWS_PROFILE`
- `AWS_DEFAULT_PROFILE`  
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `AWS_REGION`
- `AWS_DEFAULT_REGION`

**GCP Variables Cleared:**
- `GOOGLE_APPLICATION_CREDENTIALS`
- `GCLOUD_PROJECT`
- `GOOGLE_CLOUD_PROJECT`

**Azure Variables Cleared:**
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

### Isolation Benefits
- Prevents credential conflicts between providers
- Ensures clean environment for each profile
- Avoids accidental cross-cloud operations

## Provider Integration

### AWS Provider (`p/providers/aws.zsh`)
- **Profile Listing**: Parses `~/.aws/config` for profile entries
- **Authentication**: Handles SSO login and credential validation
- **Environment Setup**: Sets AWS-specific variables

### Future Providers
- **GCP Provider**: `gcloud config configurations list` integration
- **Azure Provider**: `az account list` integration
- **Custom Providers**: Extensible provider system

## Requirements

### AWS
- AWS CLI installed and configured
- `~/.aws/config` file with profile definitions
- For SSO profiles: Browser access for authentication

### General
- `gum` for interactive selection interface
- Provider-specific CLI tools (aws, gcloud, az)
- Proper file permissions on configuration files

## Troubleshooting

### No Profiles Found
```
❌ No cloud profiles found
```
**Solutions:**
- Verify AWS config file exists: `~/.aws/config`
- Check profile format: `[profile name]`
- Install and configure cloud CLI tools

### AWS SSO Login Failed  
```
❌ AWS authentication failed
```
**Solutions:**
- Check SSO configuration in profile
- Verify network connectivity to SSO URL
- Ensure browser can open for authentication
- Check SSO session hasn't expired

### Profile Not Switching
**Solutions:**
- Verify profile was selected (not cancelled)
- Check shell environment variables: `echo $AWS_PROFILE`
- Restart shell if environment seems stuck
- Run `cde.p` again to re-select profile

### Permission Denied on Config Files
**Solutions:**
- Check file permissions: `ls -la ~/.aws/config`
- Ensure proper ownership of AWS config directory
- Verify no conflicting environment variables

## Integration with Other Commands

Profile selection affects all other CDE commands:
- **SSM**: `cde.ssm` uses active profile for instance discovery
- **Cache**: `cde cache` organizes data by profile
- **Bastion**: `cde.tun` uses profile for tunnel configuration
- **Container Registry**: `cde.cr` uses profile for registry authentication