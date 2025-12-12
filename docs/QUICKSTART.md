# Quick Start Guide

This guide provides detailed prerequisites, setup instructions, and deployment steps for Vibetics CloudEdge.

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| OpenTofu | >= 1.6.0 | Infrastructure as Code |
| Go | >= 1.21 | Terratest integration tests |
| Poetry | >= 1.8.0 | Python dependency management |
| TFLint | Latest | OpenTofu linting |
| gcloud CLI | Latest | GCP authentication and setup |

### Installation

```bash
# OpenTofu
# See: https://opentofu.org/docs/intro/install/

# Go
# See: https://golang.org/doc/install

# Poetry
curl -sSL https://install.python-poetry.org | python3 -

# TFLint
brew install tflint  # macOS
# or
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# After installation, install project dependencies
poetry install
```

## GCP Project Setup

### Enable Required APIs

Before first deployment, enable required GCP APIs:

```bash
source .env
gcloud services enable --project="$TF_VAR_project_id" \
  compute.googleapis.com \
  run.googleapis.com \
  cloudresourcemanager.googleapis.com \
  billingbudgets.googleapis.com \
  cloudbilling.googleapis.com \
  logging.googleapis.com
```

**Required APIs**:

- `compute.googleapis.com` - VPCs, Load Balancers, Firewalls, NEGs
- `run.googleapis.com` - Cloud Run services
- `cloudresourcemanager.googleapis.com` - Project metadata
- `billingbudgets.googleapis.com` - Budget alerts
- `cloudbilling.googleapis.com` - Billing account access
- `logging.googleapis.com` - Cloud Logging

### IAM Roles

The deployment account (user or service account) needs these roles:

| Role | Purpose |
|------|---------|
| `roles/run.admin` | Cloud Run administration |
| `roles/compute.networkAdmin` | Network resources (VPC, subnets, firewall) |
| `roles/compute.securityAdmin` | Cloud Armor WAF policies |
| `roles/compute.loadBalancerAdmin` | Load balancer configuration |
| `roles/iam.serviceAccountUser` | Service account impersonation |
| `roles/billing.user` | Billing budget creation |
| `roles/logging.admin` | Logging bucket management |

**Grant roles to your user account**:

```bash
source .env
ACCOUNT=$(gcloud config get-value account)

for ROLE in run.admin compute.networkAdmin compute.securityAdmin \
  compute.loadBalancerAdmin iam.serviceAccountUser billing.user logging.admin; do
  gcloud projects add-iam-policy-binding $TF_VAR_project_id \
    --member="user:$ACCOUNT" \
    --role="roles/$ROLE"
done
```

**Verify roles are assigned**:

```bash
gcloud projects get-iam-policy $TF_VAR_project_id \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$ACCOUNT" \
  --format="table(bindings.role)"
```

### Configure Application Default Credentials

After granting IAM roles, refresh ADC:

```bash
gcloud auth application-default login
```

## Cloudflare Setup

The core configuration requires Cloudflare for DNS management.

### Create API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Create token with permissions:
   - Zone: DNS: Edit
   - Zone: Zone: Read
3. Save the token securely

### Get Zone ID

1. Go to your domain dashboard in Cloudflare
2. Copy the Zone ID from the right sidebar

### Configure Environment

Add to your `.env` file:

```bash
TF_VAR_cloudflare_api_token="your-api-token"
TF_VAR_cloudflare_zone_id="your-zone-id"
```

## Environment Configuration

Create `.env` from template:

```bash
cp .env.example .env
```

Edit `.env` with your settings:

```bash
# Required - GCP Project
TF_VAR_project_id="your-gcp-project-id"
TF_VAR_project_suffix="nonprod"           # nonprod or prod
TF_VAR_region="northamerica-northeast2"
TF_VAR_cloudedge_github_repository="vibetics-cloudedge"
TF_VAR_billing_account_name="Your Billing Account"

# Required - Cloudflare
TF_VAR_cloudflare_api_token="your-cloudflare-api-token"
TF_VAR_cloudflare_zone_id="your-zone-id"

# Optional
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_logging="true"
TF_VAR_demo_web_app_image="us-docker.pkg.dev/cloudrun/container/hello"
```

## State Backend Setup

Configure GCS backend for remote state storage:

```bash
source .env
./scripts/setup-backend.sh
```

This creates:

- GCS bucket: `${TF_VAR_project_id}-tfstate`
- Backend config files for each configuration
- State prefixes: `${project_id}-singleton`, `demo-web-app`, `${project_id}-core`

## Deployment

### Full Deployment

Deploy all three configurations in order:

```bash
source .env
./scripts/deploy.sh
```

This deploys:

1. `project-singleton` - Billing, logging, API enablement
2. `demo-web-app` - Web VPC, Cloud Run, Internal ALB, PSC producer
3. `core` - Ingress VPC, WAF, External LB, PSC consumer, DNS

### Manual Deployment

Deploy configurations individually:

```bash
source .env

# 1. Project Singleton
cd deploy/opentofu/gcp/project-singleton
tofu init -backend-config=backend-config.hcl
tofu apply

# 2. Demo Web App (requires project-singleton)
cd ../demo-web-app
tofu init -backend-config=backend-config.hcl
tofu apply

# 3. Core (requires demo-web-app)
cd ../core
tofu init -backend-config=backend-config.hcl
tofu apply
```

### Verify Deployment

After deployment:

```bash
# Get the load balancer IP
cd deploy/opentofu/gcp/core
tofu output load_balancer_ip

# Test the endpoint (allow 2-3 minutes for DNS propagation)
curl -k https://demo-web-app.your-domain.com
```

## Teardown

Destroy all infrastructure in reverse order:

```bash
./scripts/teardown.sh
```

Or manually:

```bash
cd deploy/opentofu/gcp/core && tofu destroy
cd ../demo-web-app && tofu destroy
cd ../project-singleton && tofu destroy
```

**Note**: Logging bucket deletion may be delayed 1-7 days by GCP.

## Troubleshooting

### Permission Denied (403)

```
Error: Error creating Network: googleapi: Error 403: Permission denied
```

**Solution**: Refresh Application Default Credentials:

```bash
gcloud auth application-default login
```

### Remote State Not Found

```
Error: Failed to load state: the remote state could not be found
```

**Solution**: Ensure previous configuration is deployed:

```bash
# Check state bucket
gsutil ls gs://${TF_VAR_project_id}-tfstate/

# Deploy in order
cd project-singleton && tofu apply
cd ../demo-web-app && tofu apply
cd ../core && tofu apply
```

### PSC Connection Failed

```
Error: Error creating NetworkEndpointGroup: service attachment not found
```

**Solution**: Verify demo-web-app is deployed and PSC service attachment exists:

```bash
cd deploy/opentofu/gcp/demo-web-app
tofu output web_app_psc_service_attachment_self_link
```

### Cloudflare API Error

```
Error: failed to create DNS record: Invalid API Token
```

**Solution**: Verify Cloudflare credentials:

```bash
# Test API token
curl -X GET "https://api.cloudflare.com/client/v4/zones/$TF_VAR_cloudflare_zone_id" \
  -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" \
  -H "Content-Type: application/json"
```

### Logging Bucket Deletion Delayed

```
Error: Error deleting LogBucketConfig: deletion pending
```

**Solution**: GCP enforces 1-7 day deletion delay for logging buckets. Options:

1. Wait for deletion to complete
2. Set `TF_VAR_enable_logging="false"` for development
3. Manually undelete and re-delete after delay period

## Service Account Setup (CI/CD)

For automated deployments, create a service account:

```bash
source .env

# Create service account
SA_NAME="opentofu-deployer"
SA_EMAIL="${SA_NAME}@${TF_VAR_project_id}.iam.gserviceaccount.com"

gcloud iam service-accounts create $SA_NAME \
  --display-name="OpenTofu Deployment Service Account" \
  --project=$TF_VAR_project_id

# Grant roles
for ROLE in run.admin compute.networkAdmin compute.securityAdmin \
  compute.loadBalancerAdmin iam.serviceAccountUser billing.user logging.admin; do
  gcloud projects add-iam-policy-binding $TF_VAR_project_id \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/$ROLE"
done

# Grant state bucket access
gsutil iam ch "serviceAccount:${SA_EMAIL}:roles/storage.objectAdmin" \
  "gs://${TF_VAR_project_id}-tfstate"

# Create key (for local dev only - use Workload Identity for CI/CD)
gcloud iam service-accounts keys create ~/sa-key.json \
  --iam-account=$SA_EMAIL
chmod 600 ~/sa-key.json

# Use the key
export GOOGLE_APPLICATION_CREDENTIALS=~/sa-key.json
```

## Next Steps

- [Architecture Overview](ARCHITECTURE.md) - Detailed architecture and design decisions
- [Configuration Reference](CONFIGURATION.md) - All configurable variables
- [GCP Resources](GCP.md) - Complete GCP resource reference
- [Security Guide](SECURITY.md) - Threat modeling and security controls
