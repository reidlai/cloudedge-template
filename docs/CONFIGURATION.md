# Configuration Reference

This document covers all configurable variables for the Vibetics CloudEdge infrastructure.

## Environment Variables

Set these in `.env` file (copy from `.env.example`):

```bash
# Required
TF_VAR_project_id="your-gcp-project-id"
TF_VAR_project_suffix="nonprod"           # nonprod or prod
TF_VAR_region="northamerica-northeast2"
TF_VAR_cloudedge_github_repository="vibetics-cloudedge"
TF_VAR_billing_account_name="Your Billing Account"

# Cloudflare (required for DNS)
TF_VAR_cloudflare_api_token="your-cloudflare-api-token"
TF_VAR_cloudflare_zone_id="your-zone-id"

# Optional
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_logging="true"
TF_VAR_demo_web_app_image="us-docker.pkg.dev/cloudrun/container/hello"
```

## Variables by Configuration

### Project Singleton

**Location**: `deploy/opentofu/gcp/project-singleton/variables.tf`

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_suffix` | string | Yes | - | Environment: `nonprod` or `prod` |
| `cloudedge_github_repository` | string | Yes | - | GitHub repo name (used in project_id) |
| `region` | string | Yes | - | GCP region |
| `project_id` | string | Yes | - | GCP project ID |
| `billing_account_name` | string | Yes | - | GCP billing account display name |
| `budget_amount` | number | No | 1000 | Budget amount in HKD |
| `resource_tags` | map(string) | No | See below | Resource labels |
| `enable_logging` | bool | No | true | Create logging bucket |

**Default resource_tags**:

```hcl
{
  "managed-by"     = "opentofu"
  "project-suffix" = "nonprod"
}
```

### Demo VPC

**Location**: `deploy/opentofu/gcp/demo-vpc/variables.tf`

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_suffix` | string | Yes | - | Environment: `nonprod` or `prod` |
| `cloudedge_github_repository` | string | Yes | - | GitHub repo name |
| `region` | string | Yes | - | GCP region |
| `project_id` | string | Yes | - | GCP project ID |
| `resource_tags` | map(string) | No | See above | Resource labels |
| `enable_demo_web_app` | bool | Yes | - | Deploy demo Cloud Run service |
| `web_subnet_cidr_range` | string | No | 10.0.3.0/24 | Web VPC subnet CIDR |
| `proxy_only_subnet_cidr_range` | string | No | 10.0.99.0/24 | Internal ALB proxy subnet |
| `demo_web_app_image` | string | Yes | - | Docker image for Cloud Run |
| `demo_web_app_port` | number | No | 3000 | Container port |

### Core

**Location**: `deploy/opentofu/gcp/core/variables.tf`

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_suffix` | string | Yes | - | Environment: `nonprod` or `prod` |
| `cloudedge_github_repository` | string | Yes | - | GitHub repo name |
| `region` | string | Yes | - | GCP region |
| `project_id` | string | Yes | - | GCP project ID |
| `resource_tags` | map(string) | No | See above | Resource labels |
| `root_domain` | string | No | vibetics.com | Root domain for DNS |
| `demo_web_app_subdomain_name` | string | No | demo-web-app | Subdomain for demo app |
| `allowed_https_source_ranges` | list(string) | No | ["0.0.0.0/0"] | Firewall source IPs |
| `ingress_vpc_cidr_range` | string | No | 10.0.1.0/24 | Ingress VPC subnet |
| `proxy_only_subnet_cidr_range` | string | No | 10.0.98.0/24 | External ALB proxy subnet |
| `enable_demo_web_app` | bool | Yes | - | Create PSC consumer for demo |
| `cloudflare_api_token` | string | Yes | - | Cloudflare API token (sensitive) |
| `cloudflare_zone_id` | string | Yes | - | Cloudflare zone ID |
| `url_map_host_rules` | map(object) | No | {} | Additional host rules |
| `url_map_path_matchers` | map(object) | No | {} | Additional path matchers |

## Feature Flags

| Flag | Configurations | Effect When `true` | Effect When `false` |
|------|---------------|-------------------|---------------------|
| `enable_logging` | project-singleton | Creates logging bucket with 30-day retention | Skips logging bucket |
| `enable_demo_web_app` | demo-vpc, core | Creates all demo resources | Skips demo resources |

### Minimal Deployment (No Demo)

```bash
TF_VAR_enable_demo_web_app="false"
TF_VAR_enable_logging="false"
```

Creates only:

- Billing budget
- Ingress VPC (empty, no backends)
- WAF policy (not attached)

### Full Deployment (Demo Enabled)

```bash
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_logging="true"
```

Creates:

- All project-singleton resources
- Complete demo-vpc with Cloud Run
- Complete core with PSC connectivity
- Cloudflare DNS record

## Network Configuration

### CIDR Ranges

| Subnet | Default CIDR | Configuration | Purpose |
|--------|--------------|---------------|---------|
| Ingress subnet | 10.0.1.0/24 | core | Ingress VPC workloads |
| External proxy-only | 10.0.98.0/24 | core | External ALB proxies |
| Web subnet | 10.0.3.0/24 | demo-vpc | Application workloads |
| Internal proxy-only | 10.0.99.0/24 | demo-vpc | Internal ALB proxies |
| PSC NAT | 10.0.100.0/24 | demo-vpc | PSC NAT translation |

### Firewall Source Ranges

Default: `["0.0.0.0/0"]` (allow all)

For production, restrict to Google Cloud Load Balancer IPs:

```bash
TF_VAR_allowed_https_source_ranges='["35.191.0.0/16","130.211.0.0/22"]'
```

## DNS Configuration

### Cloudflare Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Record type | A | Points to LB IP |
| TTL | 120 seconds | Configurable in code |
| Proxied | false | Direct to GCP (WAF at GCP) |

### Domain Structure

```
root_domain (vibetics.com)
    └── demo_web_app_subdomain_name (demo-web-app)
        = demo-web-app.vibetics.com
```

## Resource Tags

All resources are tagged with mandatory labels:

| Tag | Value | Source |
|-----|-------|--------|
| `managed-by` | opentofu | Default |
| `project-suffix` | nonprod/prod | Variable |
| `project` | ${project_id} | Computed |

Custom tags can be added via `resource_tags` variable:

```hcl
resource_tags = {
  "managed-by"     = "opentofu"
  "project-suffix" = "nonprod"
  "cost-center"    = "engineering"
  "environment"    = "development"
}
```

## Secrets Management

Sensitive variables:

| Variable | Description | Storage Recommendation |
|----------|-------------|----------------------|
| `cloudflare_api_token` | Cloudflare API access | Secret Manager / env |
| GCP credentials | Service account key | Workload Identity / env |

Never commit these to version control. Use:

- Environment variables (local dev)
- GCP Secret Manager (production)
- GitHub Secrets (CI/CD)

## Example Configurations

### Development (Fast Iteration)

```bash
# .env
TF_VAR_project_suffix="nonprod"
TF_VAR_enable_logging="false"          # Skip to avoid deletion delays
TF_VAR_enable_demo_web_app="true"
TF_VAR_demo_web_app_image="gcr.io/cloudrun/hello"
```

### Production

```bash
# .env
TF_VAR_project_suffix="prod"
TF_VAR_enable_logging="true"
TF_VAR_enable_demo_web_app="true"      # Or false if deploying real apps
TF_VAR_allowed_https_source_ranges='["35.191.0.0/16","130.211.0.0/22"]'
TF_VAR_budget_amount="5000"
```

### Testing (Minimal Resources)

```bash
# .env
TF_VAR_project_suffix="nonprod"
TF_VAR_enable_logging="false"
TF_VAR_enable_demo_web_app="false"
```
