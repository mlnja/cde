# SSM Instance Connections

## Overview

The SSM command (`cde.ssm`) provides unified cloud instance connection functionality across AWS, GCP, and Azure. It manages instance discovery, caching, and secure connections using cloud-native tools.

## Usage

```bash
# Connect to instance (interactive selection)
cde.ssm

# Refresh instance cache
cde.ssm refresh

# Show instances in table format
cde.ssm show
```

## Features

- **Multi-cloud Support**: Works with AWS EC2, GCP Compute Engine, Azure VMs
- **Interactive Selection**: Fuzzy filtering for quick instance discovery
- **Intelligent Caching**: Environment-aware instance caching
- **Beautiful Tables**: Formatted instance information display
- **Secure Connections**: Uses cloud-native connection methods (SSM, SSH, etc.)
- **Real-time Status**: Shows instance state and connectivity

## Cloud Provider Support

### AWS EC2 (Fully Supported)
- **Connection Method**: AWS Systems Manager Session Manager
- **Discovery**: EC2 instances with SSM agent enabled
- **Requirements**: Instance must be online in SSM
- **Authentication**: Uses current AWS profile credentials

### GCP Compute Engine (Planned)
- **Connection Method**: Cloud SSH with IAP tunneling
- **Discovery**: Compute Engine instances in current project
- **Requirements**: OS Login API enabled
- **Authentication**: Uses gcloud credentials

### Azure VMs (Planned)
- **Connection Method**: Azure Bastion or SSH
- **Discovery**: Virtual machines in current subscription
- **Requirements**: Azure CLI authentication
- **Authentication**: Uses az credentials

## Command Actions

### Connect (`cde.ssm` or `cde.ssm connect`)
Interactive instance selection and connection:
1. **Cache Check**: Looks for cached instances for current environment
2. **Auto-refresh**: Automatically refreshes if no cache found
3. **Interactive Selection**: Fuzzy search through available instances
4. **Connection**: Establishes secure connection to selected instance

### Refresh (`cde.ssm refresh`)
Updates instance cache for current environment:
1. **Environment Detection**: Identifies current cloud profile
2. **Instance Discovery**: Queries cloud APIs for running instances
3. **Data Processing**: Formats and enriches instance metadata
4. **Cache Storage**: Stores results in environment-specific cache

### Show (`cde.ssm show`)
Displays cached instances in formatted table:
1. **Cache Retrieval**: Gets cached instance data
2. **Table Generation**: Creates formatted ASCII table
3. **Provider-specific**: Adapts columns based on cloud provider
4. **Status Display**: Shows connection readiness

## Instance Discovery

### AWS EC2 Process
1. **EC2 Query**: Gets all running instances with metadata
2. **SSM Filter**: Checks SSM connectivity status
3. **Tag Processing**: Extracts Name tags and other metadata
4. **JSON Output**: Formats as single-line JSON records

### Data Format
Each cached instance includes:
```json
{
  "instanceId": "i-1234567890abcdef0",
  "instanceType": "t3.medium",
  "privateIp": "10.0.1.100",
  "publicIp": "54.123.45.67",
  "name": "web-server-01",
  "tags": [...],
  "bastion": "false"
}
```

## Caching System

### Environment-based Organization
Cache keys use environment prefixes:
- **AWS**: `ssm_instances:aws:{AWS_PROFILE}`
- **GCP**: `ssm_instances:gcp:{PROJECT_ID}`
- **Azure**: `ssm_instances:azure:{SUBSCRIPTION_NAME}`

### Cache Lifecycle
1. **Population**: `cde.ssm refresh` discovers and caches instances
2. **Usage**: `cde.ssm` and `cde.ssm show` read from cache
3. **Auto-refresh**: Automatic refresh if cache is empty
4. **Cleanup**: `cde cache.clean` removes environment-specific cache

### Performance Benefits
- **Fast Selection**: No API calls during instance selection
- **Offline Browsing**: View instances without network connectivity
- **Reduced API Usage**: Minimizes cloud API rate limiting

## Interactive Selection

### Display Format
Instances shown in formatted table columns:
```
💻 i-1234567890abcdef0  │ web-server-01                    │ t3.medium        │ 10.0.1.100
💻 i-0987654321fedcba0  │ database-primary                 │ t3.large         │ 10.0.1.200
💻 i-abcdef1234567890  │ api-gateway                      │ t3.small         │ 10.0.1.50
```

### Fuzzy Filtering
Type to filter instances by:
- Instance ID
- Instance name
- Instance type
- IP addresses

### Selection Process
1. **Filter**: Type search terms to narrow results
2. **Navigate**: Use arrow keys to select instance
3. **Connect**: Press Enter to establish connection
4. **Cancel**: Press Ctrl+C to exit without connecting

## Connection Methods

### AWS SSM Session Manager
```bash
# Direct SSM connection
aws ssm start-session --target i-1234567890abcdef0
```

**Benefits:**
- No SSH keys required
- No bastion hosts needed
- Audit trail in CloudTrail
- Network isolation compatible

**Requirements:**
- SSM agent on instance
- IAM permissions for Session Manager
- Instance connectivity to SSM endpoints

### Future Connection Methods

**GCP Cloud SSH:**
```bash
# Cloud SSH with IAP
gcloud compute ssh instance-name --zone=zone --tunnel-through-iap
```

**Azure SSH:**
```bash
# Azure CLI SSH
az ssh vm --resource-group rg-name --name vm-name
```

## Table Display

### AWS EC2 Table
```
🖥️  Cloud Instances - aws:production
┌─────────────────────┬──────────────────────────────────┬─────────────────┬─────────────────┐
│ Instance ID         │ Name                             │ Type            │ Private IP      │
├─────────────────────┼──────────────────────────────────┼─────────────────┼─────────────────┤
│ i-1234567890abcdef0 │ web-server-01                    │ t3.medium       │ 10.0.1.100      │
│ i-0987654321fedcba0 │ database-primary                 │ t3.large        │ 10.0.1.200      │
└─────────────────────┴──────────────────────────────────┴─────────────────┴─────────────────┘
```

### Provider-specific Columns
- **AWS**: Instance ID, Name, Type, Private IP
- **GCP**: Instance Name, Display Name, Type, Zone, Private IP
- **Azure**: VM Name, Display Name, Size, Resource Group, Private IP

## Use Cases

### Daily Development Workflow
```bash
# Start of day - set profile and connect
cde.p                # Select: 🟠 aws:development
cde.ssm              # Interactive: Select web-server-dev
# Connected to instance for debugging
```

### Infrastructure Inspection
```bash
# View all instances in environment
cde.ssm show
# Review instance inventory and status

# Connect to specific instance for maintenance
cde.ssm              # Select database server
```

### Multi-Environment Operations
```bash
# Check production instances
cde.p                # Select: 🟠 aws:production  
cde.ssm show         # Review production infrastructure

# Switch to staging for testing
cde.p                # Select: 🟠 aws:staging
cde.ssm              # Connect to staging instance
```

### Cache Management
```bash
# Force refresh instance list
cde.ssm refresh      # Update cache with latest instances

# Clear cache when switching environments
cde cache.clean      # Clean environment-specific cache
```

## Error Handling

### No Instances Found
```
⚠️ No SSM instances found for this environment
```
**Solutions:**
- Verify instances are running
- Check SSM agent is installed and running
- Confirm IAM permissions for SSM
- Ensure network connectivity to SSM endpoints

### Instance Not SSM-Accessible
```
❌ Instance i-1234567890abcdef0 is not SSM-accessible (status: Unknown)
```
**Solutions:**
- Check SSM agent status on instance
- Verify instance IAM role has SSM permissions
- Confirm VPC endpoints or internet access for SSM

### Authentication Required
```
❌ AWS authentication required. Please run cde.p first.
```
**Solutions:**
- Run `cde.p` to select valid cloud profile
- Verify cloud CLI authentication
- Check profile credentials are valid

### Connection Failed
```
💡 Connection failed. Try refreshing the instance list:
   cde.ssm refresh
```
**Solutions:**
- Refresh instance cache for latest status
- Verify instance is still running
- Check network connectivity
- Confirm security group allows SSM traffic

## Requirements

### AWS Support
- AWS CLI with Session Manager plugin
- `jq` for JSON processing
- Appropriate IAM permissions:
  - `ec2:DescribeInstances`
  - `ssm:DescribeInstanceInformation`
  - `ssm:StartSession`

### General Requirements
- Active cloud profile set via `cde.p`
- `skate` for caching
- `gum` for interactive interface
- Network connectivity to cloud APIs

## Integration

### With Other CDE Commands
- **Profile**: Uses active profile from `cde.p`
- **Cache**: Stores data accessible via `cde cache`
- **Bastion**: Instance data used by `cde.tun` for bastion discovery

### Provider Architecture
Extensible provider system in `ssm/providers/`:
- `aws.zsh`: AWS EC2 and SSM integration
- `gcp.zsh`: Future GCP Compute Engine support
- `azure.zsh`: Future Azure VM support

## Troubleshooting

### Stale Cache Data
**Problem**: Instance list shows terminated instances
**Solution**: Run `cde.ssm refresh` to update cache

### Performance Issues
**Problem**: Slow instance discovery
**Solution**: Instance data is cached; only refresh when needed

### Provider Detection Failed
**Problem**: Command doesn't detect cloud environment
**Solution**: Ensure cloud profile is set with `cde.p`

### Missing Dependencies
**Problem**: Commands fail with missing tool errors
**Solution**: Install required tools (aws cli, jq, skate, gum)