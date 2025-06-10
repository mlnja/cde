# Container Registry Login

## Overview

The container registry command (`cde.cr`) provides automated login functionality for cloud container registries. Currently supports AWS ECR with planned support for GCP and Azure registries.

## Usage

```bash
# Get registry URL (stdout only) 
cde.cr

# Get registry URL for specific region
cde.cr us-west-2

# Login to container registry for current cloud profile
cde.cr login

# Login to specific AWS region
cde.cr login us-west-2
```

## Features

- **Registry URL Output**: Get registry URL for Docker commands (stdout only)
- **Multi-cloud Support**: Detects active cloud profile automatically
- **AWS ECR Integration**: Full support for Elastic Container Registry login
- **Regional Flexibility**: Override default region for AWS ECR
- **Automatic Authentication**: Handles credential management and Docker login
- **Profile Awareness**: Uses current cloud profile settings
- **Command Substitution**: Perfect for use in Docker build/push commands

## Cloud Provider Support

### AWS ECR (Fully Supported)
- Automatic account ID and region detection
- ECR registry URL generation
- Docker credential helper integration
- Support for custom regions

### GCP Container Registry (Planned)
- Google Container Registry (GCR) support
- Artifact Registry integration  
- Service account authentication

### Azure Container Registry (Planned)
- Azure Container Registry (ACR) login
- Resource group awareness
- Managed identity support

## AWS ECR Usage

### Get Registry URL
```bash
# Set AWS profile first
cde.p  # Select AWS profile

# Get registry URL for current region
cde.cr
# Output: 123456789.dkr.ecr.us-east-1.amazonaws.com

# Get registry URL for specific region
cde.cr eu-west-1
# Output: 123456789.dkr.ecr.eu-west-1.amazonaws.com
```

### Command Substitution Examples
```bash
# Build with dynamic registry URL
docker build -t $(cde.cr)/my/image:tag .

# Build for specific region
docker build -t $(cde.cr us-west-2)/my/image:tag .

# Push to current profile's registry
docker push $(cde.cr)/my/image:tag

# Tag and push in one line
docker tag myapp:latest $(cde.cr)/myapp:latest && docker push $(cde.cr)/myapp:latest
```

### Login Operations
```bash
# Login to ECR in profile's default region
cde.cr login

# Login to specific region
cde.cr login eu-west-1

# Login to multiple regions
cde.cr login us-east-1
cde.cr login us-west-2
```

### Complete Workflow Example
```bash
# Set profile and login
cde.p                    # Select AWS profile: production
cde.cr login            # Login to ECR

# Build and push with command substitution
docker build -t $(cde.cr)/myapp:latest .
docker push $(cde.cr)/myapp:latest

# Or with specific region
docker build -t $(cde.cr us-west-2)/myapp:v1.0 .
docker push $(cde.cr us-west-2)/myapp:v1.0
```

## How It Works

### Registry URL Output
1. **Profile Detection**: Verifies AWS profile is set
2. **Account Information**: Gets AWS account ID via STS (silently)
3. **Region Resolution**: Uses AWS_REGION, AWS_DEFAULT_REGION, or profile default
4. **Registry URL**: Constructs ECR URL: `{account}.dkr.ecr.{region}.amazonaws.com`
5. **Output**: URL to stdout, help/examples to stderr

### AWS ECR Login Process
1. **Profile Detection**: Verifies AWS profile is set
2. **Account Information**: Gets AWS account ID via STS
3. **Region Resolution**: Uses AWS_REGION, AWS_DEFAULT_REGION, or profile default
4. **Registry URL**: Constructs ECR URL: `{account}.dkr.ecr.{region}.amazonaws.com`
5. **Authentication**: Gets login token and authenticates Docker
6. **Confirmation**: Displays successful login message

### Region Priority
1. Command line argument (highest priority)
2. `AWS_REGION` environment variable
3. `AWS_DEFAULT_REGION` environment variable  
4. AWS profile configured region
5. Error if no region found

## Registry URL Formats

### AWS ECR
```
{account-id}.dkr.ecr.{region}.amazonaws.com
```
Example: `123456789012.dkr.ecr.us-east-1.amazonaws.com`

### GCP (Future)
```
gcr.io/{project-id}
{region}-docker.pkg.dev/{project-id}/{repository}
```

### Azure (Future)  
```
{registry-name}.azurecr.io
```

## Use Cases

### CI/CD Pipeline Integration
```bash
#!/bin/bash
# Deploy script with dynamic registry URL
cde.p  # Select environment profile
cde.cr login

# Build and push using command substitution
docker build -t $(cde.cr)/$IMAGE_NAME:$BUILD_TAG .
docker push $(cde.cr)/$IMAGE_NAME:$BUILD_TAG
```

### Local Development
```bash
# Pull private images for development
cde.p  # Select dev profile
cde.cr login

# Pull using dynamic registry URL
docker pull $(cde.cr)/base-image:latest
```

### Multi-Region Deployment
```bash
# Push to multiple regions using command substitution
for region in us-east-1 us-west-2 eu-west-1; do
  cde.cr login $region
  docker tag myapp:latest $(cde.cr $region)/myapp:latest
  docker push $(cde.cr $region)/myapp:latest
done
```

### Makefile Integration
```makefile
# Use in Makefiles
REGISTRY := $(shell cde.cr)
IMAGE_NAME := myapp
TAG := latest

build:
	docker build -t $(REGISTRY)/$(IMAGE_NAME):$(TAG) .

push: build
	docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

.PHONY: build push
```

## Requirements

### AWS ECR
- AWS CLI configured and authenticated
- Docker installed and running
- Appropriate ECR permissions:
  - `ecr:GetAuthorizationToken`
  - `ecr:BatchCheckLayerAvailability`
  - `ecr:GetDownloadUrlForLayer`
  - `ecr:BatchGetImage`

### General
- Active cloud profile set via `cde.p`
- Container registry permissions for target repositories
- Network connectivity to registry endpoints

## Troubleshooting

### No Cloud Profile Set
```
❌ No cloud profile set. Use 'cde.p' to select a profile first.
```
**Solution**: Run `cde.p` to select an active cloud profile

### AWS Account ID Retrieval Failed
```
❌ Failed to get AWS account ID. Check your AWS credentials.
```
**Solution**: Verify AWS credentials and permissions

### No Region Configured
```
❌ No AWS region configured. Set AWS_REGION or configure default region.
```
**Solution**: Set region via environment variable or AWS profile

### Docker Login Failed
```  
❌ Failed to login to ECR registry
```
**Solution**: Check Docker daemon is running and ECR permissions

### ECR Registry Access Denied
**Solution**: Verify ECR repository exists and IAM permissions are correct

## Future Enhancements

- GCP Container Registry and Artifact Registry support
- Azure Container Registry integration
- Multi-registry login in single command
- Registry configuration caching
- Custom registry endpoint support