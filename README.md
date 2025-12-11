# Vibetics CloudEdge

Cloud-agnostic edge infrastructure managed by OpenTofu, providing secure ingress with optional WAF, load balancing, and Private Service Connect (PSC) connectivity for backend applications.

## Overview

Vibetics CloudEdge provides a **modular secure baseline infrastructure** for deploying applications behind a unified edge security layer. The current implementation focuses on GCP with planned expansion to AWS and Azure.

**What This Project Provides** (Infrastructure-Only):

- **Flexible Edge Security**: Choose between Cloudflare WAF (free) or GCP Cloud Armor (paid)
- **Flexible Connectivity**: PSC (isolation), Direct Cloud Run (simplicity), or Shared VPC (enterprise)
- Regional HTTPS Load Balancer with SSL termination
- Cloudflare Origin CA certificates or Google-managed certificates
- Optional Private Service Connect (PSC) for cross-VPC connectivity
- Optional Internal Application Load Balancer
- Ingress VPC with dynamic firewall rules (Cloudflare IPs or custom ranges)
- Cloudflare DNS integration with proxy support
- Billing budget monitoring

**What This Project Does NOT Provide** (Application Responsibility):

- API Gateway (authentication, rate limiting, request transformation)
- Application-level security (OAuth, JWT, API keys)
- Business logic or application code

## Architecture

### Architecture Flexibility

The infrastructure supports **three connectivity patterns** controlled by `enable_psc` and `enable_internal_alb` variables:

#### Pattern 1: PSC with Internal ALB (Default - Maximum Isolation)
**Configuration:** `enable_psc=true, enable_internal_alb=true`

```
Internet → Cloudflare → External HTTPS LB → PSC NEG →
  PSC Service Attachment → Internal ALB → Serverless NEG → Cloud Run
```

**Use case:** Maximum network isolation for multi-tenant or security-critical deployments

#### Pattern 2: Direct Cloud Run (Simplest)
**Configuration:** `enable_psc=false, enable_internal_alb=false`

```
Internet → Cloudflare → External HTTPS LB → Serverless NEG → Cloud Run
```

**Use case:** Single-project deployments, simplified architecture, cost optimization

#### Pattern 3: Shared VPC with Internal ALB
**Configuration:** `enable_psc=false, enable_internal_alb=true, enable_shared_vpc=true`

```
Internet → Cloudflare → External HTTPS LB →
  Shared VPC Backend Service → Internal ALB → Serverless NEG → Cloud Run
```

**Use case:** Shared VPC scenarios, organizational policy requirements

### Detailed Architecture: PSC with Internal ALB (Default)

```
                            INTERNET
                               |
                    +----------v----------+
                    |   Cloudflare Proxy  |
                    |  (proxied = true)   |
                    |   - Free WAF/DDoS   |
                    |   - Free SSL/TLS    |
                    |   - Global CDN      |
                    +----------+----------+
                               |
                   Cloudflare Origin Certificate
                               |
+------------------------------v-------------------------------+
|                    CORE CONFIGURATION                        |
|                    deploy/opentofu/gcp/core                  |
|                                                              |
|  +------------------+                                        |
|  | Regional Static  |                                        |
|  | External IP      |                                        |
|  +------------------+                                        |
|                                                              |
|  +--------------------------------------------------------+  |
|  |           Regional External HTTPS Load Balancer       |  |
|  |  +------------------+    +-------------------------+  |  |
|  |  | Cloudflare       |    | URL Map                 |  |  |
|  |  | Origin Cert      |    | (Backend routing)       |  |  |
|  |  | (15-year)        |    |                         |  |  |
|  |  +------------------+    +-------------------------+  |  |
|  +--------------------------------------------------------+  |
|                                                              |
|  +--------------------------------------------------------+  |
|  |                    Ingress VPC                         |  |
|  |  +------------------+    +------------------------+    |  |
|  |  | Ingress Subnet   |    | Proxy-Only Subnet      |    |  |
|  |  | (10.0.1.0/24)    |    | (10.0.98.0/24)         |    |  |
|  |  +------------------+    +------------------------+    |  |
|  |                                                        |  |
|  |  +--------------------------------------------------+  |  |
|  |  | Firewall: HTTPS from Cloudflare IPs only        |  |  |
|  |  +--------------------------------------------------+  |  |
|  +--------------------------------------------------------+  |
|                                     |                        |
|  +----------------------------------v---------------------+  |
|  |        PSC NEG / Direct Backend (Conditional)          |  |
|  |  If enable_psc=true:                                   |  |
|  |    PSC NEG -> Service Attachment in demo-vpc           |  |
|  |  If enable_psc=false:                                  |  |
|  |    Direct Backend Service -> Serverless NEG/Internal ALB|  |
|  +--------------------------------------------------------+  |
+--------------------------------------------------------------+
                               |
           PSC (if enabled) or Direct Connection
                               |
+------------------------------v-------------------------------+
|                   DEMO-VPC CONFIGURATION                     |
|                   deploy/opentofu/gcp/demo-vpc               |
|                                                              |
|  +--------------------------------------------------------+  |
|  |               Web VPC (if enable_internal_alb=true)    |  |
|  |  +------------------+    +------------------------+    |  |
|  |  | Web Subnet       |    | Proxy-Only Subnet      |    |  |
|  |  | (10.0.3.0/24)    |    | (10.0.99.0/24)         |    |  |
|  |  +------------------+    +------------------------+    |  |
|  |                          +------------------------+    |  |
|  |                          | PSC NAT Subnet         |    |  |
|  |                          | (if enable_psc=true)   |    |  |
|  |                          +------------------------+    |  |
|  +--------------------------------------------------------+  |
|                               |                              |
|  +---------------------------v----------------------------+  |
|  |    Internal ALB (if enable_internal_alb=true)           |  |
|  |  +------------------+    +------------------------+    |  |
|  |  | Internal ALB     |    | Serverless NEG         |    |  |
|  |  | URL Map          |--->| (Cloud Run service)    |    |  |
|  |  +------------------+    +------------------------+    |  |
|  +--------------------------------------------------------+  |
|                               |                              |
|  +---------------------------v----------------------------+  |
|  |      PSC Service Attachment (if enable_psc=true)        |  |
|  +--------------------------------------------------------+  |
|                               |                              |
|  +---------------------------v----------------------------+  |
|  |                     Cloud Run                           |  |
|  |  +--------------------------------------------------+  |  |
|  |  | demo-web-app                                     |  |  |
|  |  | Ingress: INTERNAL_LOAD_BALANCER only             |  |  |
|  |  | IAM: allUsers (for LB forwarding)                |  |  |
|  |  +--------------------------------------------------+  |  |
|  +--------------------------------------------------------+  |
+--------------------------------------------------------------+
```

## Architecture Options

This infrastructure supports **three security configurations** via feature flags:

### Option A: Cloudflare Edge (Default - Free)
**Configuration:**
```hcl
enable_cloudflare_proxy = true   # Cloudflare proxy (orange cloud)
enable_waf              = false  # No Cloud Armor cost
```

**Security Layers:**
- ✅ Cloudflare WAF (OWASP Top 10 protection)
- ✅ Cloudflare DDoS protection
- ✅ Cloudflare SSL/TLS
- ✅ Origin IP hidden by Cloudflare
- ✅ Firewall restricted to Cloudflare IPs only
- ✅ Cloud Run ingress policy (internal only)
- ✅ PSC private connectivity

**Cost:** $0/month for WAF

### Option B: GCP Edge
**Configuration:**
```hcl
enable_cloudflare_proxy = false  # Direct DNS resolution
enable_waf              = true   # GCP Cloud Armor enabled
```

**Security Layers:**
- ✅ GCP Cloud Armor WAF (10 OWASP ModSecurity rules)
- ✅ Configurable firewall rules
- ✅ Google-managed or self-signed SSL
- ✅ Cloud Run ingress policy (internal only)
- ✅ PSC private connectivity

**Cost:** $16-91/month (policy + rules + requests)

### Option C: Defense-in-Depth (Hybrid)
**Configuration:**
```hcl
enable_cloudflare_proxy = true   # Cloudflare as first layer
enable_waf              = true   # Cloud Armor as second layer
```

**Security Layers:**
- ✅ Cloudflare WAF (Layer 1 - Edge)
- ✅ GCP Cloud Armor WAF (Layer 2 - Origin)
- ✅ Both Cloudflare and GCP DDoS protection
- ✅ All other security layers

**Cost:** $16-91/month for Cloud Armor (Cloudflare WAF is free)

## Deployment Structure

The infrastructure is organized into three OpenTofu configurations that must be deployed in order:

```
deploy/opentofu/gcp/
├── project-singleton/    # 1. Project-level resources (deploy first)
│   ├── main.tf          #    Backend config, providers
│   ├── project-singleton.tf  # Billing, logging, APIs, SSL certs
│   ├── variables.tf
│   └── outputs.tf
│
├── demo-vpc/            # 2. Application VPC (deploy second)
│   ├── main.tf          #    Backend config, providers
│   ├── demo-vpc.tf      #    Web VPC, Cloud Run, Internal ALB, PSC
│   ├── variables.tf
│   └── outputs.tf
│
└── core/                # 3. Core ingress infrastructure (deploy last)
    ├── main.tf          #    Backend config, providers
    ├── core.tf          #    Ingress VPC, WAF (optional), External LB, PSC consumer, DNS
    ├── variables.tf
    └── outputs.tf
```

**Deployment Order Dependency**:

1. `project-singleton` - Creates project-level resources, SSL certificates, outputs read by other configs
2. `demo-vpc` - Creates backend VPC and PSC service attachment, outputs service attachment ID
3. `core` - Creates ingress VPC and PSC consumer that connects to demo-vpc

## Quick Start

For detailed prerequisites and troubleshooting, see [docs/QUICKSTART.md](docs/QUICKSTART.md).

### Prerequisites

- OpenTofu >= 1.6.0
- GCP project with billing enabled
- Cloudflare account with DNS zone
- Cloudflare Origin CA Key (for Cloudflare proxy mode)
- Required GCP APIs enabled (see QUICKSTART.md)

### Deploy

```bash
# 1. Clone and configure
git clone <repository-url>
cd vibetics-cloudedge
cp .env.example .env
# Edit .env with your project settings

# 2. Set Cloudflare Origin CA Key (if using Cloudflare proxy)
export TF_VAR_cloudflare_origin_ca_key="your-origin-ca-key"

# 3. Source environment
source .env

# 4. Deploy in order
./scripts/deploy.sh
```

### Configure Cloudflare SSL Mode (if using Cloudflare proxy)

After deployment, manually configure Cloudflare SSL/TLS:

1. Go to: https://dash.cloudflare.com/ → Your domain → **SSL/TLS** → **Overview**
2. Set encryption mode to: **"Full (strict)"**
3. This ensures encrypted connection between Cloudflare and GCP origin

### Teardown

```bash
./scripts/teardown.sh
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture, PSC patterns, WAF options, future roadmap |
| [docs/GCP.md](docs/GCP.md) | GCP resource reference by configuration |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Variables, feature flags, environment setup |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Prerequisites, IAM setup, deployment guide |
| [docs/SECURITY.md](docs/SECURITY.md) | Threat modeling, security controls, STRIDE analysis |
| [docs/TESTING.md](docs/TESTING.md) | Testing strategy, Terratest integration tests |
| [docs/CI_WORKFLOW.md](docs/CI_WORKFLOW.md) | CI/CD pipeline documentation |
| [docs/PRE_COMMIT_SETUP.md](docs/PRE_COMMIT_SETUP.md) | Pre-commit hooks setup guide |

## Security

This infrastructure implements defense-in-depth with multiple security layers:

### Default Configuration (Cloudflare Edge)

| Layer | Component | Protection |
|-------|-----------|------------|
| Edge | Cloudflare WAF | SQLi, XSS, DDoS, OWASP Top 10 |
| Network | Ingress VPC Firewall | Cloudflare IP ranges only |
| Transport | SSL/TLS | Cloudflare Origin Certificate (15-year) |
| Backend | Cloud Run Ingress Policy | Internal load balancer traffic only |
| Connectivity | Private Service Connect | No public IP exposure for backends |

### Optional GCP Cloud Armor (enable_waf = true)

| Priority | Rule | Protection |
|----------|------|------------|
| 1000 | sqli-v33-stable | SQL injection |
| 1001 | xss-v33-stable | Cross-site scripting |
| 1002 | lfi-v33-stable | Local file inclusion |
| 1003 | rfi-v33-stable | Remote file inclusion |
| 1004 | rce-v33-stable | Remote code execution |
| 1006 | methodenforcement-v33-stable | HTTP method attacks |
| 1007 | scannerdetection-v33-stable | Scanner/bot detection |
| 1008 | protocolattack-v33-stable | Protocol attacks |
| 1009 | sessionfixation-v33-stable | Session fixation |
| 1010 | nodejs-v33-stable | Node.js exploits |

For detailed security documentation, see [docs/SECURITY.md](docs/SECURITY.md).

## Cost Optimization

### Current Implementation (Cloudflare Edge)
- **WAF:** $0/month (Cloudflare free tier)
- **DDoS Protection:** $0/month (Cloudflare free tier)
- **SSL Certificates:** $0/month (Cloudflare Origin CA)
- **Load Balancer:** ~$18/month (forwarding rule)
- **Regional IP:** ~$5/month (Standard tier)
- **Total:** ~$23/month

### With Cloud Armor (Defense-in-Depth)
- **Additional Cost:** $16-91/month
  - Security policy: $5/month
  - WAF rules (11): $11/month
  - Requests: $0.75 per million requests

## Feature Flags

The architecture supports flexible configuration via feature flags:

| Flag | Default | Purpose | Impact |
|------|---------|---------|--------|
| `enable_cloudflare_proxy` | `true` | Enable Cloudflare proxy | Free WAF, DDoS, hides origin IP |
| `enable_waf` | `false` | Enable GCP Cloud Armor | $16-91/month additional cost |
| `enable_demo_web_app` | varies | Deploy demo app | Creates all backend resources |
| `enable_psc` | `true` | Enable Private Service Connect | Maximum network isolation, supports multi-tenant |
| `enable_internal_alb` | `true` | Enable Internal ALB | Adds internal load balancer layer |
| `enable_shared_vpc` | `false` | Enable Shared VPC | For organizational shared VPC policies |
| `enable_logging` | `true` | Centralized logging | 30-day retention |
| `enable_self_signed_cert` | `false` | Use self-signed certs | For testing only |

## Future Expansion

The architecture supports planned expansion:

- **Multi-Cloud**: AWS and Azure modules (directory structure ready)
- **Multi-Backend**: Additional application VPCs with PSC attachments
- **Multi-Region**: DR with failover load balancing
- **Advanced Routing**: Host/path-based routing for multiple services

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the roadmap.

## Development

### Pre-commit Hooks

```bash
poetry install
poetry run pre-commit install --install-hooks --hook-type pre-commit --hook-type commit-msg
```

### Code Formatting

```bash
tofu fmt -recursive .
poetry run black . && poetry run isort .
```

### Security Scanning

```bash
poetry run semgrep scan --config=auto .
poetry run checkov --directory . --framework terraform
```

For complete development workflow, see [docs/PRE_COMMIT_SETUP.md](docs/PRE_COMMIT_SETUP.md).

## Branching Strategy

| Branch | Purpose | Deployment |
|--------|---------|------------|
| `main` | Integration branch | Not deployed |
| `nonprod` | Testing and validation | nonprod environment |
| `prod` | Production releases | prod environment |

All changes flow: `feature-branch` -> `main` -> `nonprod` -> `prod`

## License

This project is under a proprietary license. See [LICENSE.md](./LICENSE.md) for details.
