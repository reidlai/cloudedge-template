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

# Cloudflare Origin CA Key (required when enable_cloudflare_proxy = true)
TF_VAR_cloudflare_origin_ca_key="your-origin-ca-key"

# Feature Flags
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_logging="true"
TF_VAR_enable_cloudflare_proxy="true"    # Enable Cloudflare WAF (free)
TF_VAR_enable_waf="false"                # Enable GCP Cloud Armor ($16-91/mo)
TF_VAR_enable_self_signed_cert="false"   # Use self-signed certs (testing only)

# Optional
TF_VAR_demo_web_app_image="us-docker.pkg.dev/cloudrun/container/hello"
```

## Variables by Configuration

### Project Singleton

**Location**: `deploy/opentofu/gcp/project-singleton/variables.tf`

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_suffix` | string | Yes | - | Environment: `nonprod` or `prod` (validated) |
| `cloudedge_github_repository` | string | Yes | - | GitHub repo name (used in project_id) |
| `region` | string | Yes | `northamerica-northeast2` | GCP region for regional resources |
| `project_id` | string | Yes | - | GCP project ID (format: `vibetics-cloudedge-{suffix}`) |
| `billing_account_name` | string | Yes | - | GCP billing account display name |
| `budget_amount` | number | No | 1000 | Budget amount in HKD with alerts at 50%, 80%, 100% |
| `resource_tags` | map(string) | No | See below | Resource labels (FR-007 compliance) |
| `enable_logging` | bool | No | true | Create centralized logging bucket (30-day retention) |
| `enable_self_signed_cert` | bool | No | false | Use self-signed cert instead of Google-managed |
| `demo_web_app_subdomain_name` | string | No | `demo-web-app` | Subdomain for demo app |
| `root_domain` | string | No | `vibetics.com` | Root domain for DNS |
| `cloudflare_api_token` | string (sensitive) | Yes | - | Cloudflare API token for DNS operations |

**Default resource_tags**:

```hcl
{
  "managed-by"     = "opentofu"
  "project-suffix" = "nonprod"
}
```

**Note**: Tags must include `project-suffix` and `managed-by` keys (validated).

### Demo Web App

**Location**: `deploy/opentofu/gcp/demo-web-app/variables.tf`

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_suffix` | string | Yes | - | Environment: `nonprod` or `prod` (validated) |
| `cloudedge_github_repository` | string | Yes | - | GitHub repo name |
| `region` | string | Yes | - | GCP region |
| `project_id` | string | Yes | - | GCP project ID |
| `resource_tags` | map(string) | No | See above | Resource labels (FR-007 compliance) |
| `enable_demo_web_app` | bool | Yes | - | Deploy demo Cloud Run service and all backend resources |
| `web_subnet_cidr_range` | string | No | `10.0.3.0/24` | Web VPC subnet CIDR (must not overlap) |
| `proxy_only_subnet_cidr_range` | string | No | `10.0.99.0/24` | Internal ALB proxy subnet CIDR |
| `psc_nat_subnet_cidr_range` | string | No | `10.0.100.0/24` | PSC NAT subnet CIDR (used when `enable_psc=true`) |
| `demo_web_app_image` | string | Yes | - | Docker image for Cloud Run (e.g., gcr.io/cloudrun/hello) |
| `demo_web_app_port` | number | No | 3000 | Container port for Cloud Run service |
| **`enable_demo_web_app_psc_neg`** | **bool** | **No** | **false** | **Enable Private Service Connect Network Endpoint Group (PSC NEG) for cross-project isolation** |
| **`enable_demo_web_app_internal_alb`** | **bool** | **No** | **true** | **Enable Internal Application Load Balancer** |
| `demo_web_app_web_vpc_name` | string | No | `demo-web-app-web-vpc` | Name of the Web VPC |
| `demo_web_app_web_subnet_cidr_range` | string | No | `10.0.3.0/24` | Web subnet CIDR range |
| `demo_web_app_proxy_only_subnet_cidr_range` | string | No | `10.0.99.0/24` | Proxy-only subnet CIDR for Internal ALB |
| `demo_web_app_psc_nat_subnet_cidr_range` | string | No | `10.0.100.0/24` | PSC NAT subnet CIDR (used when PSC NEG enabled) |

### Core

**Location**: `deploy/opentofu/gcp/core/variables.tf`

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_suffix` | string | Yes | - | Environment: `nonprod` or `prod` (validated) |
| `cloudedge_github_repository` | string | Yes | - | GitHub repo name |
| `region` | string | Yes | - | GCP region |
| `project_id` | string | Yes | - | GCP project ID |
| `resource_tags` | map(string) | No | See above | Resource labels (FR-007 compliance) |
| `root_domain` | string | No | `vibetics.com` | Root domain for DNS |
| `demo_web_app_subdomain_name` | string | No | `demo-web-app` | Subdomain for demo app |
| `allowed_https_source_ranges` | list(string) | No | `["0.0.0.0/0"]` | Firewall source IPs (when Cloudflare proxy disabled) |
| `ingress_vpc_cidr_range` | string | No | `10.0.1.0/24` | Ingress VPC subnet CIDR |
| `proxy_only_subnet_cidr_range` | string | No | `10.0.98.0/24` | External ALB proxy subnet CIDR |
| `enable_demo_web_app` | bool | Yes | - | Create PSC consumer and backend for demo app |
| `enable_self_signed_cert` | bool | No | false | Use self-signed certificates (testing only) |
| `cloudflare_api_token` | string (sensitive) | Yes | - | Cloudflare API token for DNS operations |
| `cloudflare_origin_ca_key` | string (sensitive) | No | `""` | Cloudflare Origin CA Key (required when `enable_cloudflare_proxy = true`) |
| `cloudflare_zone_id` | string | Yes | - | Cloudflare zone ID for DNS management |
| `url_map_host_rules` | map(object) | No | `{}` | Additional host-based routing rules (future extensibility) |
| `url_map_path_matchers` | map(object) | No | `{}` | Additional path-based routing rules (future extensibility) |
| **`enable_waf`** | **bool** | **No** | **false** | **Enable GCP Cloud Armor WAF ($16-91/month)** |
| **`enable_cloudflare_proxy`** | **bool** | **No** | **true** | **Enable Cloudflare proxy (orange cloud) for free WAF/DDoS** |
| **`enable_demo_web_app_psc_neg`** | **bool** | **No** | **false** | **Enable PSC NEG consumer (connects to PSC service attachment in demo-web-app)** |

## Feature Flags

### Core Feature Flags

| Flag | Configurations | Default | Effect When `true` | Effect When `false` |
|------|---------------|---------|-------------------|---------------------|
| `enable_logging` | project-singleton | `true` | Creates logging bucket with 30-day retention | Skips logging bucket |
| `enable_demo_web_app` | demo-web-app, core | varies | Creates all demo resources (Cloud Run, VPC, PSC, LB) | Skips demo resources |
| `enable_self_signed_cert` | project-singleton | `false` | Uses self-signed certificates (1-year) | Uses Google-managed certificates |
| **`enable_waf`** | **core** | **`false`** | **Creates Cloud Armor security policy ($16-91/mo)** | **No Cloud Armor (saves cost)** |
| **`enable_cloudflare_proxy`** | **core** | **`true`** | **Enables Cloudflare proxy, WAF, DDoS (free)** | **Direct DNS to GCP** |
| **`enable_demo_web_app_psc_neg`** | **demo-web-app, core** | **`false`** | **Creates PSC resources (service attachment, PSC NEG)** | **Direct backend service connection** |
| **`enable_demo_web_app_internal_alb`** | **demo-web-app** | **`true`** | **Creates Internal ALB and web VPC** | **External LB connects directly via backend service** |

### Connectivity Pattern Configuration

Choose your connectivity pattern based on isolation and complexity requirements:

#### Pattern 1: PSC with Internal ALB (Maximum Isolation)

```bash
TF_VAR_enable_demo_web_app_psc_neg="true"
TF_VAR_enable_demo_web_app_internal_alb="true"
```

**Architecture:**
- External HTTPS LB → PSC NEG → PSC Service Attachment → Internal ALB → Serverless NEG → Cloud Run

**Use Case:** Cross-project isolation, maximum security

**Benefits:**
- ✅ Complete VPC separation via PSC
- ✅ IP overlap allowed (PSC NAT)
- ✅ Cross-project connectivity
- ✅ Producer controls access

**Cost:** ~$30/month

#### Pattern 2: Direct Backend Service (Simplest - Default)

```bash
TF_VAR_enable_demo_web_app_psc_neg="false"
TF_VAR_enable_demo_web_app_internal_alb="true"
```

**Architecture:**
- External HTTPS LB → Backend Service → Internal ALB → Serverless NEG → Cloud Run

**Use Case:** Single or cross-project, cost optimization

**Benefits:**
- ✅ Supports Internal ALB without PSC overhead
- ✅ Faster deployment
- ✅ Simpler troubleshooting
- ✅ Lower cost

**Cost:** ~$23-30/month

### Security Configuration Matrix

Choose your security configuration by combining these flags:

#### Option A: Cloudflare Edge (Default - Free)

```bash
TF_VAR_enable_cloudflare_proxy="true"
TF_VAR_enable_waf="false"
```

**Security Stack:**
- ✅ Cloudflare WAF (OWASP Top 10)
- ✅ Cloudflare DDoS protection
- ✅ Cloudflare SSL/TLS
- ✅ Firewall restricted to Cloudflare IPs
- ✅ Cloud Run ingress policy
- ✅ PSC private connectivity

**Cost:** ~$23/month (no WAF charges)

**Requirements:**
- `TF_VAR_cloudflare_origin_ca_key` must be set
- Manually set Cloudflare SSL mode to "Full (strict)"

#### Option B: GCP Edge

```bash
TF_VAR_enable_cloudflare_proxy="false"
TF_VAR_enable_waf="true"
```

**Security Stack:**
- ✅ GCP Cloud Armor WAF (10 OWASP ModSecurity rules)
- ✅ Configurable firewall rules
- ✅ Google-managed or self-signed SSL
- ✅ Cloud Run ingress policy
- ✅ PSC private connectivity

**Cost:** ~$39-114/month (includes Cloud Armor)

**Requirements:**
- Set `TF_VAR_allowed_https_source_ranges` for firewall restrictions
- Choose cert strategy via `enable_self_signed_cert`

#### Option C: Defense-in-Depth (Hybrid)

```bash
TF_VAR_enable_cloudflare_proxy="true"
TF_VAR_enable_waf="true"
```

**Security Stack:**
- ✅ Cloudflare WAF (Layer 1 - Edge)
- ✅ GCP Cloud Armor WAF (Layer 2 - Origin)
- ✅ Dual DDoS protection
- ✅ Firewall restricted to Cloudflare IPs
- ✅ All other security layers

**Cost:** ~$39-114/month (Cloud Armor + free Cloudflare)

**Requirements:**
- `TF_VAR_cloudflare_origin_ca_key` must be set
- Manually set Cloudflare SSL mode to "Full (strict)"

### Minimal Deployment (No Demo)

```bash
TF_VAR_enable_demo_web_app="false"
TF_VAR_enable_logging="false"
TF_VAR_enable_cloudflare_proxy="true"
TF_VAR_enable_waf="false"
```

Creates only:
- Billing budget
- Ingress VPC (empty, no backends)
- Cloudflare DNS record (no backend to route to)
- External load balancer infrastructure (no backend services)

**Use case:** Infrastructure pre-provisioning, testing

### Full Deployment (Demo Enabled)

```bash
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_logging="true"
TF_VAR_enable_cloudflare_proxy="true"
TF_VAR_enable_waf="false"
```

Creates:
- All project-singleton resources
- Complete demo-web-app with Cloud Run
- Complete core with PSC connectivity
- Cloudflare DNS record (proxied)
- Cloudflare Origin CA certificates

**Use case:** Default production configuration

## Network Configuration

### CIDR Ranges

| Subnet | Default CIDR | Configuration | Purpose |
|--------|--------------|---------------|---------|
| Ingress subnet | 10.0.1.0/24 | core | Ingress VPC workloads |
| External proxy-only | 10.0.98.0/24 | core | External ALB proxies (REGIONAL_MANAGED_PROXY) |
| Web subnet | 10.0.3.0/24 | demo-web-app | Application workloads |
| Internal proxy-only | 10.0.99.0/24 | demo-web-app | Internal ALB proxies (REGIONAL_MANAGED_PROXY) |
| PSC NAT | 10.0.100.0/24 | demo-web-app | PSC NAT translation (PRIVATE_SERVICE_CONNECT) |

**Important:** Ensure no CIDR overlap between configurations.

### Firewall Source Ranges

**Default:** `["0.0.0.0/0"]` (allow all - only used when Cloudflare proxy disabled)

**Automatic Cloudflare Restriction:**
When `enable_cloudflare_proxy = true`, firewall automatically restricts to Cloudflare IP ranges:

```
173.245.48.0/20, 103.21.244.0/22, 103.22.200.0/22, 103.31.4.0/22,
141.101.64.0/18, 108.162.192.0/18, 190.93.240.0/20, 188.114.96.0/20,
197.234.240.0/22, 198.41.128.0/17, 162.158.0.0/15, 104.16.0.0/13,
104.24.0.0/14, 172.64.0.0/13, 131.0.72.0/22
```

**Manual Restriction (when Cloudflare proxy disabled):**
For production with direct DNS, restrict to Google Cloud Load Balancer IPs:

```bash
TF_VAR_allowed_https_source_ranges='["35.191.0.0/16","130.211.0.0/22"]'
```

## SSL/TLS Configuration

### Certificate Strategy Selection

The infrastructure supports **three certificate strategies**:

#### Strategy 1: Cloudflare Origin Certificates (Default)

**When:** `enable_cloudflare_proxy = true`

**Configuration:**
```bash
TF_VAR_enable_cloudflare_proxy="true"
TF_VAR_cloudflare_origin_ca_key="your-origin-ca-key"
```

**Resources Created:**
- `tls_private_key.cloudflare_origin_key` (RSA 2048)
- `tls_cert_request.cloudflare_origin_csr`
- `cloudflare_origin_ca_certificate.origin_cert` (15-year validity)
- `google_compute_region_ssl_certificate.cloudflare_origin_cert`

**Characteristics:**
- ✅ 15-year validity (low maintenance)
- ✅ Free from Cloudflare
- ✅ Automatically trusted by Cloudflare
- ⚠️ Only valid when traffic comes through Cloudflare
- ⚠️ Requires Origin CA Key

**Manual Step Required:**
Set Cloudflare SSL/TLS encryption mode to **"Full (strict)"** in dashboard.

#### Strategy 2: Google-Managed Certificates

**When:** `enable_cloudflare_proxy = false` AND `enable_self_signed_cert = false`

**Configuration:**
```bash
TF_VAR_enable_cloudflare_proxy="false"
TF_VAR_enable_self_signed_cert="false"
```

**Resources Created (in project-singleton):**
- `google_compute_managed_ssl_certificate.external_https_lb_cert`

**Characteristics:**
- ✅ Free from Google
- ✅ Automatic renewal
- ✅ Trusted by browsers
- ⚠️ Global resource (incompatible with regional LB currently)

**Current Limitation:** Regional load balancers cannot use global managed certificates. This strategy is prepared for future global LB support.

#### Strategy 3: Self-Signed Certificates (Testing)

**When:** `enable_self_signed_cert = true`

**Configuration:**
```bash
TF_VAR_enable_self_signed_cert="true"
```

**Resources Created (in project-singleton):**
- `tls_private_key.self_signed_key` (RSA 2048)
- `tls_self_signed_cert.self_signed_cert` (1-year validity)
- `google_compute_region_ssl_certificate.external_https_lb_cert`

**Characteristics:**
- ✅ Works with regional load balancers
- ✅ No external dependencies
- ✅ 1-year validity
- ⚠️ Browser warnings (not trusted)
- ⚠️ For testing/development only

## DNS Configuration

### Cloudflare Settings

| Setting | When `enable_cloudflare_proxy = true` | When `enable_cloudflare_proxy = false` |
|---------|-------------------------------------|---------------------------------------|
| Record type | A | A |
| TTL | 1 (automatic) | 120 seconds |
| Proxied | true (orange cloud) | false (gray cloud) |
| Target | Cloudflare Anycast IP | GCP Load Balancer IP |

### Domain Structure

```
root_domain (vibetics.com)
    └── demo_web_app_subdomain_name (demo-web-app)
        = demo-web-app.vibetics.com
```

**Customization:**
```bash
TF_VAR_root_domain="yourdomain.com"
TF_VAR_demo_web_app_subdomain_name="app"
# Results in: app.yourdomain.com
```

## Resource Tags

All resources are tagged with mandatory labels:

| Tag | Value | Source |
|-----|-------|--------|
| `managed-by` | opentofu | Required in resource_tags |
| `project-suffix` | nonprod/prod | Required in resource_tags |
| `goog-terraform-provisioned` | true | Auto-added by provider |

Custom tags can be added via `resource_tags` variable:

```hcl
resource_tags = {
  "managed-by"     = "opentofu"
  "project-suffix" = "nonprod"
  "cost-center"    = "engineering"
  "environment"    = "development"
  "team"           = "platform"
}
```

**Validation:** Tags must include `project-suffix` and `managed-by` keys.

## Secrets Management

Sensitive variables:

| Variable | Description | Storage Recommendation |
|----------|-------------|----------------------|
| `cloudflare_api_token` | Cloudflare API access (DNS, general ops) | Secret Manager / env / GitHub Secrets |
| `cloudflare_origin_ca_key` | Cloudflare Origin CA operations | Secret Manager / env / GitHub Secrets |
| GCP credentials | Service account key | Workload Identity / env |

**Security Best Practices:**

1. **Local Development:**
   ```bash
   export TF_VAR_cloudflare_api_token="xxx"
   export TF_VAR_cloudflare_origin_ca_key="xxx"
   ```

2. **CI/CD (GitHub Actions):**
   - Store in GitHub Secrets
   - Reference in workflows

3. **Production:**
   - Use GCP Secret Manager
   - Mount as environment variables

**Never commit secrets to version control!**

## Example Configurations

### Development (Cloudflare Edge, Fast Iteration)

```bash
# .env
TF_VAR_project_suffix="nonprod"
TF_VAR_enable_logging="false"                # Skip to avoid deletion delays
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_cloudflare_proxy="true"        # Free WAF/DDoS
TF_VAR_enable_waf="false"                    # No Cloud Armor cost
TF_VAR_demo_web_app_image="gcr.io/cloudrun/hello"
TF_VAR_cloudflare_origin_ca_key="v1.0-xxx"
```

**Cost:** ~$23/month

### Production (Cloudflare Edge)

```bash
# .env
TF_VAR_project_suffix="prod"
TF_VAR_enable_logging="true"
TF_VAR_enable_demo_web_app="true"            # Or false for real apps
TF_VAR_enable_cloudflare_proxy="true"        # Free WAF/DDoS
TF_VAR_enable_waf="false"                    # Cost optimization
TF_VAR_budget_amount="5000"
TF_VAR_cloudflare_origin_ca_key="v1.0-xxx"
```

**Cost:** ~$30/month (with logging)

**Manual Step:** Set Cloudflare SSL mode to "Full (strict)"

### Production (Defense-in-Depth, High Security)

```bash
# .env
TF_VAR_project_suffix="prod"
TF_VAR_enable_logging="true"
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_cloudflare_proxy="true"        # Cloudflare Layer 1
TF_VAR_enable_waf="true"                     # Cloud Armor Layer 2
TF_VAR_budget_amount="10000"
TF_VAR_cloudflare_origin_ca_key="v1.0-xxx"
```

**Cost:** ~$46-121/month (dual WAF)

**Use case:** Finance, healthcare, high-security compliance

### Production (GCP-Native, No Cloudflare)

```bash
# .env
TF_VAR_project_suffix="prod"
TF_VAR_enable_logging="true"
TF_VAR_enable_demo_web_app="true"
TF_VAR_enable_cloudflare_proxy="false"       # Direct DNS
TF_VAR_enable_waf="true"                     # Cloud Armor only
TF_VAR_allowed_https_source_ranges='["35.191.0.0/16","130.211.0.0/22"]'
TF_VAR_budget_amount="5000"
```

**Cost:** ~$46-121/month (Cloud Armor)

**Use case:** GCP-only compliance, low-latency APIs

### Testing (Minimal Resources)

```bash
# .env
TF_VAR_project_suffix="nonprod"
TF_VAR_enable_logging="false"
TF_VAR_enable_demo_web_app="false"           # No backend resources
TF_VAR_enable_cloudflare_proxy="true"
TF_VAR_enable_waf="false"
```

**Cost:** ~$23/month (infrastructure only)

**Use case:** Infrastructure pre-provisioning, network testing

## Variable Precedence

OpenTofu resolves variables in this order (highest to lowest precedence):

1. Command-line flags: `-var="key=value"`
2. Environment variables: `TF_VAR_key=value`
3. `terraform.tfvars` file
4. `terraform.tfvars.json` file
5. `*.auto.tfvars` files (alphabetical order)
6. Default values in variable definitions

**Recommended Approach:**
- Use `.env` file with environment variables (ignored by git)
- Set defaults in `variables.tf`
- Override specific values via command line when needed

## Validation Rules

Several variables have validation rules:

### project_suffix
```hcl
validation {
  condition     = contains(["nonprod", "prod"], var.project_suffix)
  error_message = "Must be 'nonprod' or 'prod'"
}
```

### resource_tags
```hcl
validation {
  condition     = contains(keys(var.resource_tags), "project-suffix")
  error_message = "Must include 'project-suffix' key"
}

validation {
  condition     = contains(keys(var.resource_tags), "managed-by")
  error_message = "Must include 'managed-by' key"
}
```

These validations ensure compliance with organizational standards (FR-007).

## Cost Estimation by Configuration

| Configuration | enable_cloudflare_proxy | enable_waf | Monthly Cost |
|---------------|------------------------|-----------|--------------|
| **Cloudflare Edge** (default) | true | false | ~$23-30 |
| **GCP Edge** | false | true | ~$39-114 |
| **Defense-in-Depth** | true | true | ~$39-114 |
| **Minimal** (no demo) | true | false | ~$23 |

**Cost Breakdown:**
- Load Balancer forwarding rule: ~$18/month
- Regional IP (Standard tier): ~$5/month
- Cloud Armor (if enabled): $16-91/month
- Cloudflare: $0/month (free tier)
- Logging: ~$0-5/month (low volume)
