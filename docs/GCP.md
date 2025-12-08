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

### Logging

| Resource | Description |
|----------|-------------|
| `google_logging_project_bucket_config.logs_bucket` | Centralized logging bucket |

**Configuration**:

- Location: global
- Retention: 30 days (NFR-001 compliance)
- Conditional: Only created when `enable_logging = true`

### Outputs

| Output | Description |
|--------|-------------|
| `project_suffix` | Environment suffix (nonprod/prod) |
| `project_id` | GCP project ID |
| `billing_budget_id` | Budget resource ID |
| `logs_bucket_id` | Logging bucket ID (null if disabled) |
| `enable_logging` | Whether logging is enabled |

---

## Demo VPC

**Location**: `deploy/opentofu/gcp/demo-vpc/`

**Purpose**: Backend application VPC with Cloud Run service and PSC service attachment.

**Remote State Prefix**: `${project_id}-demo-vpc`

**Dependencies**: Reads from `project-singleton` remote state

### VPC Network

| Resource | Description |
|----------|-------------|
| `google_compute_network.web_vpc` | Application VPC (auto_create_subnetworks: false) |

### Subnets

| Resource | CIDR | Purpose |
|----------|------|---------|
| `google_compute_subnetwork.web_subnet` | 10.0.3.0/24 | Cloud Run and workloads |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.99.0/24 | Internal ALB proxy-only (REGIONAL_MANAGED_PROXY) |
| `google_compute_subnetwork.psc_nat_subnet` | 10.0.100.0/24 | PSC NAT (PRIVATE_SERVICE_CONNECT) |

### Cloud Run

| Resource | Description |
|----------|-------------|
| `google_cloud_run_v2_service.demo_web_app` | Demo web application container |
| `google_cloud_run_v2_service_iam_member.invoker` | IAM binding for allUsers invocation |

**Cloud Run Configuration**:

- Ingress: `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`
- Scaling: min 0 (scale to zero)
- Deletion protection: disabled
- Image: Configurable via `demo_web_app_image`
- Port: Configurable via `demo_web_app_port` (default: 3000)

### Internal Load Balancer

| Resource | Description |
|----------|-------------|
| `google_compute_region_network_endpoint_group.demo_web_app` | Serverless NEG for Cloud Run |
| `google_compute_region_backend_service.demo_web_app_internal_backend` | Internal backend service (INTERNAL_MANAGED) |
| `google_compute_region_url_map.internal_alb_url_map` | URL routing for internal ALB |
| `google_compute_region_target_https_proxy.internal_alb_https_proxy` | HTTPS proxy with SSL certificate |
| `google_compute_forwarding_rule.internal_alb_forwarding_rule` | Internal forwarding rule (port 443) |

### SSL Certificate

| Resource | Description |
|----------|-------------|
| `tls_private_key.self_signed_cert_key` | RSA 2048-bit private key |
| `tls_self_signed_cert.self_signed_cert` | Self-signed certificate (1 year validity) |
| `google_compute_region_ssl_certificate.internal_alb_cert_binding` | Regional SSL certificate binding |

### Private Service Connect

| Resource | Description |
|----------|-------------|
| `google_compute_service_attachment.demo_web_app_psc_attachment` | PSC service attachment (producer) |

**PSC Configuration**:

- Connection preference: `ACCEPT_AUTOMATIC`
- Proxy protocol: disabled
- Target: Internal ALB forwarding rule

### Outputs

| Output | Description |
|--------|-------------|
| `demo_web_app_psc_service_attachment_self_link` | PSC service attachment ID for consumers |

---

## Core

**Location**: `deploy/opentofu/gcp/core/`

**Purpose**: Public-facing ingress infrastructure with WAF and PSC consumer.

**Remote State Prefix**: `${project_id}-core`

**Dependencies**:

- Reads from `project-singleton` for `enable_logging`
- Reads from `demo-vpc` for `demo_web_app_psc_service_attachment_self_link`

### Providers

| Provider | Purpose |
|----------|---------|
| `google` | Standard GCP resources |
| `google-beta` | Beta features |
| `cloudflare` | DNS management |

### APIs Enabled

| Resource | Service | Description |
|----------|---------|-------------|
| `google_project_service.run` | `run.googleapis.com` | Cloud Run API |

### Static IP

| Resource | Description |
|----------|-------------|
| `google_compute_address.external_lb_ip` | Regional external IP (STANDARD tier) |

### VPC Network

| Resource | Description |
|----------|-------------|
| `google_compute_network.ingress_vpc` | Ingress VPC (auto_create_subnetworks: false) |

### Subnets

| Resource | CIDR | Purpose |
|----------|------|---------|
| `google_compute_subnetwork.ingress_subnet` | 10.0.1.0/24 | Ingress traffic (private Google access enabled) |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.98.0/24 | External ALB proxy-only (REGIONAL_MANAGED_PROXY) |

### Firewall

| Resource | Description |
|----------|-------------|
| `google_compute_firewall.allow_ingress_vpc_https_ingress` | Allow HTTPS (port 443) from configured sources |

**Firewall Configuration**:

- Direction: INGRESS
- Priority: 1000
- Source ranges: Configurable via `allowed_https_source_ranges` (default: 0.0.0.0/0)

### Cloud Armor WAF

| Resource | Description |
|----------|-------------|
| `google_compute_security_policy.edge_waf_policy` | Cloud Armor security policy |

**WAF Rules**:

| Priority | Expression | Action |
|----------|------------|--------|
| 1000 | `sqli-v33-stable` | deny(403) |
| 1001 | `xss-v33-stable` | deny(403) |
| 1002 | `lfi-v33-stable` | deny(403) |
| 1003 | `rfi-v33-stable` | deny(403) |
| 1004 | `rce-v33-stable` | deny(403) |
| 1006 | `methodenforcement-v33-stable` | deny(403) |
| 1007 | `scannerdetection-v33-stable` | deny(403) |
| 1008 | `protocolattack-v33-stable` | deny(403) |
| 1009 | `sessionfixation-v33-stable` | deny(403) |
| 1010 | `nodejs-v33-stable` | deny(403) |
| 2147483647 | `*` (default) | allow |

### SSL Certificate

| Resource | Description |
|----------|-------------|
| `tls_private_key.self_signed_key` | RSA 2048-bit private key |
| `tls_self_signed_cert.self_signed_cert` | Self-signed certificate (1 year validity) |
| `google_compute_region_ssl_certificate.external_https_lb_cert_binding` | Regional SSL certificate binding |

**Certificate Configuration**:

- Common name: `${demo_web_app_subdomain_name}.${root_domain}`
- DNS names: Same as common name

### PSC Consumer

| Resource | Description |
|----------|-------------|
| `google_compute_region_network_endpoint_group.demo_web_app_psc_neg` | PSC NEG (consumer) |

**PSC Configuration**:

- Type: `PRIVATE_SERVICE_CONNECT`
- Target: `demo_web_app_psc_service_attachment_self_link` from demo-vpc

### External Load Balancer

| Resource | Description |
|----------|-------------|
| `google_compute_region_backend_service.demo_web_app_external_backend` | External backend service with WAF |
| `google_compute_region_url_map.external_https_lb` | URL routing for external LB |
| `google_compute_region_target_https_proxy.external_https_lb` | HTTPS proxy with SSL certificate |
| `google_compute_forwarding_rule.external_https_lb` | External forwarding rule (port 443) |

**Load Balancer Configuration**:

- Scheme: `EXTERNAL_MANAGED` (regional)
- Protocol: HTTPS
- Network tier: STANDARD
- Security policy: `edge_waf_policy`

### Cloudflare DNS

| Resource | Description |
|----------|-------------|
| `cloudflare_record.demo_web_app_subdomain_a` | A record for subdomain |

**DNS Configuration**:

- Type: A
- TTL: 120 seconds
- Proxied: false (direct to GCP)
- Content: External LB IP address

### Outputs

| Output | Description |
|--------|-------------|
| `ingress_vpc_id` | Ingress VPC resource ID |
| `ingress_subnet_id` | Ingress subnet resource ID |
| `load_balancer_ip` | External load balancer IP address |
| `waf_policy_id` | Cloud Armor policy ID |

---

## Resource Dependencies

```
project-singleton
        |
        | (terraform_remote_state)
        v
    demo-vpc
        |
        | (terraform_remote_state: psc_service_attachment_self_link)
        v
      core
```

## Conditional Resources

Many resources are conditionally created based on feature flags:

| Flag | Configurations Affected | Resources Controlled |
|------|------------------------|---------------------|
| `enable_logging` | project-singleton | `logs_bucket` |
| `enable_demo_web_app` | demo-vpc, core | All Cloud Run, NEG, PSC resources |

When `enable_demo_web_app = false`:

- demo-vpc creates no resources (all have `count = 0`)
- core PSC NEG and backend service are not created
