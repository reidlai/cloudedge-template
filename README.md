# Vibetics CloudEdge

This repository contains the Infrastructure as Code (IaC) for the Vibetics CloudEdge platform, managed by OpenTofu. The purpose of this project is to provide a secure, standardized, and cloud-agnostic baseline infrastructure that can be deployed rapidly and consistently across multiple cloud providers.

## Infrastructure Architecture

### Overview

The Vibetics CloudEdge platform provides a **6-layer secure baseline infrastructure** designed for cloud-agnostic deployments. This MVP (Feature 001) focuses on establishing the foundational security and networking layers with a demo Cloud Run backend for validation.

**Current MVP Scope**:
- ✅ Edge security layer (WAF with DDoS protection)
- ✅ Global HTTPS load balancer with domain-based routing capability
- ✅ Ingress and Egress VPCs with firewall rules
- ✅ Demo Cloud Run backend (single region, testing/validation only)
- ✅ Serverless NEG connectivity (Google-managed private networking for Cloud Run)
- ✅ CIS compliance, observability, mandatory resource tagging

**Note**: CDN is **optional** and excluded from MVP as it's only required for static content caching. The WAF (Cloud Armor) provides DDoS protection and the Load Balancer hides backend IP addresses.

### Scope: Infrastructure-Only Deployment

**This project provides INFRASTRUCTURE-ONLY deployment.** API management capabilities (authentication, authorization, rate limiting, request validation, API versioning, analytics) are **OUT OF SCOPE** and are the responsibility of applications deployed on this infrastructure.

**What IS Included** (Network-Level Security):
- ✅ WAF for DDoS protection
- ✅ Firewall rules and VPC isolation
- ✅ Load Balancer with domain-based routing
- ✅ Serverless NEG (Google-managed private connectivity for Cloud Run backends)
- ✅ Distributed tracing for infrastructure observability

**What is NOT Included** (Application-Level Security):
- ❌ API Gateway (authentication, rate limiting, request transformation)
- ❌ API-level security policies (API keys, OAuth, JWT validation)
- ❌ API analytics and developer portal

**Security Boundary**: The baseline infrastructure provides **network-level security** (WAF, firewall, VPC isolation, Serverless NEG private connectivity). Applications are responsible for **application-level security** (authentication, authorization, input validation). Applications must implement their own API security within their service code or deploy API Gateway (Cloud Endpoints/Apigee) as a separate feature.

**Demo Backend Access**: The demo Cloud Run service uses `allUsers` IAM binding for unauthenticated access from the load balancer. This is intentional for infrastructure validation. Production applications MUST implement proper authentication mechanisms.

For detailed scope information, see [Feature Specification](specs/001-create-cloud-agnostic/spec.md#scope-clarification).

**Future Extensibility** (Features 002-003):
- 🔜 Multi-backend support: Application teams can deploy Cloud Run, GKE, or Compute Engine VMs
- 🔜 True Private Service Connect (PSC) with service attachments for GKE/VM backends (full network isolation)
- 🔜 Multi-region disaster recovery with automatic health-based failover
- 🔜 Production application VPC onboarding workflow

### Current Architecture: Single-Region MVP with Demo Backend

The following diagram shows the **implemented architecture** for this feature:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INTERNET (External Client)                        │
│                     curl -k -H "Host: example.com" https://34.117.156.60    │
└────────────────────────────────────┬────────────────────────────────────────┘
                                     │
                                     │ HTTPS (Port 443)
                                     │
                          ┌──────────▼──────────┐
                          │  Global External IP │
                          │   34.117.156.60     │
                          └──────────┬──────────┘
                                     │
┌────────────────────────────────────┼────────────────────────────────────────┐
│                         EDGE SECURITY LAYER                                 │
│                                    │                                        │
│                          ┌─────────▼─────────┐                              │
│                          │   Cloud Armor     │                              │
│                          │      (WAF)        │                              │
│                          │  - Rate limiting  │                              │
│                          │  - DDoS protection│                              │
│                          │  - OWASP rules    │                              │
│                          └─────────┬─────────┘                              │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │
┌────────────────────────────────────┼────────────────────────────────────────┐
│                         LOAD BALANCING LAYER                                │
│                            (Ingress VPC)                                    │
│                                    │                                        │
│                          ┌─────────▼──────────┐                             │
│                          │  HTTPS Load Balancer│                            │
│                          │  - SSL termination  │                            │
│                          │  - URL map routing  │                            │
│                          │  - Host: example.com│                            │
│                          └─────────┬───────────┘                            │
│                                    │                                        │
│                          ┌─────────▼───────────┐                            │
│                          │   Backend Service   │                            │
│                          │ (nonprod-demo-api-  │                            │
│                          │      backend)       │                            │
│                          │  - Health checks    │                            │
│                          │  - Load distribution│                            │
│                          └─────────┬───────────┘                            │
│                                    │                                        │
│                          ┌─────────▼───────────┐                            │
│                          │  Serverless NEG     │                            │
│                          │ (Network Endpoint   │                            │
│                          │      Group)         │                            │
│                          └─────────┬───────────┘                            │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │
                                     │ Internal traffic only
                                     │
┌────────────────────────────────────┼────────────────────────────────────────┐
│                      CLOUD RUN BACKEND (Serverless)                         │
│                                    │                                        │
│                                    │ Google-managed private connectivity    │
│                                    │ (Serverless NEG handles routing)       │
│                                    │                                        │
│                          ┌─────────▼───────────┐                            │
│                          │   Cloud Run Service │                            │
│                          │  nonprod-demo-api   │                            │
│                          │                     │                            │
│                          │  Ingress Policy:    │                            │
│                          │  INGRESS_TRAFFIC_   │                            │
│                          │  INTERNAL_LOAD_     │                            │
│                          │  BALANCER           │                            │
│                          │                     │                            │
│                          │  IAM: roles/run.    │                            │
│                          │       invoker →     │                            │
│                          │       allUsers      │                            │
│                          │                     │                            │
│                          │  Container:         │                            │
│                          │  us-docker.pkg.dev/ │                            │
│                          │  cloudrun/container/│                            │
│                          │  hello              │                            │
│                          │                     │                            │
│                          │  Note: No VPC       │                            │
│                          │  Connector needed - │                            │
│                          │  Serverless NEG     │                            │
│                          │  provides direct    │                            │
│                          │  connectivity       │                            │
│                          └─────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Security Controls

**Defense-in-Depth Strategy**: This architecture implements multiple security layers to protect against various attack vectors.

| Layer | Component | Security Feature | Purpose |
|-------|-----------|------------------|---------|
| **Edge** | Cloud Armor (WAF) | Rate limiting, DDoS protection, OWASP rules | Blocks malicious traffic before it reaches infrastructure |
| **Ingress VPC** | Firewall Source Restriction | Restricts HTTPS traffic to Google Cloud Load Balancer IPs (`35.191.0.0/16`, `130.211.0.0/22`) | **Defense-in-depth**: Even if WAF is bypassed, only GCP load balancer IPs can reach the ingress layer. Override via `allowed_https_source_ranges` variable for testing. |
| **Load Balancer** | SSL Certificate | TLS 1.2+ encryption | Encrypts data in transit |
| **Load Balancer** | URL Map | Domain-based routing via Host header | Routes traffic to correct backend based on hostname |
| **Backend** | Serverless NEG | Serverless network endpoint | Connects load balancer to Cloud Run without public exposure |
| **Backend** | Cloud Run Ingress | `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` | **Blocks direct public access**, allows only load balancer traffic |
| **Backend** | IAM Policy | `roles/run.invoker` for `allUsers` | **INTENTIONAL for load balancer forwarding**: Cloud Run requires IAM authentication, but Google Cloud Load Balancers cannot provide service account credentials when forwarding traffic. The `allUsers` binding allows the LB to invoke the service. Security is enforced at network layer (WAF, firewall, ingress policy) NOT at Cloud Run IAM layer. |
| **Backend** | Serverless NEG | Google-managed networking | Direct Load Balancer → Cloud Run connectivity via Google's private network (no VPC Connector needed for serverless backends) |

### Access Validation

**✅ Allowed Traffic Path:**
```bash
curl -k -H "Host: example.com" https://34.117.156.60
# → Cloud Armor → HTTPS LB → Backend Service → Serverless NEG → Cloud Run
# Result: HTTP 200 OK with demo API response
```

**❌ Blocked Traffic Path:**
```bash
curl https://nonprod-demo-api-vbuysgm44q-pd.a.run.app
# → Direct to Cloud Run URL
# Result: HTTP 403/404 (blocked by INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER policy)
```

### VPC Connectivity Scenarios

| Scenario                                          | Recommended Solution                               | Why It's Better                                                                                                                            |
| :------------------------------------------------ | :------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------|
| Ingress VPC to Cloud Run (Same Project/Organization)        | Internal ALB + Serverless NEG + Cloud Run        | Simpler to configure than PSC, lower complexity, and avoids the "managed service" abstraction when one is not needed.                     |
| Ingress VPC to VPC B (Different Projects/Organizations) | Private Service Connect (PSC)                      | This is the main use case for PSC. It is designed specifically to allow private consumption of a "published service" across security or administrative boundaries without VPC peering. |

---

### Future Architecture: Multi-Backend Support (Features 002-003)

The baseline infrastructure is **architected to support** multiple backend types and multi-region deployments. Future features will extend (not replace) the current architecture.

#### Planned Capabilities

**Multi-Backend Support** (Future Feature 002):
- Application teams will be able to deploy their own VPCs with Cloud Run, GKE clusters, or Compute Engine VMs
- Each application VPC connects to the central load balancer via Private Service Connect (PSC)
- No public IPs on backend services (all traffic flows through central WAF)
- Domain-based routing maps hostnames to specific application VPCs (e.g., `app1.example.com` → App1 VPC)

**Multi-Region Disaster Recovery** (Future Feature 003):
- Primary + secondary region configuration per application
- Automatic health-based failover (60-second RTO)
- Optional geo-affinity routing (EU users → europe-west1)
- Active-passive or active-active traffic distribution strategies

#### Target Architecture Diagram

```
                                    INTERNET
                                       ↓
                          ┌────────────────────────┐
                          │  Global Anycast IP     │
                          └───────────┬────────────┘
                                      │
┌─────────────────────────────────────┼─────────────────────────────────────┐
│                          EDGE SECURITY LAYER                               │
│                          ┌──────────▼──────────┐                           │
│                          │   Cloud Armor (WAF) │                           │
│                          │  + DDoS protection  │                           │
│                          └──────────┬──────────┘                           │
│                                     │                                      │
│                          ┌──────────▼──────────┐                           │
│                          │   Cloud CDN         │ (OPTIONAL - only for     │
│                          │  (if static content)│  static content caching) │
│                          └──────────┬──────────┘                           │
└─────────────────────────────────────┼─────────────────────────────────────┘
                                      │
┌─────────────────────────────────────┼─────────────────────────────────────┐
│           GLOBAL LOAD BALANCER (Ingress VPC)                               │
│                    ┌────────────────▼────────────────┐                     │
│                    │  HTTPS Load Balancer            │                     │
│                    │  - Multi-region DR              │                     │
│                    │  - Host-based routing           │                     │
│                    └────────────────┬────────────────┘                     │
│                    ┌────────────────▼────────────────┐                     │
│                    │      URL Map & Host Rules       │                     │
│                    │  app1.example.com → App1 VPC    │                     │
│                    │  app2.example.com → App2 VPC    │                     │
│                    │  app3.example.com → App3 VPC    │                     │
│                    └─────┬──────────┬────────┬───────┘                     │
└──────────────────────────┼──────────┼────────┼─────────────────────────────┘
                           │          │        │
        ┌──────────────────┘          │        └──────────────────┐
        │                             │                           │
        │                             │                           │
┌───────▼───────┐          ┌──────────▼────────┐         ┌───────▼────────┐
│ Backend Svc 1 │          │  Backend Svc 2    │         │ Backend Svc 3  │
│ (Cloud Run)   │          │  (GKE)            │         │ (Compute VMs)  │
│ Multi-region  │          │  Multi-region     │         │ Multi-region   │
└───────┬───────┘          └──────────┬────────┘         └────────┬───────┘
        │                             │                           │
┌───────▼────────────────────────────────────────────────────────▼────────┐
│               PRIVATE SERVICE CONNECT (PSC) LAYER                        │
│   ┌───────────┐         ┌───────────┐         ┌───────────┐            │
│   │ PSC NEG   │         │ PSC NEG   │         │ PSC NEG   │            │
│   │ Serverless│         │ VM IP:PORT│         │ VM IP:PORT│            │
│   └─────┬─────┘         └─────┬─────┘         └─────┬─────┘            │
└─────────┼─────────────────────┼─────────────────────┼──────────────────┘
          │                     │                     │
┌─────────▼──────┐    ┌─────────▼──────┐    ┌─────────▼──────┐
│   App1 VPC     │    │   App2 VPC     │    │   App3 VPC     │
│ (Cloud Run)    │    │   (GKE)        │    │(Compute VMs)   │
│                │    │                │    │                │
│ ┌────────────┐ │    │ ┌────────────┐ │    │ ┌────────────┐ │
│ │ Cloud Run  │ │    │ │GKE Cluster │ │    │ │ Managed    │ │
│ │ Service    │ │    │ │+ K8s Svc   │ │    │ │ Instance   │ │
│ │ (Internal) │ │    │ │  (Internal)│ │    │ │ Group (MIG)│ │
│ │            │ │    │ │            │ │    │ │            │ │
│ │ + Firewall │ │    │ │ + Firewall │ │    │ │ + Firewall │ │
│ └────────────┘ │    │ └────────────┘ │    │ └────────────┘ │
└────────────────┘    └────────────────┘    └────────────────┘
```

**Key Differences from MVP**:
- **Multiple Application VPCs**: Each application team deploys their own isolated VPC
- **Multi-Backend Types**: Support for Cloud Run, GKE, and Compute Engine VMs
- **Multi-Region**: Primary + secondary regions for each backend with automatic failover
- **Production Workloads**: Real application services (not just demo/testing)

**Architecture Readiness**:
- ✅ URL Map already supports multiple host rules (extensible)
- ✅ Backend services + NEG pattern works for all backend types
- ✅ PSC demonstrated with demo backend (reusable for production)
- ✅ Global Load Balancer natively supports multi-region backends

**No Rework Required**: Future features will add new modules and configuration without changing the baseline infrastructure.

## Project Skeleton

```
.
├── .github/workflows/      # CI/CD pipelines (e.g., ci.yml)
├── deploy/docker/          # Dockerfile and related container assets
├── features/               # Cucumber BDD scenarios for integration testing
├── modules/                # Reusable OpenTofu modules for infrastructure components
│   ├── aws/                # (Future) AWS-specific modules
│   ├── azure/              # (Future) Azure-specific modules
│   └── gcp/                # GCP-specific modules (WAF, CDN, VPC, etc.)
├── scripts/                # Helper scripts for deployment and teardown
├── tests/                  # Automated tests (unit, integration, contract)
│   ├── contract/           # Contract tests (e.g., Checkov)
│   ├── integration/        # Integration tests (Terratest/Go)
│   └── unit/               # Unit tests (*.tftest.hcl)
├── threat_modelling/       # Threat modeling reports and artifacts
├── CHANGELOG.md            # Record of notable changes
├── LICENSE.md              # Project license
├── local-devsecops.sh      # Script for local security validation
├── main.tf                 # Root OpenTofu module
├── outputs.tf              # Root module outputs
├── pre-commit-config.yaml  # Pre-commit hook configurations
├── README.md               # This file
└── variables.tf            # Root module variables
```

## Quick Start

### Prerequisites

1.  **Install OpenTofu**: Follow the official instructions at [https://opentofu.org/docs/intro/install/](https://opentofu.org/docs/intro/install/).
2.  **Install Go**: Required for running Terratest. Follow instructions at [https://golang.org/doc/install](https://golang.org/doc/install).
3.  **Install Poetry**: Required for Python dependency management (Checkov, Semgrep). Follow instructions at [https://python-poetry.org/docs/#installation](https://python-poetry.org/docs/#installation).
    ```bash
    # After installing Poetry, install project dependencies
    poetry install
    ```
4.  **Install TFLint**: Required for linting OpenTofu/Terraform code. Follow instructions at [https://github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint).
    ```bash
    # macOS/Linux (using install script):
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

    # Or via Homebrew (macOS):
    brew install tflint

    # Or via Chocolatey (Windows):
    choco install tflint

    # Verify installation:
    tflint --version
    ```
5.  **Configure Cloud Credentials**: For GCP, ensure your credentials are configured as environment variables (e.g., `GOOGLE_APPLICATION_CREDENTIALS`).
6.  **Enable Required GCP APIs**: Before the first deployment to a new GCP project, you **MUST** manually enable the necessary APIs. This is a one-time setup step that cannot be automated in OpenTofu without circular dependencies.

    **Why manual enablement?** API enablement requires project-level permissions that create chicken-egg problems if managed in IaC. Additionally, disabling APIs during `tofu destroy` could accidentally delete resources not managed by this project.

    First, ensure your `.env` file is created and sourced, then run:
    ```bash
    source .env
    gcloud services enable \
      --project="$TF_VAR_project_id" \
      compute.googleapis.com \
      run.googleapis.com \
      cloudresourcemanager.googleapis.com
    ```

    **Required APIs**:
    - `compute.googleapis.com` - Compute Engine (VPCs, Load Balancers, Firewalls, SSL Certificates, Serverless NEG)
    - `run.googleapis.com` - Cloud Run (Serverless container platform for demo backend)
    - `cloudresourcemanager.googleapis.com` - Resource Manager (Project metadata and IAM)

    **Note**: VPC Access Connector API (`vpcaccess.googleapis.com`) is **NOT required** - Serverless NEG provides direct connectivity without VPC Connector.

    **Verification**: Confirm all APIs are enabled before running `tofu init`:
    ```bash
    gcloud services list --enabled --project="$TF_VAR_project_id" | grep -E 'compute|run|cloudresourcemanager'
    ```

    If any APIs are missing, you'll encounter errors during `tofu plan` or `tofu apply`.

7.  **Grant Deployment IAM Roles (Project Owner/Admin Only)**: This is a **one-time bootstrap step** that must be performed by a GCP project owner or admin. If you are a developer without owner/admin access, skip to step 9 and ask your admin to complete steps 7-8.

    **Who should perform this step?**
    - ✅ GCP Project Owner
    - ✅ User with `roles/owner` OR both `roles/resourcemanager.projectIamAdmin` + `roles/iam.serviceAccountAdmin`
    - ❌ Regular developers (you'll get "Permission denied" errors)

    **Why manual IAM role assignment?** OpenTofu cannot grant itself the permissions it needs to run (chicken-and-egg problem). A privileged user must bootstrap the initial permissions. Additionally, managing IAM credentials or service account keys in code would violate security best practices.

    ---

    ### Choose Your Deployment Approach

    **Option A: Local Development with User Account** (Simpler, for testing/development)
    - ✅ Best for: Individual developers, quick testing, local development
    - ✅ Setup: Grant deployment roles directly to your user account
    - ❌ Not recommended for: Production, CI/CD pipelines, shared environments

    **Option B: Service Account** (Recommended for production/CI/CD)
    - ✅ Best for: CI/CD pipelines, automation, production deployments, team environments
    - ✅ Setup: Create dedicated service account with deployment roles
    - ✅ Security: Better auditability, key rotation, and access control

    ---

    ### Required Deployment IAM Roles

    The deployment account (user or service account) needs these roles to provision all infrastructure:

    | Role | Purpose | Resources Managed |
    |------|---------|-------------------|
    | `roles/run.admin` | Cloud Run administration | Create/update/delete Cloud Run services, configure ingress policies, manage IAM bindings |
    | `roles/compute.networkAdmin` | Network resource management | Create VPCs, subnets, firewall rules, load balancers, forwarding rules, backend services, NEGs |
    | `roles/compute.securityAdmin` | Security policy management | Create/manage Cloud Armor (WAF) security policies, SSL certificates |
    | `roles/compute.loadBalancerAdmin` | Load balancer configuration | Configure global external HTTPS load balancers, URL maps, target proxies, health checks |
    | `roles/iam.serviceAccountUser` | Service account impersonation | Allow Cloud Run services to use service accounts for authentication |

    ---

    ### Option A: Grant Roles to Your User Account

    **Prerequisites**: You must already have `roles/owner` or `roles/resourcemanager.projectIamAdmin` to run these commands.

    ```bash
    # Load environment variables from .env file
    source .env

    # Get your current account
    ACCOUNT=$(gcloud config get-value account)

    # Grant all required deployment roles
    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/compute.networkAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/compute.securityAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/compute.loadBalancerAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/iam.serviceAccountUser"
    ```

    **Verification**: Confirm IAM roles are assigned (may take 60-120 seconds to propagate):
    ```bash
    gcloud projects get-iam-policy $TF_VAR_project_id \
      --flatten="bindings[].members" \
      --filter="bindings.members:user:$ACCOUNT" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see all 5 deployment roles listed.

    **Next steps**:
    - ✅ If successful → Proceed to **Step 9** (Configure Application Default Credentials)
    - ❌ If you chose Option A → **Skip Step 8** (Service Account setup not needed)

    ---

    ### Option B: Setup via Service Account

    **Prerequisites**: You must already have `roles/owner` OR both `roles/resourcemanager.projectIamAdmin` + `roles/iam.serviceAccountAdmin`.

    **For full service account setup instructions, see Step 8 below.**

    **Next steps after completing Option B**:
    - ✅ Complete **Step 8** (Create Service Account for Deployment)
    - ✅ Then proceed to **Step 9** (Configure Application Default Credentials)

    ---

    **Troubleshooting**:
    - **Error: "Permission denied"** during role assignment → You need `roles/owner` or `roles/resourcemanager.projectIamAdmin`. Contact your GCP project owner.
    - **Error: "Error 403: Permission 'X' denied"** during deployment → The listed permission is missing; re-run the role assignment commands above
    - **Roles not showing in verification** → IAM changes can take up to 2 minutes to propagate; wait and re-run verification

    **Security Note**: These roles follow the **principle of least privilege** for infrastructure deployment. The `roles/editor` or `roles/owner` roles grant excessive permissions and should NOT be used for deployment accounts.

8.  **Create Service Account for Deployment (CI/CD and Production)**: This section is for **Option B** from Step 7. If you chose **Option A** (user account), skip this step entirely and proceed to Step 9.

    **Who should perform this step?**
    - ✅ GCP Project Owner or Admin (same person who completed Step 7)
    - ❌ Regular developers without `roles/iam.serviceAccountAdmin`

    **Why use a service account?**
    - ✅ **CI/CD pipelines**: GitHub Actions, Jenkins, GitLab CI require non-interactive authentication
    - ✅ **Production deployments**: Better security boundaries and auditability
    - ✅ **Team environments**: Multiple developers can share the same service account credentials
    - ✅ **Key rotation**: Service account keys can be rotated without affecting user accounts

    ---

    ### Create the Service Account

    ```bash
    # Load environment variables
    source .env

    # Define service account name
    SERVICE_ACCOUNT_NAME="opentofu-deployer"
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${TF_VAR_project_id}.iam.gserviceaccount.com"

    # Create the service account
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
      --display-name="OpenTofu Deployment Service Account" \
      --description="Service account for automated OpenTofu infrastructure deployments" \
      --project=$TF_VAR_project_id
    ```

    **Verification**: Confirm service account was created:
    ```bash
    gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id \
      --format="value(email)"
    ```

    **Expected output**: `opentofu-deployer@your-project-id.iam.gserviceaccount.com`

    ---

    ### Grant Deployment Roles to Service Account

    ```bash
    # Grant all required deployment roles
    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/compute.networkAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/compute.securityAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/compute.loadBalancerAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/iam.serviceAccountUser"
    ```

    **Verification**: Confirm IAM roles are assigned (may take 60-120 seconds to propagate):
    ```bash
    gcloud projects get-iam-policy $TF_VAR_project_id \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see all 5 deployment roles listed.

    ---

    ### Create Service Account Key (For Local Development)

    **⚠️ Security Warning**: Service account keys are long-lived credentials. Use Workload Identity Federation for production CI/CD instead of keys when possible.

    ```bash
    # Create and download the key file
    gcloud iam service-accounts keys create ~/${TF_VAR_project_id}-opentofu-deployer-key.json \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id

    # Restrict key file permissions (critical for security)
    chmod 600 ~/${TF_VAR_project_id}-opentofu-deployer-key.json

    # Verify the key file was created
    ls -lh ~/${TF_VAR_project_id}-opentofu-deployer-key.json
    ```

    **Expected output**: A file with `-rw-------` permissions (only owner can read/write)

    ---

    ### Share Service Account Key with Team (If Needed)

    **For individual developers**:
    1. Admin shares the key file via secure channel (1Password, Google Secret Manager, etc.)
    2. Developer saves it to `~/${TF_VAR_project_id}-opentofu-deployer-key.json`
    3. Developer runs `chmod 600 ~/${TF_VAR_project_id}-opentofu-deployer-key.json`

    **For CI/CD pipelines**:
    1. Store the key content as a secret in your CI/CD system:
       - GitHub Actions: Repository Settings → Secrets → Actions → New repository secret
       - GitLab CI: Settings → CI/CD → Variables → Add Variable (Protected, Masked)
       - Jenkins: Manage Jenkins → Credentials → Add Credentials
    2. Secret name: `GCP_SA_KEY` or `GOOGLE_APPLICATION_CREDENTIALS`
    3. Secret value: Paste the entire JSON key file content

    **Security Best Practices**:
    - ✅ **Never commit key files to git**: Already in `.gitignore` as `*.json`
    - ✅ **Rotate keys every 90 days**: See rotation commands below
    - ✅ **Use Workload Identity Federation for CI/CD**: Eliminates need for long-lived keys (recommended for production)
    - ✅ **Audit key usage**: Monitor Cloud Logging for service account activity

    **Key Rotation** (every 90 days):
    ```bash
    # List existing keys
    gcloud iam service-accounts keys list \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id

    # Create new key
    gcloud iam service-accounts keys create ~/${TF_VAR_project_id}-opentofu-deployer-key-new.json \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id

    # Test new key works before deleting old one
    # ... test deployment with new key ...

    # Delete old key (replace KEY_ID with actual ID from list above)
    gcloud iam service-accounts keys delete KEY_ID \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id
    ```

    ---

    **Troubleshooting**:
    - **Error: "Permission denied" when creating service account** → You need `roles/iam.serviceAccountAdmin`. Contact your GCP project owner.
    - **Error: "Permission denied" when creating key** → You need `roles/iam.serviceAccountKeyAdmin` or be the project owner
    - **Error: "Service account does not exist"** → Check project ID in `.env` is correct and matches where you created the service account
    - **Key file not found after creation** → Verify the path `~/${TF_VAR_project_id}-opentofu-deployer-key.json` is correct

    **Next steps**: Proceed to **Step 9** to configure Application Default Credentials using this service account.

9.  **Configure Application Default Credentials (ADC)**: After granting IAM roles in steps 7-8, you **MUST** configure Application Default Credentials so that OpenTofu can authenticate and use your permissions. This is a **critical step** that is often missed.

    **Why is this required?** Google Cloud uses two separate credential systems:

    | Credential Type | Command | Used By | When to Configure |
    |-----------------|---------|---------|-----------------|
    | **User Credentials** | `gcloud auth login` | gcloud CLI commands | When switching Google accounts |
    | **Application Default Credentials (ADC)** | See methods below | OpenTofu, GCP client libraries, SDKs | **After granting IAM roles** |

    ---

    **⚠️ IMPORTANT: Choose the correct method based on what you did in Steps 7-8:**

    | What You Did | Use This Method |
    |------------------------|-----------------|
    | ✅ **Step 7 Option A**: Granted IAM roles to **your user account** | **Method A: User Account ADC** (below) |
    | ✅ **Step 8**: Created and granted IAM roles to a **service account** | **Method B: Service Account ADC** (below) |

    ---

    ### Method A: User Account ADC (For Local Development)

    **Use this method if you completed Step 7 Option A and granted IAM roles to your personal Google account.**

    **Step 1: Refresh ADC credentials**:
    ```bash
    gcloud auth application-default login
    ```

    This command will:
    1. Open your browser automatically
    2. Prompt you to sign in with your Google account (use the same account from step 6)
    3. Ask you to grant permissions to "Google Auth Library"
    4. Save the new credentials to `~/.config/gcloud/application_default_credentials.json`

    **Wait for the terminal to show**: `Credentials saved to file: [/home/user/.config/gcloud/application_default_credentials.json]`

    **Step 2: Verify ADC credentials are working**:
    ```bash
    # Check that a new access token is generated
    gcloud auth application-default print-access-token | cut -c1-50
    ```

    You should see an access token starting with `ya29.` (first 50 characters shown).

    **Common Errors if ADC is Not Refreshed**:
    - `Error: Error creating Network: googleapi: Error 403: Required 'compute.networks.create' permission`
    - `Error: Error creating FirewallRule: googleapi: Error 403: Insufficient Permission`
    - `Error: Error creating Address: googleapi: Error 403: Required 'compute.addresses.create' permission`

    If you see any 403 permission errors during `tofu apply` **even after granting IAM roles**, it means you forgot this step. Simply run `gcloud auth application-default login` and retry.

    **When to Refresh User Account ADC**:
    - ✅ **Required**: After granting new IAM roles to your user account (first-time setup)
    - ✅ **Required**: After switching to a different Google Cloud project
    - ✅ **Required**: If you see 403 permission errors during OpenTofu operations
    - ❌ **Not required**: When running regular `gcloud` commands (those use user credentials)

    ---

    ### Method B: Service Account ADC (For Automation/CI/CD)

    **Use this method if you completed Step 8 and created a service account with deployment IAM roles.**

    **⚠️ Note**: If you already created the service account key in **Step 8** (subsection "Create Service Account Key"), you can skip Step 1 below and proceed directly to Step 2.

    **Step 1: Load Environment and Set Service Account Email** (if not already set):
    ```bash
    # Load environment variables
    source .env

    # Set service account email
    SERVICE_ACCOUNT_NAME="opentofu-deployer"
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${TF_VAR_project_id}.iam.gserviceaccount.com"
    ```

    **Step 2: Configure ADC to Use the Service Account Key**:
    ```bash
    # Set the GOOGLE_APPLICATION_CREDENTIALS environment variable
    # Use the key file path from Step 8 (subsection "Create Service Account Key")
    export GOOGLE_APPLICATION_CREDENTIALS="$HOME/${TF_VAR_project_id}-opentofu-deployer-key.json"

    # Verify it's set
    echo $GOOGLE_APPLICATION_CREDENTIALS
    ```

    **Step 3: Make It Permanent** (add to shell profile):
    ```bash
    # Add to ~/.bashrc or ~/.zshrc (replace with your actual project ID)
    echo 'export GOOGLE_APPLICATION_CREDENTIALS="$HOME/your-project-id-opentofu-deployer-key.json"' >> ~/.bashrc
    source ~/.bashrc
    ```

    **Step 4: (Optional) Activate the service account for gcloud CLI commands**:
    ```bash
    # This allows gcloud commands to also use the service account
    gcloud auth activate-service-account $SERVICE_ACCOUNT_EMAIL \
      --key-file=$GOOGLE_APPLICATION_CREDENTIALS

    # Verify which account is active
    gcloud auth list
    ```

    **Step 5: Verify Service Account Authentication**:
    ```bash
    # Check that ADC is using the service account
    gcloud auth application-default print-access-token | head -c 50
    ```

    You should see an access token starting with `ya29.` (first 50 characters shown).

    **Security Best Practices**:

    Service account key security best practices are covered in **Step 8** (subsection "Share Service Account Key with Team"). Key reminders:
    - ✅ Never commit key files to git (already in `.gitignore`)
    - ✅ Restrict key file permissions: `chmod 600 ~/${TF_VAR_project_id}-opentofu-deployer-key.json`
    - ✅ Rotate keys every 90 days (see Step 8 subsection "Share Service Account Key with Team" for rotation commands)
    - ✅ Use Workload Identity Federation for production CI/CD instead of key files when possible

    **Troubleshooting Method B**:
    - **Error: "Permission denied" when creating key** → You need `roles/iam.serviceAccountKeyAdmin` on the service account or project
    - **Error: "403: Permission denied" during `tofu apply`** → Verify the service account has all required IAM roles (Step 8 subsection "Grant Deployment Roles to Service Account")
    - **Error: "Could not load the default credentials"** → Verify `GOOGLE_APPLICATION_CREDENTIALS` is set and points to a valid key file
    - **Error: "Key file not found"** → Check the path in `GOOGLE_APPLICATION_CREDENTIALS` is correct and file exists

    ---

    **When to Use Each Method**:

    | Scenario | Use Method | Why |
    |----------|------------|-----|
    | **Local development** (your laptop) | Method A (User Account) | Simpler, no key file management |
    | **CI/CD pipelines** (GitHub Actions, Jenkins) | Method B (Service Account) | Required for automation |
    | **Shared development server** | Method B (Service Account) | Avoid sharing personal credentials |
    | **Testing with specific permissions** | Method B (Service Account) | Service account has different IAM roles than your user |

10. **Configure Remote State Backend**: By default, OpenTofu stores state locally in a `terraform.tfstate` file. For production use and team collaboration, you should configure a remote backend to store state in Google Cloud Storage (GCS).

    **Why use remote state?**
    - ✅ **Team collaboration**: Multiple team members can work on the same infrastructure
    - ✅ **State locking**: Prevents concurrent modifications that could corrupt state
    - ✅ **Version history**: GCS bucket versioning provides state file history
    - ✅ **Security**: State files can contain sensitive data and should be stored securely
    - ✅ **Disaster recovery**: State is backed up in cloud storage, not local disk

    **Automated Backend Setup**:

    The `scripts/setup-backend.sh` script automates the entire backend configuration process:

    ```bash
    # Ensure .env is configured first (see step 3 below under Deployment)
    source .env
    ./scripts/setup-backend.sh
    ```

    This script will:
    1. Detect your cloud provider from `TF_VAR_cloud_provider` variable
    2. For GCP: Create a GCS bucket named `${TF_VAR_project_id}-${ENVIRONMENT}-tfstate`
    3. Enable versioning on the bucket for state history
    4. Generate a `backend-config.hcl` file with your bucket configuration
    5. Initialize OpenTofu with the remote backend
    6. Migrate local state to GCS if a local `terraform.tfstate` file exists
    7. Create a backup of your local state file after successful migration

    **Backend Configuration Details** (GCP):
    - **Bucket name pattern**: `<project-id>-<environment>-tfstate`
    - **State path pattern**: `terraform/state/<environment>/default.tfstate`
    - **Versioning**: Enabled (protects against accidental deletion/corruption)
    - **Access**: Uniform bucket-level access (modern IAM-based access control)

    **Manual Backend Setup** (if you prefer):

    If you want to manually configure the backend:

    ```bash
    # 1. Create GCS bucket
    source .env
    BUCKET_NAME="${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"
    gsutil mb -p "${TF_VAR_project_id}" -l "${TF_VAR_region}" "gs://${BUCKET_NAME}"
    gsutil versioning set on "gs://${BUCKET_NAME}"

    # 2. Create backend-config.hcl
    cat > backend-config.hcl <<EOF
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state/${TF_VAR_environment}"
    EOF

    # 3. Initialize with backend
    tofu init -backend-config=backend-config.hcl -migrate-state
    ```

    **Verification**: After backend setup, verify state is stored remotely:
    ```bash
    # Check bucket exists
    gsutil ls -b "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"

    # List state files
    gsutil ls "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate/terraform/state/"
    ```

    **When to Skip Backend Setup**:
    - ❌ **Skip for**: Quick local testing or experiments
    - ❌ **Skip for**: Single-user development without state sharing needs
    - ✅ **Required for**: Production deployments
    - ✅ **Required for**: Team collaboration
    - ✅ **Required for**: CI/CD pipelines

    **Troubleshooting**:
    - **Error: "Backend initialization required"** → Run `./scripts/setup-backend.sh`
    - **Error: "bucket does not exist"** → The script will create it automatically
    - **Error: "Permission denied" when creating bucket** → Verify you have `roles/storage.admin` or `roles/owner`

11. **Grant Service Account Access to State Bucket** (Required if using service account from Step 8):

    If you created a service account in **Step 8** for OpenTofu deployments, you **MUST** grant it permissions to read and write to the Terraform state bucket. The `setup-backend.sh` script only grants permissions to your current user account by default.

    **Why is this required?** The service account needs to:
    - Read the current state file before making changes
    - Write updated state files after applying infrastructure changes
    - Create and manage state lock files to prevent concurrent modifications

    **Grant state bucket permissions**:
    ```bash
    # Ensure .env is loaded
    source .env

    # Grant storage.objectAdmin role (read/write access to state files)
    gcloud storage buckets add-iam-policy-binding "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate" \
      --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
      --role="roles/storage.objectAdmin"
    ```

    **Verification**: Confirm the service account has the correct permissions:
    ```bash
    # View all IAM policies on the bucket
    gcloud storage buckets get-iam-policy "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"

    # Or filter for just the service account
    gcloud storage buckets get-iam-policy "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate" \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see the service account listed with `roles/storage.objectAdmin` role.

    **Alternative using gsutil** (if you prefer the legacy command):
    ```bash
    # Ensure .env is loaded and set bucket name
    source .env

    # Grant permissions using gsutil
    gsutil iam ch "serviceAccount:${SERVICE_ACCOUNT_EMAIL}:roles/storage.objectAdmin" \
      "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"

    # Verify permissions
    gsutil iam get "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate" | grep -A 2 "${SERVICE_ACCOUNT_EMAIL}"
    ```

    **Troubleshooting**:
    - **Error: "CommandException: 'iam' command does not support provider-only URLs"** → The bucket name variable is not set. Ensure you've run `source .env` first
    - **Error: "Permission denied" when granting IAM** → You need `roles/storage.admin` or `roles/owner` to modify bucket IAM policies
    - **Error: "ServiceAccount not found"** → Verify the service account was created in **Step 8** using `gcloud iam service-accounts list`
    - **Error: "403 Permission denied" during `tofu apply` with service account** → The service account lacks state bucket permissions; re-run the command above
    - **Error: "BucketNotFoundException"** → The state bucket doesn't exist yet. Run `./scripts/setup-backend.sh` first

    **Security Note**: The `roles/storage.objectAdmin` role is the recommended permission level for OpenTofu state management. It follows the principle of least privilege while providing all necessary permissions for state file operations (create, read, update, delete objects).

## Deployment

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd vibetics-cloudedge
    ```

2.  **Set Environment Variables**: Create a `.env` file in the root of the project from the example template.

    ```bash
    cp .env.example .env
    ```

    Edit `.env` and configure your GCP project settings:
    ```bash
    TF_VAR_cloud_provider="gcp"
    TF_VAR_project_id="your-gcp-project-id"
    TF_VAR_region="northamerica-northeast2"
    TF_VAR_environment="nonprod"
    TF_VAR_billing_account="your-billing-account-id"
    ```

    **IMPORTANT**: The `.env` file is already in `.gitignore` to prevent committing secrets.

3.  **Configure Remote State Backend** (RECOMMENDED):
    ```bash
    source .env
    ./scripts/setup-backend.sh
    ```

    This will:
    - Create a GCS bucket for state storage with versioning enabled
    - Generate backend configuration
    - Initialize OpenTofu with remote backend
    - Migrate any existing local state to GCS

    **Skip this step** for quick local testing. For production and team collaboration, remote state is required.

4.  **Deploy the infrastructure**:
    ```bash
    source .env
    ./scripts/deploy.sh
    ```

    **Note**: If you ran `setup-backend.sh` in step 3, OpenTofu is already initialized. Otherwise, `deploy.sh` will run `tofu init` automatically.

## Teardown

To destroy all infrastructure managed by this deployment, run the following command:
```bash
./scripts/teardown.sh
```

## Testing Strategy

This project employs a two-tiered, Test-Driven Development (TDD) approach as mandated by the [constitution](.specify/memory/constitution.md).

### Tier 1: Unit Tests (Local, Pre-Commit)

Unit tests are designed to validate the logic of individual OpenTofu modules in isolation, without deploying real resources.

-   **Framework**: OpenTofu Native Testing (`tofu test`)
-   **Location**: `*.tftest.hcl` files within each module's directory
-   **Status**: ⚠️ **Not yet implemented** - Native unit tests are planned for future iterations

**Note**: Currently, this project uses **Tier 2 integration tests only** (see below). The `tofu test` command will return `0 passed, 0 failed` because no `.tftest.hcl` files exist yet. For testing infrastructure, use the Terratest integration tests described in Tier 2.

### Tier 2: Integration & BDD Tests (Post-Deployment)

This tier validates the behavior of the fully deployed infrastructure. It is driven by Behavior-Driven Development (BDD) principles.

-   **Framework**: Terratest (Go) with Cucumber for BDD.
-   **Specifications**: Human-readable Gherkin scenarios are defined in `.feature` files within the `features/` directory.
-   **Implementation**: The Go test files in `tests/integration/` and `tests/contract/` implement the steps defined in the Gherkin scenarios.

**How to Run All Integration Tests:**
This command deploys the infrastructure, runs all integration tests against it, and then tears it down.
```bash
cd tests/integration/gcp
go test -v -timeout 30m
```

**How to Run Specific Tests:**
You can run individual test suites for faster feedback:

```bash
cd tests/integration/gcp

# Full baseline test (all 7 components + connectivity)
go test -v -run TestFullBaseline -timeout 30m

# CIS compliance test
go test -v -run TestCISCompliance -timeout 20m

# Mandatory tagging test
go test -v -run TestMandatoryResourceTagging -timeout 20m

# Teardown validation test
go test -v -run TestTeardown -timeout 20m
```

**How to Run Contract Tests:**
Contract tests validate IaC compliance using Checkov:
```bash
# Ensure Poetry dependencies are installed first
poetry install

# Run contract tests
cd tests/contract
poetry run go test -v -timeout 10m
```

**Troubleshooting: "0 passed, 0 failed"**

If you see this message, you likely ran `tofu test` instead of the Go integration tests. This project uses **Terratest (Go)**, not OpenTofu native tests. Use the commands above to run tests.

### Testing in the CI/CD Pipeline

-   **Continuous Integration (CI)**: On every Pull Request, the CI pipeline runs static analysis (Checkov, Semgrep) and OpenTofu validation. Unit tests (`.tftest.hcl` files) are planned for future implementation.
-   **Continuous Deployment (CD)**: After a successful deployment to the `nonprod` environment, the CD pipeline will execute the **Tier 2 Integration and Smoke Tests** against the live infrastructure to ensure it is behaving as expected. This is also where post-deployment DAST scans will be run.

## Security Documentation

### Threat Modeling

This project requires threat modeling as part of the security development lifecycle, as mandated by the [constitution](.specify/memory/constitution.md) (§7). Threat models help identify security risks, attack vectors, and mitigation strategies before deployment.

#### Threat Modeling Directory Structure

```
threat_modelling/
├── reports/              # Automated threat detection reports
│   ├── pr-threats.json   # JSON report from CI pipeline (SAST/threat detection)
│   └── pr-threats.md     # Markdown summary of detected threats
└── manual/               # Manual threat modeling artifacts (if applicable)
    ├── STRIDE-analysis.md
    ├── attack-trees.md
    └── data-flow-diagrams/
```

#### Automated Threat Detection (CI Pipeline)

The CI pipeline automatically runs SAST and threat modeling analysis on every Pull Request to `main`. Results are stored in `threat_modelling/reports/`.

**What's analyzed**:
- Code patterns indicating security vulnerabilities
- Infrastructure misconfigurations with security implications
- Attack surface analysis based on infrastructure design
- Compliance with security best practices (CIS benchmarks)

**CI Job**: `ci-sast-threatmodel` (defined in `.github/workflows/ci.yml`)

**Outputs**:
- `threat_modelling/reports/pr-threats.json` - Machine-readable findings
- `threat_modelling/reports/pr-threats.md` - Human-readable summary
- Automated GitHub issues created for CRITICAL/HIGH severity findings

**Viewing automated threat reports**:

1. **After CI completes on your PR**:
   ```bash
   # View Markdown summary
   cat threat_modelling/reports/pr-threats.md

   # View JSON report (for tooling integration)
   cat threat_modelling/reports/pr-threats.json | jq
   ```

2. **Check GitHub Issues**:
   - Issues are auto-created with labels: `security`, `threat-model`, `severity:critical`, `severity:high`
   - Navigate to: Repository → Issues → Filter by `label:threat-model`

**Severity Levels** (from constitution §7):

| Severity | Blocks Deployment | Action Required |
|----------|------------------|-----------------|
| **CRITICAL** | ✅ Yes | Must fix or provide approved waiver |
| **HIGH** | ✅ Yes | Must fix or provide approved time-boxed waiver |
| **MEDIUM** | ❌ No | Must acknowledge and plan remediation |
| **LOW** | ❌ No | Optional, recommended to address |

**Waiver Process** (for CRITICAL/HIGH findings):
1. Document the risk assessment in the PR description
2. Provide mitigation plan or compensating controls
3. Get approval from security lead or tech lead
4. Attach waiver with time-box (e.g., "Accept risk until [date], remediate in [ticket]")

#### Manual Threat Modeling (STRIDE Methodology)

For major features or architectural changes, manual threat modeling should be conducted using the STRIDE framework.

**When to perform manual threat modeling**:
- ✅ New infrastructure architecture (e.g., adding DR, multi-region)
- ✅ New security boundaries (e.g., VPC peering, service mesh)
- ✅ External integrations (e.g., API Gateway, third-party services)
- ✅ Data classification changes (e.g., handling PII, financial data)
- ❌ Minor configuration changes to existing resources

**STRIDE Framework**:

| Threat Category | Description | Example Threats |
|----------------|-------------|-----------------|
| **S**poofing | Impersonating something or someone | Service account key theft, IP spoofing |
| **T**ampering | Modifying data or code | Man-in-the-middle attacks, unauthorized config changes |
| **R**epudiation | Claiming to have not performed an action | Missing audit logs, non-traceable actions |
| **I**nformation Disclosure | Exposing information to unauthorized parties | Public S3 buckets, exposed secrets, verbose errors |
| **D**enial of Service | Deny or degrade service availability | DDoS attacks, resource exhaustion |
| **E**levation of Privilege | Gain capabilities without authorization | IAM misconfigurations, container escapes |

**How to create a manual threat model**:

1. **Create a data flow diagram** (DFD):
   ```bash
   # Create directory for your feature
   mkdir -p threat_modelling/manual/feature-name/

   # Document data flows (use draw.io, Mermaid, or ASCII diagrams)
   # Save as: threat_modelling/manual/feature-name/data-flow-diagram.png
   ```

2. **Identify trust boundaries**:
   - External users → Load Balancer
   - Load Balancer → VPC (ingress)
   - VPC → Cloud Run backend
   - Cloud Run → External APIs

3. **Apply STRIDE to each component and boundary**:
   ```bash
   # Create STRIDE analysis document
   cat > threat_modelling/manual/feature-name/STRIDE-analysis.md <<EOF
   # STRIDE Analysis: [Feature Name]

   ## Component: [e.g., Cloud Run Backend]

   ### Spoofing
   - **Threat**: Attacker impersonates legitimate service account
   - **Mitigation**: Use Workload Identity, rotate service account keys every 90 days
   - **Residual Risk**: LOW (compensating controls in place)

   ### Tampering
   - **Threat**: Man-in-the-middle attack on API traffic
   - **Mitigation**: TLS 1.2+ enforced, Cloud Armor blocks non-HTTPS
   - **Residual Risk**: LOW

   [Continue for T, R, I, D, E...]

   ## Trust Boundary: Internet → Cloud Armor WAF

   ### Spoofing
   - **Threat**: DDoS attack from spoofed IP addresses
   - **Mitigation**: Cloud Armor adaptive protection, rate limiting
   - **Residual Risk**: MEDIUM (sophisticated DDoS requires additional mitigation)

   [Continue for all boundaries...]
   EOF
   ```

4. **Document attack trees** (optional, for complex features):
   ```bash
   # Create attack tree diagram
   cat > threat_modelling/manual/feature-name/attack-trees.md <<EOF
   # Attack Trees: [Feature Name]

   ## Attack Goal: Gain unauthorized access to Cloud Run backend

   ```
   [Root] Unauthorized Access to Backend
   ├── [AND] Bypass WAF
   │   ├── Exploit WAF rule gap
   │   └── Use legitimate user agent
   ├── [OR] Compromise Load Balancer
   │   ├── Exploit LB vulnerability (CVSS 7.5+)
   │   └── Steal LB admin credentials
   └── [OR] Direct access to Cloud Run
       ├── Find exposed Cloud Run URL (BLOCKED by ingress policy)
       └── Compromise VPC network (LOW likelihood)
   ```
   EOF
   ```

5. **Review and validate**:
   - Peer review threat model with team
   - Validate mitigations are implemented
   - Update threat model when architecture changes

**Tools for threat modeling** (optional):

- **Microsoft Threat Modeling Tool**: GUI-based STRIDE analysis
  - Download: https://aka.ms/threatmodelingtool

- **OWASP Threat Dragon**: Open-source threat modeling tool
  - Install: `npm install -g owasp-threat-dragon`

- **draw.io / Mermaid**: For data flow diagrams
  - Online: https://app.diagrams.net/
  - Mermaid in Markdown (supported in GitHub)

**Example Mermaid diagram** (paste in Markdown):
```mermaid
graph LR
    A[External User] -->|HTTPS| B[Cloud Armor WAF]
    B -->|Filtered Traffic| C[HTTPS Load Balancer]
    C -->|Internal| D[Serverless NEG]
    D -->|Private Network| E[Cloud Run Backend]
    E -->|API Call| F[External Service]

    style B fill:#f96,stroke:#333,stroke-width:2px
    style C fill:#96f,stroke:#333,stroke-width:2px
    style E fill:#9f6,stroke:#333,stroke-width:2px
```

#### Current Architecture Security Controls

For the baseline infrastructure (Feature 001), see the **Key Security Controls** section in the [Architecture Overview](#current-architecture-single-region-mvp-with-demo-backend) above.

**Threat Model Status**:
- ✅ Automated threat detection via CI pipeline
- ✅ Defense-in-depth architecture (WAF, Firewall, Ingress Policy)
- ⚠️ Manual STRIDE analysis: Recommended for Feature 002 (multi-backend) and Feature 003 (DR)

#### Accessing Historical Threat Reports

Threat reports from past PRs are stored in the repository history:

```bash
# View threat reports from specific commit
git show <commit-sha>:threat_modelling/reports/pr-threats.md

# Search commit history for threat reports
git log --all --full-history -- threat_modelling/reports/

# View all security issues ever created
# Navigate to: GitHub → Issues → Filter: is:issue label:threat-model is:closed
```

**Note**: The `threat_modelling/reports/` directory is currently empty as the CI pipeline implementation is pending. Once CI is configured, reports will be automatically generated on every PR.

## Branching Strategy & Git Workflow

This project follows a strict Git promotion model as defined in the [constitution](.specify/memory/constitution.md) (§1). All changes flow through a controlled promotion pipeline across protected branches.

### Branch Structure

The repository maintains three protected branches representing different stages of the deployment pipeline:

| Branch | Purpose | Deployment Target | Protection |
|--------|---------|------------------|------------|
| **`main`** | Integration branch for approved features | Not deployed (aggregation only) | PR-only, no direct pushes |
| **`nonprod`** | Non-production testing and validation | `nonprod` environment (infrastructure team only) | PR-only, requires main merge + CI pass |
| **`prod`** | Production-ready releases | `prod` environment (application teams + production) | PR-only, requires nonprod validation + approval |

**Important Notes**:
- **No direct pushes** to protected branches (main, nonprod, prod)
- All work happens on **issue branches** created from GitHub issues
- The `nonprod` environment is reserved for **infrastructure team testing only** - application teams cannot use this environment
- The `prod` environment hosts **all application team environments** (dev, test, staging, production)

### Git Workflow & Promotion Flow

The standard workflow for deploying infrastructure changes follows this sequence:

```
┌─────────────┐
│  Developer  │
│Local Machine│
└──────┬──────┘
       │ 1. Create issue branch from GitHub issue
       │ 2. Make changes and test locally
       │ 3. git push origin <issue-branch>
       │
       ▼
┌─────────────────────┐
│   Issue Branch      │
│ (e.g., 123-feature) │
└──────┬──────────────┘
       │ 4. Open PR to main
       │ 5. CI runs (SCA, SAST, Secrets Scan, Lint, IaC Compliance)
       │ 6. Code review + approval
       │ 7. Merge to main
       │ 8. Auto-tag: build-YYYYMMDDHHmm
       ▼
┌─────────────┐
│    main     │
│ (build tag) │
└──────┬──────┘
       │ 9. Open PR: main → nonprod
       │10. CD deploys to nonprod environment
       │11. Post-deploy tests: Integration, Smoke, DAST
       │12. Merge to nonprod
       │13. Auto-tag: nonprod-YYYYMMDDHHmm
       ▼
┌──────────────┐
│   nonprod    │
│(nonprod tag) │
└──────┬───────┘
       │14. Request approval for production
       │15. Open PR: nonprod → prod
       │16. Blue/Green tag management:
       │    - Tag current prod commit as "blue" (backup)
       │    - Tag nonprod commit as "green" (candidate)
       │17. CD deploys "green" tag to prod environment
       │18. Post-deploy tests: Smoke, DAST
       │19. If tests pass: Tag as prod-YYYYMMDDHHmm
       │20. If tests fail: Rollback to "blue" tag
       ▼
┌─────────────┐
│    prod     │
│ (prod tag)  │
└─────────────┘
```

### Tag Naming Conventions

Tags are automatically created at each promotion stage to enable traceability and rollback:

| Tag Format | When Created | Purpose | Example |
|------------|-------------|---------|---------|
| `build-YYYYMMDDHHmm` | After merge to `main` | Identifies build that passed CI | `build-202501171430` |
| `nonprod-YYYYMMDDHHmm` | After successful nonprod deployment + tests | Marks validated nonprod release | `nonprod-202501171445` |
| `blue` | Before prod deployment | Backup of current production (for rollback) | `blue` (moves to previous prod commit) |
| `green` | Before prod deployment | Production candidate being deployed | `green` (points to nonprod-YYYYMMDDHHmm) |
| `prod-YYYYMMDDHHmm` | After successful prod deployment + tests | Confirmed production release | `prod-202501171500` |

### Branch Protection Rules

All protected branches enforce these requirements:

**`main` branch**:
- ✅ Require pull request reviews (minimum 1 approval)
- ✅ Require status checks to pass (CI pipeline)
- ✅ Require conversation resolution before merge
- ✅ No force pushes
- ✅ No deletions

**`nonprod` branch**:
- ✅ All `main` branch rules +
- ✅ Require successful deployment to nonprod environment
- ✅ Require integration tests to pass
- ✅ Require smoke tests to pass
- ✅ Require DAST scan to pass

**`prod` branch**:
- ✅ All `nonprod` branch rules +
- ✅ Require explicit approval from maintainer/release manager
- ✅ Require successful blue/green tag validation
- ✅ Manual approval gate before deployment

### Rollback Procedures

If production deployment fails (step 20 in workflow above):

1. **Automated rollback triggers**:
   ```bash
   # CI detects test failures in prod deployment
   # Automatically executed:
   git tag -f green blue         # Point green tag back to blue (previous prod)
   # CD pipeline redeploys green tag (now same as blue)
   ```

2. **Manual rollback** (if needed):
   ```bash
   # Find the last known good production commit
   git log --oneline --decorate | grep prod-

   # Tag it as green
   git tag -f green <last-good-commit-sha>
   git push origin green --force

   # CD pipeline will redeploy
   ```

3. **Notification**:
   - Infrastructure team is alerted via GitHub issue
   - Rollback event is logged in CHANGELOG.md
   - Postmortem required for prod rollback incidents

### Issue Branch Naming

Branch names must follow GitHub issue number format:

| Pattern | Example | Use Case |
|---------|---------|----------|
| `<issue#>-<short-description>` | `123-add-waf-rules` | Feature or bug fix |
| `<issue#>-hotfix-<description>` | `124-hotfix-firewall-rule` | Production hotfix |

**Creating an issue branch**:
```bash
# From GitHub Issues page:
# 1. Create new issue
# 2. Use "Create a branch" button in issue sidebar
# 3. Or manually:
git checkout main
git pull origin main
git checkout -b 123-add-waf-rules
```

### Example: Complete Feature Workflow

```bash
# 1. Create issue branch (from GitHub issue #145)
git checkout main
git pull origin main
git checkout -b 145-add-cdn-module

# 2. Make changes locally
# ... edit files ...
tofu fmt -recursive .
tofu validate
poetry run pre-commit run --all-files

# 3. Commit and push to issue branch
git add .
git commit -m "feat: add CDN module for static content caching"
git push origin 145-add-cdn-module

# 4. Create PR: 145-add-cdn-module → main
# (via GitHub UI)

# 5. CI runs automatically (ci-sca, ci-format-lint, ci-secrets-scan, ci-sast-threatmodel, ci-iac-compliance)

# 6. After approval and merge to main:
# Auto-tagged as: build-202501171430

# 7. Create PR: main → nonprod
# (via GitHub UI)

# 8. CD deploys to nonprod environment and runs:
#    - cd-integration-tests
#    - cd-smoke-tests
#    - cd-dast
# Auto-tagged as: nonprod-202501171445

# 9. Request production approval and create PR: nonprod → prod

# 10. After approval:
# CD performs blue/green deployment:
#    - Tags current prod as "blue"
#    - Tags nonprod-202501171445 as "green"
#    - Deploys "green"
#    - Runs cd-smoke-tests and cd-dast
# If successful, tagged as: prod-202501171500
```

## Development Workflow

This project follows a strict Spec-Driven Development (SDD) workflow as defined in the [constitution](.specify/memory/constitution.md). All infrastructure changes must be implemented through the following process:

### Code Formatting and Linting (Local Development)

Before committing code, format and lint your code to ensure consistency and catch common errors. This project uses different tools for different file types.

#### Prerequisites

Ensure Poetry dependencies are installed:
```bash
poetry install
```

#### OpenTofu/Terraform Files (*.tf)

**1. Format OpenTofu code** (auto-fix):
```bash
# Format all .tf files in the current directory and subdirectories
tofu fmt -recursive .
```

**What it does**:
- Rewrites OpenTofu configuration files to a canonical format
- Adjusts indentation, spacing, and alignment
- Sorts blocks and arguments

**When to run**: Before every commit that modifies `.tf` files

**2. Validate OpenTofu syntax**:
```bash
# Initialize OpenTofu (required before validation)
tofu init

# Validate configuration files
tofu validate
```

**What it checks**:
- Syntax errors
- Invalid attribute names
- Missing required arguments
- Type errors

**When to run**: After making changes to module structure or variable definitions

**3. Lint OpenTofu code (optional - requires tflint)**:
```bash
# Install tflint (one-time setup)
# macOS/Linux:
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Or via Homebrew:
brew install tflint

# Run tflint
tflint --recursive
```

**What it checks**:
- Provider-specific best practices
- Deprecated syntax
- Unused variables and outputs
- Naming conventions

**When to run**: Before creating a PR for infrastructure changes

#### Python Files (*.py) - Test Scripts

**1. Format Python code with Black** (auto-fix):
```bash
# Format specific file
poetry run black path/to/file.py

# Format all Python files in tests directory
poetry run black tests/

# Format entire project
poetry run black .
```

**Configuration**: See `[tool.black]` in `pyproject.toml`
- Line length: 100 characters
- Target: Python 3.12

**2. Sort imports with isort** (auto-fix):
```bash
# Sort imports in specific file
poetry run isort path/to/file.py

# Sort all Python imports in tests directory
poetry run isort tests/

# Sort entire project
poetry run isort .
```

**Configuration**: See `[tool.isort]` in `pyproject.toml`
- Profile: black (compatible with Black formatter)
- Line length: 100 characters

**3. Run both formatters together** (recommended):
```bash
# Format and sort imports for all Python files
poetry run black . && poetry run isort .
```

**4. Lint Python code (if using ruff or flake8)**:

**Note**: These tools are not currently in `pyproject.toml` dependencies but can be added:

```bash
# Add ruff to dev dependencies (recommended - faster than flake8)
poetry add --group dev ruff

# Run ruff linter
poetry run ruff check .

# Run ruff with auto-fix
poetry run ruff check --fix .
```

**Alternative with flake8**:
```bash
# Add flake8 to dev dependencies
poetry add --group dev flake8

# Run flake8
poetry run flake8 tests/
```

#### Go Files (*.go) - Test Files

**1. Format Go code**:
```bash
# Format all Go files in tests directory
go fmt ./tests/...

# Format specific file
go fmt path/to/file.go
```

**2. Lint Go code**:
```bash
# Install golangci-lint (one-time setup)
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run linter on tests
golangci-lint run ./tests/...
```

#### Markdown Files (*.md)

**1. Lint Markdown** (optional):
```bash
# Install markdownlint-cli (one-time setup)
npm install -g markdownlint-cli

# Lint all markdown files
markdownlint '**/*.md' --ignore node_modules
```

**2. Check links** (optional):
```bash
# Install markdown-link-check (one-time setup)
npm install -g markdown-link-check

# Check for broken links
markdown-link-check README.md
```

#### YAML Files (*.yaml, *.yml)

**1. Lint YAML files**:
```bash
# Install yamllint via Poetry (add to pyproject.toml)
poetry add --group dev yamllint

# Lint all YAML files
poetry run yamllint .
```

#### Quick Commands Cheatsheet

**Before every commit**:
```bash
# Format OpenTofu files
tofu fmt -recursive .

# Format Python files (if you modified test scripts)
poetry run black tests/ && poetry run isort tests/

# Format Go files (if you modified test files)
go fmt ./tests/...
```

**Before creating a PR**:
```bash
# Full formatting and validation
tofu fmt -recursive . && \
tofu validate && \
poetry run black . && \
poetry run isort . && \
go fmt ./tests/...
```

**Automated via pre-commit hooks** (see Pre-commit Hooks section below):
- Running `git commit` will automatically format code if pre-commit hooks are installed
- Pre-commit hooks run formatters and linters on staged files only

#### Common Formatting Issues

**OpenTofu/Terraform**:
- `Inconsistent indentation` → Run `tofu fmt -recursive .`
- `Blocks not sorted` → Run `tofu fmt` (automatically sorts)
- `Trailing whitespace` → Run `tofu fmt` (automatically removes)

**Python**:
- `Line too long` → Black wraps automatically to 100 characters
- `Imports not sorted` → Run `isort`
- `Missing docstrings` → Add docstrings (linters will detect)

**Go**:
- `Imports not grouped` → `go fmt` handles automatically
- `Unused variables` → Linter will catch, remove them

#### Tools Summary

| File Type | Formatter | Linter | Auto-fix |
|-----------|-----------|--------|----------|
| **OpenTofu (.tf)** | `tofu fmt` | `tofu validate`, `tflint` | ✅ Yes |
| **Python (.py)** | `black`, `isort` | `ruff`, `flake8` (optional) | ✅ Yes |
| **Go (.go)** | `go fmt` | `golangci-lint` | ✅ Yes |
| **Markdown (.md)** | N/A | `markdownlint` (optional) | Partial |
| **YAML (.yml)** | N/A | `yamllint` (optional) | ❌ No |

### Security Scanning (Local Development)

Before committing code, you should run security scans locally to catch issues early. This project uses multiple security tools as defined in the [constitution](.specify/memory/constitution.md).

#### Prerequisites

Ensure Poetry dependencies are installed:
```bash
poetry install
```

#### Run All Security Scans

**Option 1: Run all scans individually**

1. **SAST (Static Application Security Testing) - Semgrep**:
   ```bash
   # Scan for security vulnerabilities in code
   poetry run semgrep scan --config=auto --severity=ERROR --severity=WARNING .
   ```

   **What it checks**: Code patterns, security anti-patterns, common vulnerabilities (OWASP Top 10)

   **Expected output**: `No findings` or a list of security issues with severity levels

2. **SCA (Software Composition Analysis) - Checkov**:
   ```bash
   # Scan OpenTofu/Terraform IaC for misconfigurations
   poetry run checkov --directory . --framework terraform --compact --quiet
   ```

   **What it checks**: CIS benchmarks, cloud security best practices, compliance violations

   **Expected output**: Summary of passed/failed checks with recommendations

3. **Secrets Detection - Gitleaks**:
   ```bash
   # Install gitleaks (one-time setup)
   go install github.com/gitleaks/gitleaks/v8@latest

   # Scan for exposed secrets
   gitleaks detect --source . --verbose
   ```

   **What it checks**: API keys, passwords, tokens, private keys accidentally committed

   **Expected output**: `No leaks found` or list of detected secrets

**Option 2: Run quick security check (recommended before commits)**

```bash
# Run SAST + SCA together (fastest combination)
poetry run semgrep scan --config=auto --severity=ERROR . && \
poetry run checkov --directory . --framework terraform --compact --quiet
```

**Option 3: Run comprehensive security validation**

If a `local-devsecops.sh` script exists in your project:
```bash
./local-devsecops.sh
```

**Note**: This script is mentioned in the project skeleton but not yet implemented. You can create it with:
```bash
cat > local-devsecops.sh <<'EOF'
#!/bin/bash
set -e

echo "Running local DevSecOps validation..."

echo "[1/3] Running Semgrep (SAST)..."
poetry run semgrep scan --config=auto --severity=ERROR --severity=WARNING .

echo "[2/3] Running Checkov (SCA)..."
poetry run checkov --directory . --framework terraform --compact --quiet

echo "[3/3] Running Gitleaks (Secrets)..."
gitleaks detect --source . --verbose

echo "✅ All security scans passed!"
EOF

chmod +x local-devsecops.sh
```

#### Blocking vs Non-Blocking

The project constitution (§7) defines blocking thresholds:

| Tool | Blocks on | Allows |
|------|-----------|--------|
| **Semgrep (SAST)** | CRITICAL severity | ERROR, WARNING (must be fixed before merge) |
| **Checkov (SCA)** | CRITICAL severity | HIGH, MEDIUM, LOW (must be addressed) |
| **Gitleaks (Secrets)** | Any secret detected | N/A (no secrets allowed) |

#### Common Issues and Fixes

**Semgrep Errors**:
- `Hardcoded credentials` → Move to environment variables or secret management
- `SQL injection risk` → Use parameterized queries
- `Insecure random` → Use cryptographically secure random generators

**Checkov Errors**:
- `CKV_GCP_X: Resource without labels` → Add required resource tags (see constitution §4)
- `CKV_GCP_X: Encryption not enabled` → Enable encryption at rest
- `CKV_GCP_X: Logging not enabled` → Add audit logging configuration

**Gitleaks Errors**:
- If secrets are detected → Remove from code, add to `.gitignore`, use environment variables
- If false positive → Add to `.gitleaksignore` file with justification

#### When to Run Security Scans

- ✅ **Before every commit**: Run Option 2 (quick check)
- ✅ **Before creating PR**: Run Option 1 (all scans individually) to see detailed reports
- ✅ **After fixing vulnerabilities**: Re-run specific tool to verify fix
- ❌ **Not required**: For documentation-only changes (e.g., README updates)

### Pre-commit Hooks

Before committing any changes, it is mandatory to run the pre-commit hooks to ensure code quality, formatting, and documentation are up to date.

1.  **Install pre-commit** (via Poetry):
    ```bash
    poetry install
    ```

2.  **Install the hooks**:
    ```bash
    poetry run pre-commit install
    ```

3.  **Run the hooks**: The hooks will run automatically on `git commit`. You can also run them manually at any time:
    ```bash
    poetry run pre-commit run --all-files
    ```

### Continuous Integration (CI)

The CI pipeline is defined in `.github/workflows/ci.yml` and runs automatically on **every Pull Request to the `main` branch**. All CI jobs must pass before a PR can be merged.

**Pipeline Trigger**: PR opened/updated against `main` branch

**CI Jobs and Gates** (as defined in constitution §7):

| Job Name | Tool/Framework | What It Does | Blocking Threshold | Duration |
|----------|----------------|--------------|-------------------|----------|
| **`ci-format-lint`** | `tofu fmt`, `tflint` | Validates OpenTofu code formatting and syntax | Any formatting error | ~2 min |
| **`ci-secrets-scan`** | `gitleaks` | Scans for exposed secrets (API keys, tokens, credentials) | Any secret detected | ~1 min |
| **`ci-sca`** | `checkov` | Software Composition Analysis - scans dependencies for known vulnerabilities | CRITICAL findings block; HIGH requires waiver | ~3 min |
| **`ci-sast-threatmodel`** | `semgrep` | Static Application Security Testing - detects security vulnerabilities in code patterns | Generates threat report; creates GitHub issues for HIGH/CRITICAL | ~4 min |
| **`ci-iac-compliance`** | `checkov` | Infrastructure-as-Code compliance checks against CIS benchmarks and cloud security best practices | CRITICAL/HIGH findings block PR | ~5 min |
| **`build-and-scan-image`** | `docker build`, `trivy` | Builds Docker images (if applicable) and scans for container vulnerabilities | CRITICAL/HIGH findings block unless waived | ~6 min |

**CI Workflow Steps**:

1. **Code Checkout**: Fetch PR branch code
2. **Dependency Installation**: Install Poetry, Go, OpenTofu, security tools
3. **Parallel Job Execution**:
   ```
   ┌─────────────────┐
   │  ci-format-lint │  (tofu fmt, tflint)
   └─────────────────┘
   ┌──────────────────┐
   │ ci-secrets-scan  │  (gitleaks)
   └──────────────────┘
   ┌─────────────────┐
   │    ci-sca       │  (checkov - dependencies)
   └─────────────────┘
   ┌─────────────────────┐
   │ ci-sast-threatmodel │  (semgrep + threat modeling)
   └─────────────────────┘
   ┌──────────────────────┐
   │ ci-iac-compliance    │  (checkov - IaC compliance)
   └──────────────────────┘
   ┌──────────────────────┐
   │ build-and-scan-image │  (docker + trivy, if applicable)
   └──────────────────────┘
   ```
4. **Artifact Generation**:
   - Threat modeling reports: `threat_modelling/reports/pr-threats.json`, `pr-threats.md`
   - SCA/SAST reports uploaded as GitHub Actions artifacts
   - Auto-create GitHub issues for HIGH/CRITICAL security findings
5. **Status Check**: All jobs must pass for PR to be mergeable

**Definition of Done for CI** (constitution §DoD):
- ✅ All formatting/linting checks pass
- ✅ No secrets detected in codebase
- ✅ No CRITICAL SCA findings (or approved waiver attached)
- ✅ SAST/threat modeling reports generated
- ✅ No CRITICAL/HIGH IaC compliance violations (or approved waiver)
- ✅ Container scans pass (if applicable)
- ✅ All required reviewers approved
- ✅ Build tagged as `build-YYYYMMDDHHmm` upon merge to main

**Waiver Process** (for CRITICAL/HIGH findings):

If a CRITICAL or HIGH severity finding cannot be immediately remediated, a time-bound waiver can be requested:

1. Create GitHub issue with:
   - Finding details (CVE ID, severity, affected component)
   - Risk assessment and business justification
   - Compensating controls or mitigation plan
   - Expiry date (max 30 days)
2. Add `security-waiver` label to PR
3. Link waiver issue in PR description
4. Obtain approval from **Security Lead + Product Owner**
5. CI jobs read waiver metadata and allow merge

**Note**: Waivers are **NOT allowed** for secrets detected in the repository. Any secrets must be removed before merge.

---

### Continuous Deployment (CD)

The CD pipeline handles automated deployments to `nonprod` and `prod` environments after successful merges. Each environment has different validation requirements as defined in the constitution (§7).

#### CD to `nonprod` Environment

**Pipeline Trigger**: PR merged from `main` → `nonprod` branch

**CD Workflow for nonprod**:

```
┌──────────────────┐
│  main branch     │
│ (build-YYYYMM... │
└────────┬─────────┘
         │ PR: main → nonprod
         ▼
┌──────────────────────────────┐
│ 1. Deploy to nonprod env     │
│    - tofu init               │
│    - tofu plan               │
│    - tofu apply              │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ 2. Post-Deployment Tests     │
│    (Run in parallel)         │
│                              │
│  ┌─────────────────────┐    │
│  │ cd-integration-tests│    │ ← Full BDD scenarios (Terratest)
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │   cd-smoke-tests    │    │ ← Critical path tests (@smoke tag)
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │      cd-dast        │    │ ← OWASP ZAP dynamic security scan
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │cd-runtime-compliance│    │ ← CIS benchmark validation
│  └─────────────────────┘    │
└────────┬─────────────────────┘
         │ All tests pass
         ▼
┌──────────────────────────────┐
│ 3. Tag and Promote           │
│    - Merge PR to nonprod     │
│    - Tag: nonprod-YYYYMM...  │
│    - Ready for prod          │
└──────────────────────────────┘
```

**nonprod CD Jobs** (constitution §7):

| Job Name | Tool/Framework | What It Does | Blocking | Duration |
|----------|----------------|--------------|----------|----------|
| **`cd-deploy-nonprod`** | OpenTofu | Deploys infrastructure to nonprod environment | Deployment failure blocks promotion | ~15 min |
| **`cd-integration-tests`** | Terratest (Go) + Cucumber | Runs full BDD scenarios from `features/` and `tests/integration/` | Test failures block promotion | ~20 min |
| **`cd-smoke-tests`** | Terratest (Go) + Cucumber | Runs critical path tests tagged with `@smoke` | Test failures block promotion | ~5 min |
| **`cd-dast`** | OWASP ZAP | Dynamic Application Security Testing against live endpoints | Scan failures block promotion | ~10 min |
| **`cd-runtime-compliance`** | CIS benchmark tools | Validates runtime configuration against security baselines | Compliance failures block promotion | ~8 min |

**Definition of Done for nonprod** (constitution §DoD):
- ✅ Infrastructure successfully deployed to nonprod environment
- ✅ All integration tests pass (Terratest BDD scenarios)
- ✅ All smoke tests pass (critical paths validated)
- ✅ DAST scan completes and report attached
- ✅ Runtime compliance checks pass
- ✅ Stakeholder acceptance criteria met
- ✅ Build tagged as `nonprod-YYYYMMDDHHmm`
- ✅ Ready for production promotion

---

#### CD to `prod` Environment

**Pipeline Trigger**: PR merged from `nonprod` → `prod` branch (requires approval)

**CD Workflow for prod**:

```
┌──────────────────────┐
│  nonprod branch      │
│ (nonprod-YYYYMM...)  │
└────────┬─────────────┘
         │ PR: nonprod → prod (with approval)
         ▼
┌──────────────────────────────┐
│ 1. Blue/Green Tag Setup      │
│    - Tag current prod "blue" │
│    - Tag candidate "green"   │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ 2. Deploy to prod env        │
│    - Deploy "green" tag      │
│    - tofu apply              │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ 3. Post-Deployment Tests     │
│                              │
│  ┌─────────────────────┐    │
│  │   cd-smoke-tests    │    │ ← Critical validation
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │      cd-dast        │    │ ← Production security scan
│  └─────────────────────┘    │
└────────┬─────────────────────┘
         │
         ├─── Tests PASS ────────────────┐
         │                               ▼
         │                    ┌──────────────────────┐
         │                    │ 4. Tag Success       │
         │                    │    - prod-YYYYMM...  │
         │                    │    - Keep "green"    │
         │                    └──────────────────────┘
         │
         └─── Tests FAIL ────────────────┐
                                         ▼
                              ┌──────────────────────┐
                              │ 5. Rollback          │
                              │    - Tag "blue" as   │
                              │      "green"         │
                              │    - Redeploy        │
                              │    - Alert team      │
                              └──────────────────────┘
```

**prod CD Jobs** (constitution §7):

| Job Name | Tool/Framework | What It Does | Blocking | Duration |
|----------|----------------|--------------|----------|----------|
| **`cd-deploy-prod`** | OpenTofu | Deploys "green" tag to prod environment with blue/green strategy | Deployment failure triggers rollback | ~15 min |
| **`cd-smoke-tests`** | Terratest (Go) + Cucumber | Validates critical paths in production | Test failures trigger rollback | ~5 min |
| **`cd-dast`** | OWASP ZAP | Security scan against production endpoints | Scan failures trigger rollback | ~10 min |
| **`cd-rollback`** | OpenTofu | Automatically reverts to "blue" tag if tests fail | Triggered on test failures | ~10 min |

**Definition of Done for prod** (constitution §DoD):
- ✅ Blue/green tags created successfully
- ✅ "green" tag deployed to prod environment
- ✅ Smoke tests pass in production
- ✅ DAST scan completes and report attached
- ✅ No rollback triggered (or rollback completed successfully)
- ✅ Build tagged as `prod-YYYYMMDDHHmm`
- ✅ Deployment notification sent to stakeholders

**Rollback on Failure**:

If any post-deployment test fails in production:

1. **Automated actions**:
   ```bash
   git tag -f green blue              # Point green back to blue (last known good)
   git push origin green --force      # Update green tag
   tofu apply                         # Redeploy blue (via green tag)
   ```

2. **Notifications**:
   - GitHub issue created with `production-incident` label
   - Infrastructure team alerted
   - Incident logged in CHANGELOG.md

3. **Postmortem required**:
   - Root cause analysis
   - Remediation plan
   - Process improvements

---

### CI/CD Pipeline Architecture

**Complete Pipeline Flow**:

```
 Issue Branch
      │
      │ git push
      ▼
┌───────────────────┐
│   Pull Request    │
│   to main         │
└─────────┬─────────┘
          │
          ▼
┌─────────────────────────────────────────┐
│          CI PIPELINE (on PR)            │
│  ┌──────────────────────────────────┐  │
│  │ ci-format-lint                   │  │
│  │ ci-secrets-scan                  │  │
│  │ ci-sca                           │  │
│  │ ci-sast-threatmodel              │  │
│  │ ci-iac-compliance                │  │
│  │ build-and-scan-image             │  │
│  └──────────────────────────────────┘  │
│  → Tag: build-YYYYMMDDHHmm            │
└─────────┬───────────────────────────────┘
          │ Merge to main
          ▼
┌─────────────────────────────────────────┐
│    CD PIPELINE (nonprod deployment)     │
│  ┌──────────────────────────────────┐  │
│  │ cd-deploy-nonprod                │  │
│  │ cd-integration-tests             │  │
│  │ cd-smoke-tests                   │  │
│  │ cd-dast                          │  │
│  │ cd-runtime-compliance            │  │
│  └──────────────────────────────────┘  │
│  → Tag: nonprod-YYYYMMDDHHmm          │
└─────────┬───────────────────────────────┘
          │ Approval + PR to prod
          ▼
┌─────────────────────────────────────────┐
│      CD PIPELINE (prod deployment)      │
│  ┌──────────────────────────────────┐  │
│  │ cd-deploy-prod (blue/green)      │  │
│  │ cd-smoke-tests                   │  │
│  │ cd-dast                          │  │
│  │ [cd-rollback if tests fail]      │  │
│  └──────────────────────────────────┘  │
│  → Tag: prod-YYYYMMDDHHmm (or rollback)│
└─────────────────────────────────────────┘
```

**Pipeline Files Location**:

- `.github/workflows/ci.yml` - CI pipeline definition
- `.github/workflows/cd-nonprod.yml` - nonprod deployment pipeline
- `.github/workflows/cd-prod.yml` - prod deployment pipeline
- `pre-commit-config.yaml` - Local pre-commit hooks (mirrors CI checks)

**Environment Variables** (12-Factor configuration):

All pipelines use environment-specific variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `TF_VAR_environment` | Target environment | `nonprod`, `prod` |
| `TF_VAR_project_id` | GCP project ID | `vibetics-nonprod-123456` |
| `TF_VAR_region` | Deployment region | `northamerica-northeast2` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Service account key for deployment | (stored in GitHub Secrets) |

**Status Badges** (add to top of README):

```markdown
![CI Status](https://github.com/vibetics/cloudedge/workflows/CI/badge.svg)
![nonprod Deployment](https://github.com/vibetics/cloudedge/workflows/CD-nonprod/badge.svg)
![prod Deployment](https://github.com/vibetics/cloudedge/workflows/CD-prod/badge.svg)
```

## License

This project is under a proprietary license. See [LICENSE.md](./LICENSE.md) for more details.