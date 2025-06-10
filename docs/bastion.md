# Bastion Tunnel Management

## Overview

The bastion command (`cde.tun`) provides secure port forwarding through bastion hosts using AWS SSM tunneling. It creates detached tmux sessions for persistent tunnel connections.

## Usage

```bash
cde.tun
```

## Features

- **Interactive Selection**: Choose from configured bastion targets with fuzzy filtering
- **Tunnel Status**: Real-time status showing running/stopped tunnels  
- **Detached Sessions**: Tunnels run in background tmux sessions
- **Log Management**: View tunnel logs and manage connections
- **Auto-discovery**: Automatically finds bastion instances tagged with `Bastion=true`

## Configuration

Create `~/.cde/config.yml` with bastion target definitions:

```yaml
bastion_targets:
  - profile: "production"
    name: "database"
    host: "prod-db.internal"
    port: "5432:5432"
  - profile: "staging"
    name: "redis"
    host: "stage-redis.internal" 
    port: "6379:6380"
```

### Configuration Fields

- `profile`: AWS profile name the target belongs to
- `name`: Display name for the tunnel
- `host`: Target hostname to connect to through bastion
- `port`: Port mapping in format `remote_port:local_port`

## How It Works

1. **Target Selection**: Lists configured targets for current AWS profile
2. **Instance Discovery**: Finds EC2 instances tagged with `Bastion=true`
3. **Tunnel Creation**: Uses AWS SSM port forwarding to target host
4. **Session Management**: Creates detached tmux session for tunnel
5. **Status Tracking**: Shows tunnel status (running/stopped)

## Tunnel Management

### Starting a Tunnel
- Select target from interactive list
- Tunnel starts in detached tmux session
- Connection details displayed

### Managing Active Tunnels
- **View Logs**: Monitor tunnel connection logs
- **Kill Tunnel**: Stop running tunnel and cleanup

### Session Names
Tunnels use standardized session names: `__mlnj_cde_tun_{profile}_{target_name}`

## Use Cases

### Database Connections
```yaml
# Connect to RDS through bastion
bastion_targets:
  - profile: "prod"
    name: "postgres"
    host: "prod-db.rds.internal"
    port: "5432:5432"
```

### Redis/Cache Access
```yaml
# Connect to ElastiCache through bastion
bastion_targets:
  - profile: "prod" 
    name: "redis"
    host: "prod-cache.elasticache.internal"
    port: "6379:6379"
```

### Web Services
```yaml
# Connect to internal web service
bastion_targets:
  - profile: "dev"
    name: "api"
    host: "internal-api.dev"
    port: "8080:8080"
```

## Requirements

- AWS CLI configured with Session Manager plugin
- EC2 instance tagged with `Bastion=true` 
- Target hosts accessible from bastion instance
- tmux installed for session management
- yq for YAML configuration parsing

## Troubleshooting

### No Bastion Instance Found
- Ensure EC2 instance has tag `Bastion=true`
- Verify instance is running and SSM-enabled
- Check AWS profile has proper permissions

### Tunnel Connection Fails
- Verify target host is reachable from bastion
- Check security groups allow required ports
- Ensure SSM agent is running on bastion

### Configuration Issues
- Validate YAML syntax in config file
- Check profile names match AWS profiles  
- Verify port format is `remote:local`