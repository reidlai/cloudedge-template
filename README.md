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
4.  **Configure Cloud Credentials**: For GCP, ensure your credentials are configured as environment variables (e.g., `GOOGLE_APPLICATION_CREDENTIALS`).
5.  **Enable Required GCP APIs**: Before the first deployment to a new GCP project, you **MUST** manually enable the necessary APIs. This is a one-time setup step that cannot be automated in OpenTofu without circular dependencies.

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

6.  **Grant Deployment IAM Roles**: The account or service account running `tofu apply` requires specific IAM permissions to create and manage GCP resources. This is a **one-time setup per environment** that must be completed before your first deployment.

    **Why manual IAM role assignment?** OpenTofu cannot grant itself the permissions it needs to run (chicken-and-egg problem). These permissions must be configured outside of the IaC repository. Additionally, managing IAM credentials or service account keys in code would violate security best practices.

    **Identify your deployment account**:
    ```bash
    # Check which account is currently active
    gcloud auth list

    # View current account
    gcloud config get-value account
    ```

    **Required IAM Roles**:

    The deployment account needs the following roles to provision all infrastructure components:

    | Role | Purpose | Resources Managed |
    |------|---------|-------------------|
    | `roles/run.admin` | Cloud Run administration | Create/update/delete Cloud Run services, configure ingress policies, manage IAM bindings |
    | `roles/compute.networkAdmin` | Network resource management | Create VPCs, subnets, firewall rules, load balancers, forwarding rules, backend services, NEGs |
    | `roles/compute.securityAdmin` | Security policy management | Create/manage Cloud Armor (WAF) security policies, SSL certificates |
    | `roles/compute.loadBalancerAdmin` | Load balancer configuration | Configure global external HTTPS load balancers, URL maps, target proxies, health checks |
    | `roles/iam.serviceAccountUser` | Service account impersonation | Allow Cloud Run services to use service accounts for authentication |

    **Grant roles to your user account** (for local development):
    ```bash
    # Set your project ID and account
    PROJECT_ID="vibetics-nonprod-475417"  # Replace with your project ID
    ACCOUNT=$(gcloud config get-value account)

    # Grant all required roles
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="user:$ACCOUNT" \
      --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="user:$ACCOUNT" \
      --role="roles/compute.networkAdmin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="user:$ACCOUNT" \
      --role="roles/compute.securityAdmin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="user:$ACCOUNT" \
      --role="roles/compute.loadBalancerAdmin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="user:$ACCOUNT" \
      --role="roles/iam.serviceAccountUser"
    ```

    **Grant roles to a service account** (for CI/CD pipelines):
    ```bash
    # Create a service account for deployment automation
    SERVICE_ACCOUNT_NAME="opentofu-deployer"
    PROJECT_ID="vibetics-nonprod-475417"  # Replace with your project ID

    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
      --display-name="OpenTofu Deployment Service Account" \
      --project=$PROJECT_ID

    # Get the service account email
    SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

    # Grant all required roles to the service account
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/compute.networkAdmin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/compute.securityAdmin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/compute.loadBalancerAdmin"

    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/iam.serviceAccountUser"
    ```

    **Verification**: Confirm IAM roles are assigned (may take 60-120 seconds to propagate):
    ```bash
    # For user accounts
    gcloud projects get-iam-policy $PROJECT_ID \
      --flatten="bindings[].members" \
      --filter="bindings.members:user:$ACCOUNT" \
      --format="table(bindings.role)"

    # For service accounts
    gcloud projects get-iam-policy $PROJECT_ID \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:$SA_EMAIL" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see all 5 roles listed in the output.

    **Troubleshooting**:
    - **Error: "Permission denied"** during role assignment → You need `roles/resourcemanager.projectIamAdmin` or `roles/owner` on the project to grant roles
    - **Error: "Error 403: Permission 'X' denied"** during deployment → The listed permission is missing; re-run the role assignment commands above
    - **Roles not showing in verification** → IAM changes can take up to 2 minutes to propagate; wait and re-run verification

    **Security Note**: These roles follow the **principle of least privilege** for infrastructure deployment. The `roles/editor` or `roles/owner` roles are NOT recommended as they grant excessive permissions beyond what's needed for this deployment.

7.  **Refresh Application Default Credentials (ADC)**: After granting IAM roles to your account, you **MUST** refresh your Application Default Credentials so that OpenTofu can use your updated permissions. This is a **critical step** that is often missed.

    **Why is this required?** Google Cloud uses two separate credential systems:

    | Credential Type | Command | Used By | When to Refresh |
    |-----------------|---------|---------|-----------------|
    | **User Credentials** | `gcloud auth login` | gcloud CLI commands | When switching Google accounts |
    | **Application Default Credentials (ADC)** | `gcloud auth application-default login` | OpenTofu, GCP client libraries, SDKs | **After granting new IAM roles** |

    When you grant IAM roles to your user account (step 6), those permissions are attached to your Google identity. However, OpenTofu doesn't use your `gcloud auth login` credentials - it uses **Application Default Credentials (ADC)**, which are separate and need to be refreshed separately.

    **Refresh ADC credentials**:
    ```bash
    gcloud auth application-default login
    ```

    This command will:
    1. Open your browser automatically
    2. Prompt you to sign in with your Google account (use the same account from step 6)
    3. Ask you to grant permissions to "Google Auth Library"
    4. Save the new credentials to `~/.config/gcloud/application_default_credentials.json`

    **Wait for the terminal to show**: `Credentials saved to file: [/home/user/.config/gcloud/application_default_credentials.json]`

    **Verify ADC credentials are refreshed**:
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

    **When to Refresh ADC**:
    - ✅ **Required**: After granting new IAM roles to your user account (first-time setup)
    - ✅ **Required**: After switching to a different Google Cloud project
    - ✅ **Required**: If you see 403 permission errors during OpenTofu operations
    - ❌ **Not required**: When running regular `gcloud` commands (those use user credentials)

### Deployment

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd vibetics-cloudedge
    ```

2.  **Initialize OpenTofu**:
    ```bash
    tofu init
    ```

3.  **Set Environment Variables**: For local development, create a `.env` file in the root of the project. **IMPORTANT**: Ensure `.env` is added to your `.gitignore` file to prevent committing secrets.

    Your `.env` file should export variables with the `TF_VAR_` prefix. For example:
    ```bash
    TF_VAR_cloud_provider="gcp"
    TF_VAR_project_id="your-gcp-project-id"
    TF_VAR_region="your-gcp-region"
    TF_VAR_default_backend_group_id="your-instance-group-name"
    ```
    
    The `default_backend_group_id` is the name of the instance group that the load balancer will send traffic to by default. You will need to replace `"your-instance-group-name"` with a real instance group in your project.

4.  **Deploy the infrastructure**: Source the environment variables and then run the deployment script.
    ```bash
    source .env
    ./scripts/deploy.sh
    ```

### Teardown

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

## Development Workflow

This project follows a strict Spec-Driven Development (SDD) workflow and a Git promotion model as defined in the [constitution](.specify/memory/constitution.md). All changes must be made on a feature branch and submitted as a Pull Request to `main`.

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

The CI pipeline is defined in `.github/workflows/ci.yml` and runs automatically on every Pull Request to the `main` branch. It performs the following checks:

-   **Pre-commit Validation**: Runs all pre-commit hooks.
-   **SAST**: Scans the codebase for security vulnerabilities using Semgrep.
-   **OpenTofu Validation**: Initializes, validates, and runs a `tofu plan` to ensure the code is syntactically correct and will not fail on deployment.

### Continuous Deployment (CD)

The CD process is conceptual at this stage and will be implemented in a future feature. As defined in the constitution, the process will be:

1.  **Deploy to `nonprod`**: After a PR is merged to `main`, a CD workflow will deploy the infrastructure to the `nonprod` environment.
2.  **Post-Deployment Testing**: Once the deployment is complete, the following tests will be run against the live `nonprod` environment:
    -   **Integration Tests**: Full BDD tests using Terratest and Cucumber.
    -   **Smoke Tests**: A subset of critical BDD tests tagged with `@smoke`.
    -   **DAST**: Dynamic Application Security Testing using a tool like OWASP ZAP.
3.  **Promotion to `prod`**: If all post-deployment tests pass, the build can be promoted to the `prod` environment.

## License

This project is under a proprietary license. See [LICENSE.md](./LICENSE.md) for more details.