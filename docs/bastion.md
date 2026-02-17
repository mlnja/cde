# Bastion Tunnel Management

## Overview

The bastion command (`cde.tun`) provides secure port forwarding through bastion hosts using AWS SSM tunneling. It creates detached tmux sessions for persistent tunnel connections.

## Usage

### Interactive Mode
```bash
cde.tun                              # Interactive tunnel management (uses current AWS_PROFILE)
cde.tun --profile <profile>          # Interactive mode with specific AWS profile
```

### Non-Interactive Mode (for automation/scripts)
```bash
cde.tun <target>                     # Start tunnel with current AWS_PROFILE
cde.tun <target> --profile <profile> # Start tunnel with specific AWS profile
```

### Other Commands
```bash
cde.tun clean                        # Stop all active tunnel sessions
cde.tun help                         # Show help message
```

## Features

- **Interactive Selection**: Choose from configured bastion targets with fuzzy filtering
- **Non-Interactive Mode**: Start tunnels directly by target name for automation
- **Profile Override**: Use `--profile` flag to override current AWS profile
- **Tunnel Status**: Real-time status showing running/stopped tunnels
- **Detached Sessions**: Tunnels run in background tmux sessions
- **Log Management**: View tunnel logs and manage connections
- **Auto-discovery**: Automatically finds bastion instances tagged with `Bastion=true`
- **Bulk Cleanup**: Clean all active tunnel sessions with `clean` command

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

**Interactive Mode:**
- Run `cde.tun` to see all configured targets for current profile
- Select target from interactive list with fuzzy filtering
- Tunnel starts in detached tmux session
- Connection details displayed

**Non-Interactive Mode (for scripts/automation):**
- Run `cde.tun <target> --profile <profile>` to start tunnel directly
- Checks if tunnel is already running (exits with warning if so)
- Verifies target exists in config for the specified profile
- Starts tunnel automatically without user interaction
- Ideal for use in Python scripts, Makefiles, or CI/CD pipelines

### Managing Active Tunnels
- **View Logs**: Monitor tunnel connection logs
- **Kill Tunnel**: Stop running tunnel and cleanup

### Session Names
Tunnels use standardized session names: `__mlnj_cde_tun_{profile}_{target_name}`

### Cleaning All Tunnels
Use `cde.tun clean` to:
- Find all active tunnel sessions across all profiles
- Display summary of running tunnels
- Prompt for confirmation before cleanup
- Kill all tunnel sessions and remove log files

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

### Automation/Scripting Example
```bash
#!/bin/bash
# Start tunnel in non-interactive mode
cde.tun postgres --profile prod-rootio

# Wait for tunnel to establish
sleep 3

# Use the tunnel
psql -h localhost -p 5432 -U user -d database

# Note: Tunnel remains running in background tmux session
# Use 'cde.tun clean' or 'cde.tun' (interactive) to stop it
```

```python
# Python script example (from data copy system)
import subprocess

def ensure_tunnel(target: str, profile: str):
    """Start tunnel if not already running."""
    result = subprocess.run(
        ["cde.tun", target, "--profile", profile],
        capture_output=True,
        text=True
    )
    if "already running" in result.stdout:
        print(f"Tunnel {target} already active")
    elif result.returncode == 0:
        print(f"Tunnel {target} started successfully")
    else:
        raise RuntimeError(f"Failed to start tunnel: {result.stderr}")
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