# GCP Resources Reference

This document provides a complete reference of GCP resources managed by each OpenTofu configuration.

## Configuration Overview

```
deploy/opentofu/gcp/
├── project-singleton/    # Project-level resources
├── demo-vpc/             # Backend application VPC
└── core/                 # Ingress infrastructure
```

## Project Singleton

**Location**: `deploy/opentofu/gcp/project-singleton/`

**Purpose**: Project-wide resources deployed once per GCP project.

**Remote State Prefix**: `${project_id}-singleton`

### Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `google` | >= 4.0.0 | Standard GCP resources |
| `google-beta` | >= 4.0.0 | Beta features |
| `tls` | ~> 4.0 | TLS certificate generation |
| `random` | ~> 3.0 | Random resource generation |
| `acme` | ~> 2.0 | ACME protocol (Let's Encrypt) |

### APIs Enabled

| Resource | Service | Description |
|----------|---------|-------------|
| `google_project_service.billingbudgets` | `billingbudgets.googleapis.com` | Billing budget alerts |
| `google_project_service.cloudbilling` | `cloudbilling.googleapis.com` | Billing account access |
| `google_project_service.compute` | `compute.googleapis.com` | Compute Engine resources |
| `google_project_service.logging` | `logging.googleapis.com` | Cloud Logging |

### Billing Budget

| Resource | Description |
|----------|-------------|
| `google_billing_budget.budget` | Project billing budget with alerts at 50%, 80%, 100% |

**Configuration**:
- Currency: HKD (configurable via `budget_amount`)
- Default: 1000 HKD
- Alerts sent to billing admins
- All-time period tracking

### Logging

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_logging_project_bucket_config.logs_bucket` | Centralized logging bucket | `enable_logging = true` |

**Configuration**:
- Location: global
- Retention: 30 days (NFR-001 compliance)
- Bucket ID: `_Default`

### SSL Certificates

The singleton configuration manages SSL certificates using a **dual-path strategy**:

#### Path 1: Self-Signed Certificates (Testing)

**Condition**: `enable_self_signed_cert = true`

| Resource | Description |
|----------|-------------|
| `tls_private_key.self_signed_key` | RSA 2048-bit private key |
| `tls_self_signed_cert.self_signed_cert` | Self-signed certificate (1-year validity) |
| `google_compute_region_ssl_certificate.external_https_lb_cert` | Regional SSL certificate binding |

**Certificate Details**:
- Common Name: `${demo_web_app_subdomain_name}.${root_domain}`
- Organization: vibetics-cloudedge-nonprod
- Validity: 365 days
- Algorithm: RSA 2048

#### Path 2: Google-Managed Certificates (Production)

**Condition**: `enable_self_signed_cert = false`

| Resource | Description |
|----------|-------------|
| `google_compute_managed_ssl_certificate.external_https_lb_cert` | Google-managed certificate with auto-renewal |

**Certificate Details**:
- Domain: `${demo_web_app_subdomain_name}.${root_domain}`
- Auto-renewal: Yes
- Global resource (not compatible with regional LB currently)

**Note**: Google-managed certificates are global resources and currently incompatible with regional load balancers. When using Cloudflare proxy (`enable_cloudflare_proxy = true`), Cloudflare Origin CA certificates are used instead (created in core configuration).

### Outputs

| Output | Description | Type |
|--------|-------------|------|
| `project_suffix` | Environment suffix (nonprod/prod) | string |
| `project_id` | GCP project ID | string |
| `billing_budget_id` | Budget resource ID | string |
| `logs_bucket_id` | Logging bucket ID (null if disabled) | string |
| `enable_logging` | Whether logging is enabled | bool |
| `external_https_lb_cert_id` | SSL certificate ID for external LB | string |

---

## Demo VPC

**Location**: `deploy/opentofu/gcp/demo-vpc/`

**Purpose**: Backend application VPC with Cloud Run service and PSC service attachment.

**Remote State Prefix**: `${project_id}-demo-vpc`

**Dependencies**: Reads from `project-singleton` remote state

### Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `google` | >= 4.0.0 | Standard GCP resources |
| `google-beta` | >= 4.0.0 | Beta features |
| `tls` | ~> 4.0 | TLS certificate generation |

### VPC Network

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_compute_network.web_vpc` | Application VPC (auto_create_subnetworks: false) | `enable_demo_web_app = true` |

### Subnets

| Resource | CIDR | Purpose | Conditional |
|----------|------|---------|-------------|
| `google_compute_subnetwork.web_subnet` | 10.0.3.0/24 | Cloud Run and workloads | `enable_demo_web_app = true` |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.99.0/24 | Internal ALB proxy-only (REGIONAL_MANAGED_PROXY) | `enable_demo_web_app = true` |
| `google_compute_subnetwork.psc_nat_subnet` | 10.0.100.0/24 | PSC NAT (PRIVATE_SERVICE_CONNECT) | `enable_demo_web_app = true` |

**Subnet Configuration**:
- `web_subnet`: Private Google Access enabled (CIS GCP 3.9)
- `proxy_only_subnet`: Purpose = REGIONAL_MANAGED_PROXY, Role = ACTIVE
- `psc_nat_subnet`: Purpose = PRIVATE_SERVICE_CONNECT

### Cloud Run

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_cloud_run_v2_service.demo_web_app` | Demo web application container | `enable_demo_web_app = true` |
| `google_cloud_run_v2_service_iam_member.invoker` | IAM binding for allUsers invocation | `enable_demo_web_app = true` |

**Cloud Run Configuration**:
- Ingress: `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` (no direct access)
- Scaling: min instances = 0 (scale to zero for cost optimization)
- Deletion protection: disabled
- Image: Configurable via `demo_web_app_image`
- Port: Configurable via `demo_web_app_port` (default: 3000)
- VPC Access: Uses Direct VPC egress
- Service Account: Default Compute Engine service account

### Internal Load Balancer

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_compute_region_network_endpoint_group.demo_web_app` | Serverless NEG for Cloud Run | `enable_demo_web_app = true` |
| `google_compute_region_backend_service.demo_web_app_internal_backend` | Internal backend service (INTERNAL_MANAGED) | `enable_demo_web_app = true` |
| `google_compute_region_url_map.internal_alb_url_map` | URL routing for internal ALB | `enable_demo_web_app = true` |
| `google_compute_region_target_https_proxy.internal_alb_https_proxy` | HTTPS proxy with SSL certificate | `enable_demo_web_app = true` |
| `google_compute_forwarding_rule.internal_alb_forwarding_rule` | Internal forwarding rule (port 443) | `enable_demo_web_app = true` |

**Load Balancer Configuration**:
- Scheme: INTERNAL_MANAGED (internal to VPC only)
- Protocol: HTTPS
- Port: 443
- Backend: Serverless NEG (Cloud Run)

### SSL Certificate (Internal ALB)

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `tls_private_key.self_signed_cert_key` | RSA 2048-bit private key | `enable_demo_web_app = true` |
| `tls_self_signed_cert.self_signed_cert` | Self-signed certificate (1-year validity) | `enable_demo_web_app = true` |
| `google_compute_region_ssl_certificate.internal_alb_cert_binding` | Regional SSL certificate binding | `enable_demo_web_app = true` |

**Certificate Configuration**:
- Common Name: `internal-alb.local`
- Organization: vibetics-cloudedge-nonprod
- Validity: 8760 hours (1 year)
- Internal use only (not exposed to internet)

### Private Service Connect

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_compute_service_attachment.demo_web_app_psc_attachment` | PSC service attachment (producer) | `enable_demo_web_app = true` |

**PSC Configuration**:
- Connection preference: `ACCEPT_AUTOMATIC` (automatic approval)
- Proxy protocol: disabled
- Target: Internal ALB forwarding rule
- NAT subnets: `psc_nat_subnet`
- Reconcile connections: true

### Outputs

| Output | Description |
|--------|-------------|
| `demo_web_app_psc_service_attachment_self_link` | PSC service attachment ID for consumers (core configuration) |

---

## Core

**Location**: `deploy/opentofu/gcp/core/`

**Purpose**: Public-facing ingress infrastructure with optional WAF and PSC consumer.

**Remote State Prefix**: `${project_id}-core`

**Dependencies**:
- Reads from `project-singleton` for `enable_logging`, `external_https_lb_cert_id`
- Reads from `demo-vpc` for `demo_web_app_psc_service_attachment_self_link`

### Providers

| Provider | Version | Purpose |
|----------|---------|---------|
| `google` | >= 4.0.0 | Standard GCP resources |
| `google-beta` | >= 4.0.0 | Beta features |
| `cloudflare` | ~> 4.0 | DNS and general operations |
| `cloudflare.origin_ca` (alias) | ~> 4.0 | Origin CA certificate operations |
| `tls` | ~> 4.0 | TLS certificate generation |
| `random` | ~> 3.0 | Random resource generation |

**Provider Configuration**:
- `cloudflare`: Uses `api_token` for DNS management
- `cloudflare.origin_ca`: Uses `api_user_service_key` (Origin CA Key) for certificate operations

### APIs Enabled

| Resource | Service | Description |
|----------|---------|-------------|
| `google_project_service.run` | `run.googleapis.com` | Cloud Run API |

### Static IP

| Resource | Description |
|----------|-------------|
| `google_compute_address.external_lb_ip` | Regional external IP (STANDARD tier) |

**Configuration**:
- Type: EXTERNAL
- Network Tier: STANDARD (cost optimization)
- Region: `var.region`

### VPC Network

| Resource | Description |
|----------|-------------|
| `google_compute_network.ingress_vpc` | Ingress VPC (auto_create_subnetworks: false) |

### Subnets

| Resource | CIDR | Purpose |
|----------|------|---------|
| `google_compute_subnetwork.ingress_subnet` | 10.0.1.0/24 | Ingress traffic (private Google access enabled) |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.98.0/24 | External ALB proxy-only (REGIONAL_MANAGED_PROXY) |

**Subnet Configuration**:
- `ingress_subnet`: Private Google Access enabled (CIS GCP 3.9)
- `proxy_only_subnet`: Purpose = REGIONAL_MANAGED_PROXY, Role = ACTIVE

### Firewall

| Resource | Description |
|----------|-------------|
| `google_compute_firewall.allow_ingress_vpc_https_ingress` | Allow HTTPS (port 443) from dynamic sources |

**Firewall Configuration**:
- Direction: INGRESS
- Priority: 1000
- Protocol: TCP, Port: 443
- **Dynamic Source Ranges**:
  - When `enable_cloudflare_proxy = true`: Cloudflare IPv4 ranges (14 CIDRs)
  - When `enable_cloudflare_proxy = false`: `var.allowed_https_source_ranges` (default: 0.0.0.0/0)

**Cloudflare IP Ranges** (when proxy enabled):
```
173.245.48.0/20, 103.21.244.0/22, 103.22.200.0/22, 103.31.4.0/22,
141.101.64.0/18, 108.162.192.0/18, 190.93.240.0/20, 188.114.96.0/20,
197.234.240.0/22, 198.41.128.0/17, 162.158.0.0/15, 104.16.0.0/13,
104.24.0.0/14, 172.64.0.0/13, 131.0.72.0/22
```

### Cloudflare DNS

| Resource | Description |
|----------|-------------|
| `cloudflare_record.demo_web_app_subdomain_a` | A record for subdomain with dynamic proxy |

**DNS Configuration**:
- Type: A
- TTL:
  - 1 (automatic) when `enable_cloudflare_proxy = true`
  - 120 seconds when `enable_cloudflare_proxy = false`
- **Proxied**: `var.enable_cloudflare_proxy` (dynamic)
  - `true`: Traffic routed through Cloudflare (orange cloud)
  - `false`: Direct DNS resolution to GCP IP
- Content: External LB IP address

### Cloudflare Origin Certificates

**Condition**: `enable_cloudflare_proxy = true`

| Resource | Description |
|----------|-------------|
| `tls_private_key.cloudflare_origin_key` | RSA 2048-bit private key |
| `tls_cert_request.cloudflare_origin_csr` | Certificate signing request |
| `cloudflare_origin_ca_certificate.origin_cert` | Cloudflare Origin CA certificate |
| `google_compute_region_ssl_certificate.cloudflare_origin_cert` | Upload Cloudflare cert to GCP |

**Certificate Configuration**:
- Common Name: `${demo_web_app_subdomain_name}.${root_domain}`
- Organization: Vibetics
- Request Type: origin-rsa
- Validity: 5475 days (15 years)
- Provider: `cloudflare.origin_ca` (requires Origin CA Key)

**Lifecycle**:
- `create_before_destroy = true` (zero-downtime cert rotation)

### Cloud Armor WAF

**Condition**: `enable_waf = true`

| Resource | Description |
|----------|-------------|
| `google_compute_region_security_policy.edge_waf_policy` | Regional Cloud Armor security policy |

**WAF Rules** (OWASP ModSecurity CRS v33):

| Priority | Expression | Action | Description |
|----------|------------|--------|-------------|
| 1000 | `sqli-v33-stable` | deny(403) | SQL injection protection |
| 1001 | `xss-v33-stable` | deny(403) | Cross-site scripting protection |
| 1002 | `lfi-v33-stable` | deny(403) | Local file inclusion protection |
| 1003 | `rfi-v33-stable` | deny(403) | Remote file inclusion protection |
| 1004 | `rce-v33-stable` | deny(403) | Remote code execution protection |
| 1006 | `methodenforcement-v33-stable` | deny(403) | HTTP method enforcement |
| 1007 | `scannerdetection-v33-stable` | deny(403) | Scanner/bot detection |
| 1008 | `protocolattack-v33-stable` | deny(403) | Protocol attack protection |
| 1009 | `sessionfixation-v33-stable` | deny(403) | Session fixation protection |
| 1010 | `nodejs-v33-stable` | deny(403) | Node.js exploit protection |
| 2147483647 | `*` (default) | allow | Allow all other traffic |

**Cost**: $5 (policy) + $11 (11 rules) + $0.75 per million requests

### PSC Consumer

**Condition**: `enable_demo_web_app = true`

| Resource | Description |
|----------|-------------|
| `google_compute_region_network_endpoint_group.demo_web_app_psc_neg` | PSC NEG (consumer) |

**PSC Configuration**:
- Type: `PRIVATE_SERVICE_CONNECT`
- Target: `demo_web_app_psc_service_attachment_self_link` (from demo-vpc remote state)
- Network: `ingress_vpc`
- Subnetwork: `ingress_subnet`

### External Load Balancer

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_compute_region_backend_service.demo_web_app_external_backend` | External backend service | `enable_demo_web_app = true` |
| `google_compute_region_url_map.external_https_lb` | URL routing for external LB | Always |
| `google_compute_region_target_https_proxy.external_https_lb` | HTTPS proxy with dynamic SSL certs | Always |
| `google_compute_forwarding_rule.external_https_lb` | External forwarding rule (port 443) | Always |

**Backend Service Configuration**:
- Scheme: `EXTERNAL_MANAGED` (regional external ALB)
- Protocol: HTTPS
- Port Name: https
- Timeout: 30 seconds
- **Security Policy**:
  - Attached when `enable_waf = true`
  - `null` when `enable_waf = false`
- Backend: PSC NEG
- Balancing Mode: UTILIZATION
- Capacity Scaler: 1.0

**HTTPS Proxy Configuration**:
- **Dynamic SSL Certificates**:
  - When `enable_cloudflare_proxy = true`: Uses `cloudflare_origin_cert`
  - When `enable_cloudflare_proxy = false`: Uses `singleton.external_https_lb_cert_id`

**Forwarding Rule Configuration**:
- Scheme: EXTERNAL_MANAGED
- Port: 443
- IP Address: `external_lb_ip`
- Network Tier: STANDARD (cost optimization)
- Network: `ingress_vpc` (required for regional LB)
- Depends On: `proxy_only_subnet`

### Outputs

| Output | Description | Type |
|--------|-------------|------|
| `ingress_vpc_id` | Ingress VPC resource ID | string |
| `ingress_subnet_id` | Ingress subnet resource ID | string |
| `load_balancer_ip` | External load balancer IP address | string |
| `waf_policy_id` | Cloud Armor policy ID (null if `enable_waf = false`) | string |
| `cloudflare_proxy_enabled` | Cloudflare proxy status | bool |
| `cloud_armor_enabled` | Cloud Armor WAF status | bool |
| `cloudflare_origin_cert_id` | Cloudflare origin cert ID (null if proxy disabled) | string |

---

## Resource Dependencies

```
project-singleton
        |
        | (terraform_remote_state: enable_logging, external_https_lb_cert_id)
        v
    demo-vpc
        |
        | (terraform_remote_state: demo_web_app_psc_service_attachment_self_link)
        v
      core
```

**Dependency Chain**:
1. `project-singleton` has no dependencies
2. `demo-vpc` reads singleton outputs (optional, for logging configuration)
3. `core` reads both singleton and demo-vpc outputs

## Conditional Resources Summary

Resources created based on feature flags:

| Flag | Configuration | Resources Affected |
|------|--------------|-------------------|
| `enable_logging` | project-singleton | `google_logging_project_bucket_config.logs_bucket` |
| `enable_self_signed_cert` | project-singleton | Self-signed cert resources vs managed cert |
| `enable_demo_web_app` | demo-vpc, core | All Cloud Run, VPC, NEG, PSC, LB resources |
| `enable_waf` | core | `google_compute_region_security_policy.edge_waf_policy` |
| `enable_cloudflare_proxy` | core | Cloudflare origin cert resources, DNS proxy setting, firewall source ranges |

**When `enable_demo_web_app = false`**:
- demo-vpc creates **no resources** (all have `count = 0`)
- core PSC NEG and backend service are **not created**
- Only ingress VPC, firewall, DNS, and external LB URL map/proxy/forwarding rule are created

**When `enable_waf = false`** (default):
- Cloud Armor security policy **not created**
- Backend service has `security_policy = null`
- Saves $16-91/month

**When `enable_cloudflare_proxy = true`** (default):
- Cloudflare origin certificate resources created
- DNS record `proxied = true` (orange cloud)
- Firewall restricted to Cloudflare IP ranges
- HTTPS proxy uses Cloudflare origin certificate

**When `enable_cloudflare_proxy = false`**:
- Cloudflare origin certificate **not created**
- DNS record `proxied = false` (gray cloud)
- Firewall uses `allowed_https_source_ranges` variable
- HTTPS proxy uses singleton certificate (self-signed or managed)

## Resource Counts by Configuration

### Minimal Configuration (No Demo App)
```hcl
enable_demo_web_app = false
```
- **project-singleton**: 5-6 resources (depending on logging)
- **demo-vpc**: 0 resources
- **core**: ~8 resources (networking only)
- **Total**: ~13-14 resources

### Default Configuration (Cloudflare Edge)
```hcl
enable_demo_web_app     = true
enable_cloudflare_proxy = true
enable_waf              = false
```
- **project-singleton**: 5-6 resources
- **demo-vpc**: 13 resources
- **core**: ~18 resources (including Cloudflare origin cert)
- **Total**: ~36-37 resources

### GCP Edge Configuration
```hcl
enable_demo_web_app     = true
enable_cloudflare_proxy = false
enable_waf              = true
```
- **project-singleton**: 5-6 resources
- **demo-vpc**: 13 resources
- **core**: ~15 resources (Cloud Armor, singleton cert)
- **Total**: ~33-34 resources

### Defense-in-Depth Configuration (Hybrid)
```hcl
enable_demo_web_app     = true
enable_cloudflare_proxy = true
enable_waf              = true
```
- **project-singleton**: 5-6 resources
- **demo-vpc**: 13 resources
- **core**: ~19 resources (Cloudflare cert + Cloud Armor)
- **Total**: ~37-38 resources

## Cost Attribution by Configuration

| Configuration | Resource | Monthly Cost Estimate |
|---------------|----------|---------------------|
| **project-singleton** | Billing budget | $0 (alerting only) |
| | Logging (30-day retention) | ~$0-5 (low log volume) |
| | SSL certificates | $0 (self-signed or Cloudflare) |
| **demo-vpc** | VPC & Subnets | $0 (no charges for VPC) |
| | Cloud Run (scale to zero) | $0 when idle |
| | Internal Load Balancer | ~$7/month (forwarding rule) |
| | PSC Service Attachment | $0 (no data transfer charges within region) |
| **core** | VPC & Subnets | $0 |
| | External IP (Standard tier) | ~$5/month |
| | External Load Balancer | ~$18/month (forwarding rule) |
| | Cloud Armor (if enabled) | $16-91/month |
| | Cloudflare (free tier) | $0/month |
| | PSC NEG | $0 (included in LB) |

**Total Monthly Cost**:
- **Cloudflare Edge** (default): ~$30/month
- **GCP Edge**: ~$46-121/month
- **Defense-in-Depth**: ~$46-121/month
