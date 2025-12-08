# Vibetics CloudEdge

Cloud-agnostic edge infrastructure managed by OpenTofu, providing secure ingress with WAF, load balancing, and Private Service Connect (PSC) connectivity for backend applications.

## Overview

Vibetics CloudEdge provides a **modular secure baseline infrastructure** for deploying applications behind a unified edge security layer. The current implementation focuses on GCP with planned expansion to AWS and Azure.

**What This Project Provides** (Infrastructure-Only):

- Edge security with Cloud Armor WAF (OWASP CRS rules)
- Regional HTTPS Load Balancer with SSL termination
- Private Service Connect (PSC) for cross-VPC connectivity
- Ingress VPC with firewall rules
- Cloudflare DNS integration
- Billing budget monitoring

**What This Project Does NOT Provide** (Application Responsibility):

- API Gateway (authentication, rate limiting, request transformation)
- Application-level security (OAuth, JWT, API keys)
- Business logic or application code

## Architecture

```
                            INTERNET
                               |
                    +----------v----------+
                    |   Cloudflare DNS    |
                    | demo-web-app.domain |
                    +----------+----------+
                               |
+------------------------------v-------------------------------+
|                    CORE CONFIGURATION                        |
|                    deploy/opentofu/gcp/core                  |
|                                                              |
|  +------------------+    +--------------------+              |
|  | Regional Static  |    |  Cloud Armor WAF   |              |
|  | External IP      |--->|  - SQLi protection |              |
|  +------------------+    |  - XSS protection  |              |
|                          |  - RCE protection  |              |
|                          |  - Scanner detect  |              |
|                          +----------+---------+              |
|                                     |                        |
|  +----------------------------------v---------------------+  |
|  |           Regional External HTTPS Load Balancer       |  |
|  |  +----------------+  +------------------+              |  |
|  |  | SSL Cert       |  | URL Map          |              |  |
|  |  | (Self-signed)  |  | (Backend routing)|              |  |
|  |  +----------------+  +------------------+              |  |
|  +----------------------------------+---------------------+  |
|                                     |                        |
|  +----------------------------------v---------------------+  |
|  |                    Ingress VPC                         |  |
|  |  +------------------+    +------------------------+    |  |
|  |  | Ingress Subnet   |    | Proxy-Only Subnet      |    |  |
|  |  | (10.0.1.0/24)    |    | (10.0.98.0/24)         |    |  |
|  |  +------------------+    +------------------------+    |  |
|  |                                                        |  |
|  |  +--------------------------------------------------+  |  |
|  |  | Firewall: Allow HTTPS from configured sources   |  |  |
|  |  +--------------------------------------------------+  |  |
|  +--------------------------------------------------------+  |
|                                     |                        |
|  +----------------------------------v---------------------+  |
|  |           PSC Consumer (Private Service Connect)       |  |
|  |  +--------------------------------------------------+  |  |
|  |  | PSC NEG -> Service Attachment in demo-vpc        |  |  |
|  |  +--------------------------------------------------+  |  |
|  +--------------------------------------------------------+  |
+--------------------------------------------------------------+
                               |
                               | Private Service Connect
                               |
+------------------------------v-------------------------------+
|                   DEMO-VPC CONFIGURATION                     |
|                   deploy/opentofu/gcp/demo-vpc               |
|                                                              |
|  +--------------------------------------------------------+  |
|  |                      Web VPC                           |  |
|  |  +------------------+    +------------------------+    |  |
|  |  | Web Subnet       |    | Proxy-Only Subnet      |    |  |
|  |  | (10.0.3.0/24)    |    | (10.0.99.0/24)         |    |  |
|  |  +------------------+    +------------------------+    |  |
|  |                          +------------------------+    |  |
|  |                          | PSC NAT Subnet         |    |  |
|  |                          | (10.0.100.0/24)        |    |  |
|  |                          +------------------------+    |  |
|  +--------------------------------------------------------+  |
|                               |                              |
|  +---------------------------v----------------------------+  |
|  |              Internal Application Load Balancer         |  |
|  |  +------------------+    +------------------------+    |  |
|  |  | Internal ALB     |    | Serverless NEG         |    |  |
|  |  | URL Map          |--->| (Cloud Run service)    |    |  |
|  |  +------------------+    +------------------------+    |  |
|  +--------------------------------------------------------+  |
|                               |                              |
|  +---------------------------v----------------------------+  |
|  |           PSC Service Attachment (Producer)             |  |
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

## Deployment Structure

The infrastructure is organized into three OpenTofu configurations that must be deployed in order:

```
deploy/opentofu/gcp/
├── project-singleton/    # 1. Project-level resources (deploy first)
│   ├── main.tf          #    Backend config, providers
│   ├── project-singleton.tf  # Billing, logging, APIs
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
    ├── core.tf          #    Ingress VPC, WAF, External LB, PSC consumer, DNS
    ├── variables.tf
    └── outputs.tf
```

**Deployment Order Dependency**:

1. `project-singleton` - Creates project-level resources, outputs read by other configs
2. `demo-vpc` - Creates backend VPC and PSC service attachment, outputs service attachment ID
3. `core` - Creates ingress VPC and PSC consumer that connects to demo-vpc

## Quick Start

For detailed prerequisites and troubleshooting, see [docs/QUICKSTART.md](docs/QUICKSTART.md).

### Prerequisites

- OpenTofu >= 1.6.0
- GCP project with billing enabled
- Cloudflare account with DNS zone
- Required GCP APIs enabled (see QUICKSTART.md)

### Deploy

```bash
# 1. Clone and configure
git clone <repository-url>
cd vibetics-cloudedge
cp .env.example .env
# Edit .env with your project settings

# 2. Source environment
source .env

# 3. Deploy in order
./scripts/deploy.sh
```

### Teardown

```bash
./scripts/teardown.sh
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture, PSC patterns, future roadmap |
| [docs/GCP.md](docs/GCP.md) | GCP resource reference by configuration |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Variables, feature flags, environment setup |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Prerequisites, IAM setup, deployment guide |
| [docs/SECURITY.md](docs/SECURITY.md) | Threat modeling, security controls, STRIDE analysis |
| [docs/TESTING.md](docs/TESTING.md) | Testing strategy, Terratest integration tests |
| [docs/CI_WORKFLOW.md](docs/CI_WORKFLOW.md) | CI/CD pipeline documentation |
| [docs/PRE_COMMIT_SETUP.md](docs/PRE_COMMIT_SETUP.md) | Pre-commit hooks setup guide |

## Security

This infrastructure implements defense-in-depth with multiple security layers:

| Layer | Component | Protection |
|-------|-----------|------------|
| Edge | Cloud Armor WAF | SQLi, XSS, RCE, LFI, RFI, scanner detection |
| Network | Ingress VPC Firewall | Source IP restriction (configurable) |
| Transport | SSL/TLS | Encryption in transit |
| Backend | Cloud Run Ingress Policy | Internal load balancer traffic only |
| Connectivity | Private Service Connect | No public IP exposure for backends |

For detailed security documentation, see [docs/SECURITY.md](docs/SECURITY.md).

## Future Expansion

The architecture supports planned expansion:

- **Multi-Cloud**: AWS and Azure modules (directory structure ready)
- **Multi-Backend**: Additional application VPCs with PSC attachments
- **Multi-Region**: DR with failover load balancing
- **Production Certificates**: Google-managed or custom certificates

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
