# Architecture

This document provides detailed architecture documentation for Vibetics CloudEdge, including current implementation, design decisions, and future roadmap.

## Design Principles

1. **Infrastructure-Only**: Edge networking and security; no application logic
2. **Defense-in-Depth**: Multiple security layers (WAF options, firewall, ingress policy, PSC)
3. **Private Connectivity**: Backends never exposed to public internet
4. **Cloud-Agnostic Design**: GCP first, extensible to AWS/Azure
5. **Separation of Concerns**: Each configuration manages a distinct layer
6. **Cost Optimization**: Flexible architecture supporting free and paid security options

## Current Architecture: Cloudflare Edge + PSC

The infrastructure uses **Cloudflare as the edge security layer** by default, combined with Private Service Connect (PSC) for backend connectivity.

### Traffic Flow (Default Configuration)

```
Internet
    |
    v
Cloudflare Global Network (proxied = true)
    |
    +---> Cloudflare WAF (OWASP Top 10, free)
    +---> Cloudflare DDoS Protection (free)
    +---> Cloudflare SSL/TLS Termination
    |
    | Cloudflare Origin Certificate (15-year, RSA 2048)
    |
    v
Regional External HTTPS Load Balancer (GCP)
    |
    +---> Regional Backend Service (EXTERNAL_MANAGED)
    |
    v
Ingress VPC Firewall (Cloudflare IPs only)
    |
    v
PSC Network Endpoint Group (PSC NEG)
    |
    | Private Service Connect
    |
    v
PSC Service Attachment (demo-vpc)
    |
    v
Internal HTTPS Load Balancer (INTERNAL_MANAGED)
    |
    v
Serverless NEG
    |
    v
Cloud Run Service (demo-web-app)
    | Ingress: INTERNAL_LOAD_BALANCER only
```

## Architecture Options

### Option A: Cloudflare Edge (Default)

**Configuration:**
```hcl
enable_cloudflare_proxy = true   # Cloudflare proxy enabled
enable_waf              = false  # Cloud Armor disabled
```

**Architecture Flow:**
```
User → Cloudflare (WAF/DDoS/CDN) → GCP LB → PSC → Cloud Run
       └── Free Protection ──┘
```

**Benefits:**
- ✅ $0/month for WAF and DDoS protection
- ✅ Global CDN and performance optimization
- ✅ Origin IP hidden from attackers
- ✅ Automatic SSL certificate management (15-year validity)
- ✅ Firewall automatically restricted to Cloudflare IPs

**Trade-offs:**
- Additional latency from Cloudflare hop (~10-50ms depending on edge location)
- Cloudflare Free tier has rate limiting (future consideration)
- Requires Cloudflare Origin CA Key for certificate generation

### Option B: GCP Edge

**Configuration:**
```hcl
enable_cloudflare_proxy = false  # Direct DNS resolution
enable_waf              = true   # Cloud Armor enabled
```

**Architecture Flow:**
```
User → DNS → GCP LB (Cloud Armor WAF) → PSC → Cloud Run
             └── Paid Protection ($16-91/mo) ──┘
```

**Benefits:**
- ✅ Lower latency (no Cloudflare hop)
- ✅ GCP-native observability and logging
- ✅ No external dependencies
- ✅ Supports Google-managed certificates or self-signed

**Trade-offs:**
- $16-91/month cost for Cloud Armor
- Origin IP exposed in DNS (unless additional measures taken)
- Manual certificate management (if not using Google-managed)

### Option C: Defense-in-Depth (Hybrid)

**Configuration:**
```hcl
enable_cloudflare_proxy = true   # Cloudflare as Layer 1
enable_waf              = true   # Cloud Armor as Layer 2
```

**Architecture Flow:**
```
User → Cloudflare (WAF Layer 1) → GCP LB (Cloud Armor Layer 2) → PSC → Cloud Run
       └── Free ──┘                └── Paid ($16-91/mo) ──┘
```

**Benefits:**
- ✅ Double WAF protection (Cloudflare + Cloud Armor)
- ✅ Redundant security if one layer is bypassed
- ✅ Both Cloudflare and GCP threat intelligence
- ✅ Compliance-friendly (multiple security controls)

**Trade-offs:**
- $16-91/month for Cloud Armor
- Higher latency (Cloudflare hop + double inspection)
- More complex troubleshooting

## Security Architecture Comparison

### Cloudflare WAF vs GCP Cloud Armor

| Aspect | Cloudflare WAF (Free) | GCP Cloud Armor |
|--------|----------------------|-----------------|
| **Cost** | $0/month | $5 policy + $11 rules + $0.75/M requests = $16-91/mo |
| **DDoS Protection** | Unlimited | Standard (no extra cost) |
| **Threat Intelligence** | Global (millions of sites) | GCP-specific |
| **OWASP Protection** | Top 10 (basic rules) | ModSecurity CRS v33 (10 specific rules) |
| **Managed Rules** | Limited on free tier | Full OWASP CRS |
| **Bot Management** | Basic on free tier | Advanced (paid feature) |
| **Adaptive Protection** | No | Yes (ML-based, learns app patterns) |
| **Observability** | Cloudflare dashboard | Cloud Logging, Cloud Monitoring |
| **Custom Rules** | Limited on free tier | Full custom CEL expressions |
| **Rate Limiting** | Basic on free tier | Advanced rate limiting |
| **Location** | Edge (before origin) | Origin (GCP load balancer) |

### When to Choose Each Option

**Choose Cloudflare Edge (Option A) if:**
- Cost optimization is priority
- Global CDN and performance needed
- Starting with MVP or small-scale deployment
- Comfortable with external dependency

**Choose GCP Edge (Option B) if:**
- 100% GCP-native required
- Lower latency critical (API services)
- Advanced observability needed
- Compliance requires GCP-only controls

**Choose Defense-in-Depth (Option C) if:**
- High-security requirements (finance, healthcare)
- Compliance mandates multiple security layers
- Budget allows $20-100/month for extra protection
- Redundancy valued over cost

## Certificate Management

### Cloudflare Origin Certificates (Default)

**When:** `enable_cloudflare_proxy = true`

**Resources Created:**
```hcl
tls_private_key.cloudflare_origin_key        # RSA 2048-bit key
tls_cert_request.cloudflare_origin_csr       # Certificate signing request
cloudflare_origin_ca_certificate.origin_cert # 15-year Cloudflare-signed cert
google_compute_region_ssl_certificate        # Upload to GCP
```

**Characteristics:**
- ✅ 15-year validity (no renewal needed for ~15 years)
- ✅ Free from Cloudflare
- ✅ Automatically trusted by Cloudflare proxy
- ⚠️ Only valid when traffic comes through Cloudflare
- ⚠️ Requires Cloudflare Origin CA Key

**Cloudflare SSL Mode:** Must be set to **"Full (strict)"** manually in Cloudflare dashboard

### Google-Managed Certificates

**When:** `enable_cloudflare_proxy = false` and `enable_self_signed_cert = false`

**Resources Created (in project-singleton):**
```hcl
google_compute_managed_ssl_certificate.external_https_lb_cert
```

**Characteristics:**
- ✅ Free from Google
- ✅ Automatic renewal (no management needed)
- ✅ Trusted by browsers
- ⚠️ Global resource (not regional)
- ⚠️ Cannot be used with regional load balancers currently
- ⚠️ Requires DNS validation

**Note:** The current implementation uses regional load balancers, which are incompatible with global managed certificates. This is why Cloudflare Origin Certificates or self-signed certificates are used.

### Self-Signed Certificates

**When:** `enable_self_signed_cert = true`

**Resources Created (in project-singleton):**
```hcl
tls_private_key.self_signed_key
tls_self_signed_cert.self_signed_cert
google_compute_region_ssl_certificate.external_https_lb_cert
```

**Characteristics:**
- ✅ Works with regional load balancers
- ✅ No external dependencies
- ✅ 1-year validity
- ⚠️ Browser warnings (not trusted)
- ⚠️ For testing/development only

## Connectivity: Private Service Connect (PSC)

### Why PSC Instead of VPC Peering?

| Aspect | VPC Peering | Private Service Connect |
|--------|-------------|------------------------|
| **IP Overlap** | Not allowed | Allowed (NAT handles translation) |
| **Scalability** | Limited by peering quota | Scales to 1000+ consumers |
| **Security Boundary** | Shares routing tables | Complete network isolation |
| **Multi-Tenancy** | Complex | Natural fit (each tenant = service attachment) |
| **Cross-Org** | Requires explicit peering | Works across organizations |
| **Producer Control** | Bidirectional trust | Producer controls access |

**Chosen Approach**: PSC provides better isolation for multi-tenant scenarios and avoids IP addressing conflicts.

### PSC Architecture Pattern

```
+------------------+          +------------------+
|    CORE (Ingress)|          |    DEMO-VPC      |
|  deploy/...core  |          |  deploy/...demo  |
+------------------+          +------------------+
|                  |          |                  |
| Ingress VPC      |   PSC    | Web VPC          |
| +-------------+  |          | +-------------+  |
| | External LB |  |          | | Internal LB |  |
| +------+------+  |          | +------+------+  |
|        |         |          |        |         |
| +------v------+  |          | +------v------+  |
| | PSC NEG     |------------->| PSC Service  |  |
| | (Consumer)  |  |          | | Attachment   |  |
| | Type:       |  |          | | (Producer)   |  |
| | PRIVATE_    |  |          | | Connection:  |  |
| | SERVICE_    |  |          | | ACCEPT_AUTO  |  |
| | CONNECT     |  |          | +------+------+  |
| +-------------+  |          |        |         |
|                  |          | +------v------+  |
+------------------+          | | Serverless  |  |
                              | | NEG         |  |
                              | +------+------+  |
                              |        |         |
                              | +------v------+  |
                              | | Cloud Run   |  |
                              | +-------------+  |
                              +------------------+
```

## Firewall Configuration

### Dynamic Source Ranges

The firewall rules adapt based on Cloudflare proxy status:

**When `enable_cloudflare_proxy = true`:**
```hcl
source_ranges = [
  "173.245.48.0/20",
  "103.21.244.0/22",
  "103.22.200.0/22",
  "103.31.4.0/22",
  "141.101.64.0/18",
  "108.162.192.0/18",
  "190.93.240.0/20",
  "188.114.96.0/20",
  "197.234.240.0/22",
  "198.41.128.0/17",
  "162.158.0.0/15",
  "104.16.0.0/13",
  "104.24.0.0/14",
  "172.64.0.0/13",
  "131.0.72.0/22"
]
```

**When `enable_cloudflare_proxy = false`:**
```hcl
source_ranges = var.allowed_https_source_ranges  # Default: ["0.0.0.0/0"]
```

**Security Benefit:** When Cloudflare proxy is enabled, the firewall automatically restricts traffic to only Cloudflare IP ranges, providing defense-in-depth even if WAF is bypassed.

## Configuration Layers

### Layer 1: Project Singleton

**Location**: `deploy/opentofu/gcp/project-singleton/`

**Purpose**: One-time project-level resources

| Resource | Description |
|----------|-------------|
| `google_project_service` | Enable required GCP APIs (compute, run, billing, logging) |
| `google_billing_budget` | Budget alerts at 50%, 80%, 100% thresholds |
| `google_logging_project_bucket_config` | Centralized logging with 30-day retention |
| `google_compute_region_ssl_certificate` OR `google_compute_managed_ssl_certificate` | SSL certificates (conditional) |

**Remote State Key**: `${project_id}-singleton`

**Outputs:**
- `external_https_lb_cert_id` - SSL certificate ID (used when Cloudflare proxy disabled)
- `enable_logging` - Logging status

### Layer 2: Demo VPC (Application Layer)

**Location**: `deploy/opentofu/gcp/demo-vpc/`

**Purpose**: Backend application VPC with PSC service attachment

| Resource | Description |
|----------|-------------|
| `google_compute_network.web_vpc` | Application VPC (no internet egress) |
| `google_compute_subnetwork.web_subnet` | 10.0.3.0/24 for workloads |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.99.0/24 for Internal ALB |
| `google_compute_subnetwork.psc_nat_subnet` | 10.0.100.0/24 for PSC NAT |
| `google_cloud_run_v2_service` | Demo web application |
| `google_compute_region_network_endpoint_group` | Serverless NEG for Cloud Run |
| `google_compute_region_backend_service` | Internal backend service |
| `google_compute_region_url_map` | Internal ALB URL routing |
| `google_compute_region_target_https_proxy` | Internal HTTPS proxy |
| `google_compute_forwarding_rule` | Internal forwarding rule |
| `google_compute_service_attachment` | PSC producer endpoint |

**Remote State Key**: `${project_id}-demo-vpc`

**Output**: `demo_web_app_psc_service_attachment_self_link` (consumed by core)

### Layer 3: Core (Ingress Layer)

**Location**: `deploy/opentofu/gcp/core/`

**Purpose**: Public-facing ingress with optional WAF and PSC consumer

| Resource | Description | Conditional |
|----------|-------------|-------------|
| `google_compute_network.ingress_vpc` | Ingress VPC for external traffic | Always |
| `google_compute_subnetwork.ingress_subnet` | 10.0.1.0/24 for ingress | Always |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.98.0/24 for External ALB | Always |
| `google_compute_firewall` | HTTPS from dynamic sources | Always |
| `google_compute_address` | Regional static external IP | Always |
| `google_compute_region_security_policy` | Cloud Armor WAF with OWASP rules | `enable_waf = true` |
| `tls_private_key.cloudflare_origin_key` | RSA 2048-bit key | `enable_cloudflare_proxy = true` |
| `tls_cert_request.cloudflare_origin_csr` | Certificate signing request | `enable_cloudflare_proxy = true` |
| `cloudflare_origin_ca_certificate.origin_cert` | Cloudflare Origin CA cert | `enable_cloudflare_proxy = true` |
| `google_compute_region_ssl_certificate.cloudflare_origin_cert` | Upload Cloudflare cert to GCP | `enable_cloudflare_proxy = true` |
| `google_compute_region_network_endpoint_group` | PSC NEG (consumer) | `enable_demo_web_app = true` |
| `google_compute_region_backend_service` | External backend service | `enable_demo_web_app = true` |
| `google_compute_region_url_map` | External LB URL routing | Always |
| `google_compute_region_target_https_proxy` | External HTTPS proxy | Always |
| `google_compute_forwarding_rule` | External forwarding rule | Always |
| `cloudflare_record` | DNS A record with dynamic proxy | Always |

**Remote State Dependencies**:
- Reads `singleton` for `enable_logging`, `external_https_lb_cert_id`
- Reads `demo-vpc` for `demo_web_app_psc_service_attachment_self_link`

## Cloud Armor WAF Rules

When `enable_waf = true`, the following OWASP ModSecurity CRS v33 rules are deployed:

| Priority | Rule ID | Protection | Action |
|----------|---------|------------|--------|
| 1000 | `sqli-v33-stable` | SQL injection | deny(403) |
| 1001 | `xss-v33-stable` | Cross-site scripting | deny(403) |
| 1002 | `lfi-v33-stable` | Local file inclusion | deny(403) |
| 1003 | `rfi-v33-stable` | Remote file inclusion | deny(403) |
| 1004 | `rce-v33-stable` | Remote code execution | deny(403) |
| 1006 | `methodenforcement-v33-stable` | HTTP method enforcement | deny(403) |
| 1007 | `scannerdetection-v33-stable` | Scanner/bot detection | deny(403) |
| 1008 | `protocolattack-v33-stable` | Protocol attack protection | deny(403) |
| 1009 | `sessionfixation-v33-stable` | Session fixation protection | deny(403) |
| 1010 | `nodejs-v33-stable` | Node.js exploit protection | deny(403) |
| 2147483647 | Default | Allow all other traffic | allow |

**Cost:** $5 (policy) + $11 (11 rules) + $0.75 per million requests

## Defense-in-Depth Layers

### Default Configuration (Cloudflare Edge)

| Layer | Control | Bypass Impact |
|-------|---------|---------------|
| 1. DNS | Cloudflare proxy | Direct IP access blocked by firewall |
| 2. Edge WAF | Cloudflare OWASP rules | Malicious requests reach GCP |
| 3. Firewall | Cloudflare IP ranges only | Only Cloudflare can reach GCP |
| 4. Transport | TLS encryption (Origin CA) | Traffic visible in transit |
| 5. Ingress Policy | Cloud Run internal only | Direct Cloud Run URL blocked |
| 6. PSC | Private connectivity | No lateral movement possible |

### With Cloud Armor Enabled (Hybrid)

| Layer | Control | Bypass Impact |
|-------|---------|---------------|
| 1. DNS | Cloudflare proxy | Direct IP access blocked by firewall |
| 2. Edge WAF | Cloudflare OWASP rules | Still protected by Cloud Armor |
| 3. Firewall | Cloudflare IP ranges only | Only Cloudflare can reach GCP |
| 4. Origin WAF | Cloud Armor OWASP rules | Malicious requests reach LB |
| 5. Transport | TLS encryption (Origin CA) | Traffic visible in transit |
| 6. Ingress Policy | Cloud Run internal only | Direct Cloud Run URL blocked |
| 7. PSC | Private connectivity | No lateral movement possible |

## Design Decisions

### Regional vs Global Load Balancer

**Chosen**: Regional External ALB (EXTERNAL_MANAGED)

| Aspect | Regional | Global |
|--------|----------|--------|
| **Pricing** | Lower (Standard tier) | Higher (Premium tier) |
| **Latency** | Single region | Anycast routing |
| **SSL Certs** | Regional resource | Global resource |
| **PSC Compatibility** | Full support | Limited |
| **Managed Certs** | Not supported | Supported |
| **Use Case** | Single-region MVP | Multi-region DR |

**Rationale**: Regional LB provides:
- Lower cost (Standard network tier ~40% cheaper)
- PSC compatibility
- Sufficient for single-region deployment
- Compatible with Cloudflare Origin CA certificates

**Future**: Global LB will be added for multi-region DR, once multi-region backends are deployed.

### Cloudflare Proxy: Enabled by Default

**Decision**: `enable_cloudflare_proxy = true` (default)

**Reasoning**:
- $0 cost for WAF, DDoS, and SSL
- Better security posture out-of-box
- Hides origin IP from attackers
- Global CDN improves performance
- 15-year certificate validity (low maintenance)

**Trade-off**: Additional latency (acceptable for most use cases)

### Cloud Armor: Disabled by Default

**Decision**: `enable_waf = false` (default)

**Reasoning**:
- Cloudflare provides adequate protection for most scenarios
- Cost optimization (save $16-91/month)
- Can be enabled when needed (compliance, high-security)
- Easy toggle via feature flag

### Cloud Run IAM: allUsers

**Decision**: `roles/run.invoker` granted to `allUsers`

**Reasoning**:
- Load balancer cannot provide service account credentials
- Security enforced at network layer (WAF, firewall, PSC)
- Cloud Run ingress policy blocks direct URL access
- Production apps should implement app-level auth

## Future Architecture

### Multi-Backend Support

Additional application VPCs connect via PSC:

```
                        +------------------+
                        |      CORE        |
                        +------------------+
                        | External LB      |
                        |    |             |
                        |    +---> URL Map |
                        |    |     |   |   |
                        +----+-----+---+---+
                             |     |   |
            +----------------+     |   +----------------+
            |                      |                    |
            v                      v                    v
    +---------------+     +---------------+     +---------------+
    | PSC Consumer  |     | PSC Consumer  |     | PSC Consumer  |
    | (app1)        |     | (app2)        |     | (app3)        |
    +-------+-------+     +-------+-------+     +-------+-------+
            |                     |                     |
            v                     v                     v
    +---------------+     +---------------+     +---------------+
    | App1 VPC      |     | App2 VPC      |     | App3 VPC      |
    | (Cloud Run)   |     | (GKE)         |     | (Compute)     |
    +---------------+     +---------------+     +---------------+
```

**URL Map Routing**:
- `app1.domain.com` -> App1 PSC backend
- `app2.domain.com` -> App2 PSC backend
- `app3.domain.com` -> App3 PSC backend

### Multi-Region Disaster Recovery

```
                            Global Load Balancer
                                    |
                    +---------------+---------------+
                    |                               |
            +-------v-------+               +-------v-------+
            | Region A      |               | Region B      |
            | (Primary)     |               | (Secondary)   |
            +---------------+               +---------------+
            | - WAF         |               | - WAF         |
            | - Ingress VPC |               | - Ingress VPC |
            | - PSC         |               | - PSC         |
            | - App VPCs    |               | - App VPCs    |
            +---------------+               +---------------+
```

**Failover Strategy**:
- Active-passive with health-based failover
- RTO: 60 seconds (health check interval)
- RPO: Application-dependent (data replication)

### Multi-Cloud Expansion

```
modules/
├── gcp/          # Current implementation
├── aws/          # Planned: ALB, WAF, PrivateLink
└── azure/        # Planned: Application Gateway, Private Endpoint
```

**Abstraction Layer**:
- Common variable interface across clouds
- Provider-specific implementations
- Unified deployment scripts
- Cloud-agnostic PSC equivalent (PrivateLink, Private Endpoint)

## Cost Optimization Summary

| Configuration | Monthly Cost | Use Case |
|---------------|--------------|----------|
| **Cloudflare Edge** (default) | ~$23 | MVP, startups, cost-sensitive |
| **GCP Edge** | ~$39-114 | GCP-native, compliance, low-latency APIs |
| **Defense-in-Depth** | ~$39-114 | High-security, finance, healthcare |

**Breakdown:**
- Load Balancer forwarding rule: ~$18/month
- Regional IP (Standard tier): ~$5/month
- Cloud Armor (if enabled): $16-91/month
- Cloudflare: $0/month (free tier)
