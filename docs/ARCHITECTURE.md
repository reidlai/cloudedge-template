# Architecture

This document provides detailed architecture documentation for Vibetics CloudEdge, including current implementation, design decisions, and future roadmap.

## Design Principles

1. **Infrastructure-Only**: Edge networking and security; no application logic
2. **Defense-in-Depth**: Multiple security layers (WAF, firewall, ingress policy, PSC)
3. **Private Connectivity**: Backends never exposed to public internet
4. **Cloud-Agnostic Design**: GCP first, extensible to AWS/Azure
5. **Separation of Concerns**: Each configuration manages a distinct layer

## Current Architecture: PSC-Based Connectivity

The infrastructure uses Private Service Connect (PSC) to connect the public-facing ingress layer to private backend VPCs without exposing backends to the internet.

### Traffic Flow

```
Internet
    |
    v
Cloudflare DNS (A record -> External LB IP)
    |
    v
Regional External HTTPS Load Balancer
    |
    +---> Cloud Armor WAF (OWASP CRS rules)
    |
    v
Regional Backend Service (EXTERNAL_MANAGED)
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
```

### Why PSC Instead of VPC Peering?

| Aspect | VPC Peering | Private Service Connect |
|--------|-------------|------------------------|
| **IP Overlap** | Not allowed | Allowed (NAT handles translation) |
| **Scalability** | Limited by peering quota | Scales to 1000+ consumers |
| **Security Boundary** | Shares routing tables | Complete network isolation |
| **Multi-Tenancy** | Complex | Natural fit (each tenant = service attachment) |
| **Cross-Org** | Requires explicit peering | Works across organizations |

**Chosen Approach**: PSC provides better isolation for multi-tenant scenarios and avoids IP addressing conflicts that would occur with VPC peering.

### Connectivity Pattern

```
+------------------+          +------------------+
|    CORE (Core)   |          |    DEMO-VPC      |
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
| +-------------+  |          | | (Producer)   |  |
|                  |          | +------+------+  |
+------------------+          |        |         |
                              | +------v------+  |
                              | | Serverless  |  |
                              | | NEG         |  |
                              | +------+------+  |
                              |        |         |
                              | +------v------+  |
                              | | Cloud Run   |  |
                              | +-------------+  |
                              +------------------+
```

## Configuration Layers

### Layer 1: Project Singleton

**Location**: `deploy/opentofu/gcp/project-singleton/`

**Purpose**: One-time project-level resources

| Resource | Description |
|----------|-------------|
| `google_project_service` | Enable required GCP APIs (compute, run, billing, logging) |
| `google_billing_budget` | Budget alerts at 50%, 80%, 100% thresholds |
| `google_logging_project_bucket_config` | Centralized logging with 30-day retention |

**Remote State Key**: `${project_id}-singleton`

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

**Purpose**: Public-facing ingress with WAF and PSC consumer

| Resource | Description |
|----------|-------------|
| `google_compute_network.ingress_vpc` | Ingress VPC for external traffic |
| `google_compute_subnetwork.ingress_subnet` | 10.0.1.0/24 for ingress |
| `google_compute_subnetwork.proxy_only_subnet` | 10.0.98.0/24 for External ALB |
| `google_compute_firewall` | HTTPS from configurable sources |
| `google_compute_address` | Regional static external IP |
| `google_compute_security_policy` | Cloud Armor WAF with OWASP rules |
| `google_compute_region_ssl_certificate` | Self-signed SSL certificate |
| `google_compute_region_network_endpoint_group` | PSC NEG (consumer) |
| `google_compute_region_backend_service` | External backend service with WAF |
| `google_compute_region_url_map` | External LB URL routing |
| `google_compute_region_target_https_proxy` | External HTTPS proxy |
| `google_compute_forwarding_rule` | External forwarding rule |
| `cloudflare_record` | DNS A record for subdomain |

**Remote State Dependencies**:

- Reads `singleton` for `enable_logging`
- Reads `demo-vpc` for `demo_web_app_psc_service_attachment_self_link`

## Security Architecture

### WAF Rules (Cloud Armor)

The edge WAF implements OWASP ModSecurity Core Rule Set v3.3:

| Priority | Rule | Description |
|----------|------|-------------|
| 1000 | `sqli-v33-stable` | SQL injection protection |
| 1001 | `xss-v33-stable` | Cross-site scripting protection |
| 1002 | `lfi-v33-stable` | Local file inclusion protection |
| 1003 | `rfi-v33-stable` | Remote file inclusion protection |
| 1004 | `rce-v33-stable` | Remote code execution protection |
| 1006 | `methodenforcement-v33-stable` | HTTP method enforcement |
| 1007 | `scannerdetection-v33-stable` | Scanner/bot detection |
| 1008 | `protocolattack-v33-stable` | Protocol attack protection |
| 1009 | `sessionfixation-v33-stable` | Session fixation protection |
| 1010 | `nodejs-v33-stable` | Node.js exploit protection |
| 2147483647 | Default allow | Allow all other traffic |

### Network Security

```
Internet
    |
    +--[Cloudflare]--> Regional External IP
    |                        |
    |                   Cloud Armor WAF
    |                        | (blocks malicious traffic)
    |                        v
    |                   Ingress VPC Firewall
    |                        | (source IP restriction)
    |                        v
    |                   External LB
    |                        | (SSL termination)
    |                        v
    |                   PSC Consumer
    |                        | (private connectivity)
    |                        v
    |                   PSC Producer
    |                        |
    |                   Internal LB
    |                        |
    |                        v
    |                   Cloud Run
    |                   (INTERNAL_LOAD_BALANCER only)
```

### Defense-in-Depth Layers

| Layer | Control | Bypass Impact |
|-------|---------|---------------|
| 1. DNS | Cloudflare proxy (optional) | Direct IP access possible |
| 2. WAF | Cloud Armor OWASP rules | Malicious requests reach LB |
| 3. Firewall | Source IP restriction | Any IP can reach ingress |
| 4. Transport | TLS encryption | Traffic visible in transit |
| 5. Ingress Policy | Cloud Run internal only | Direct Cloud Run URL access |
| 6. PSC | Private connectivity | Lateral movement from VPC |

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

**Abstraction Layer** (future):

- Common variable interface across clouds
- Provider-specific implementations
- Unified deployment scripts

## Design Decisions

### Regional vs Global Load Balancer

**Chosen**: Regional External ALB (EXTERNAL_MANAGED)

| Aspect | Regional | Global |
|--------|----------|--------|
| **Pricing** | Lower | Higher |
| **Latency** | Single region | Anycast routing |
| **SSL Certs** | Regional resource | Global resource |
| **PSC Compatibility** | Full support | Limited |
| **Use Case** | Single-region MVP | Multi-region DR |

**Rationale**: Regional LB provides PSC compatibility and lower cost for single-region deployment. Global LB will be added for multi-region DR.

### Self-Signed vs Managed Certificates

**Current**: Self-signed certificates for demo/testing

**Production Path**:

1. Google-managed certificates (free, auto-renewed)
2. Custom certificates via Certificate Manager
3. Cloudflare Origin certificates

### Cloud Run IAM: allUsers

**Decision**: `roles/run.invoker` granted to `allUsers`

**Reasoning**:

- Load balancer cannot provide service account credentials when forwarding
- Security enforced at network layer (WAF, firewall, PSC)
- Cloud Run ingress policy blocks direct URL access
- Production apps should implement app-level auth

### Cloudflare DNS: Proxied vs Direct

**Current**: `proxied = false` (direct routing to GCP LB)

**Reasoning**:

- GCP Cloud Armor provides WAF functionality
- Direct routing allows GCP-native observability
- Cloudflare proxy would add latency
- Future: Enable proxy for additional DDoS protection if needed
