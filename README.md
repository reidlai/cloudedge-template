# Vibetics CloudEdge

This repository contains the Infrastructure as Code (IaC) for the Vibetics CloudEdge platform, managed by OpenTofu. The purpose of this project is to provide a secure, standardized, and cloud-agnostic baseline infrastructure that can be deployed rapidly and consistently across multiple cloud providers.

## Infrastructure Architecture

### Traffic Flow: External Request → Demo API Backend

The following diagram illustrates how incoming traffic is routed from the internet through multiple security layers to reach the demo API backend:

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
│                                    │                                        │
│                          ┌─────────▼─────────┐                              │
│                          │   Cloud CDN       │                              │
│                          │  - Static caching │                              │
│                          │  - Edge serving   │                              │
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
│                         DEMO BACKEND VPC                                    │
│                                    │                                        │
│                          ┌─────────▼───────────┐                            │
│                          │  VPC Connector      │                            │
│                          │  10.12.0.0/28       │                            │
│                          └─────────┬───────────┘                            │
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
│                          └─────────────────────┘                            │
│                                                                             │
│                          ┌─────────────────────┐                            │
│                          │  Egress Firewall    │                            │
│                          │  DENY all egress    │                            │
│                          │  (default-deny)     │                            │
│                          └─────────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         VPC PEERING & ROUTING                               │
│                                                                             │
│   ┌──────────────────┐                           ┌──────────────────┐       │
│   │   Ingress VPC    │◄─────── Peering ─────────►│   Egress VPC     │       │
│   │  10.0.1.0/24     │                           │  10.0.2.0/24     │       │
│   └──────────────────┘                           └──────────────────┘       │
│            │                                              │                 │
│            └──────────────► Peering ◄────────────────────┘                  │
│                                 │                                           │
│                        ┌────────▼────────┐                                  │
│                        │ Demo Backend VPC│                                  │
│                        │  (auto-created) │                                  │
│                        └─────────────────┘                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Security Controls

| Layer | Component | Security Feature | Purpose |
|-------|-----------|------------------|---------|
| **Edge** | Cloud Armor (WAF) | Rate limiting, DDoS protection, OWASP rules | Blocks malicious traffic before it reaches infrastructure |
| **Edge** | Cloud CDN | Cache static content, reduce backend load | Improves performance and reduces attack surface |
| **Load Balancer** | SSL Certificate | TLS 1.2+ encryption | Encrypts data in transit |
| **Load Balancer** | URL Map | Domain-based routing via Host header | Routes traffic to correct backend based on hostname |
| **Backend** | Serverless NEG | Serverless network endpoint | Connects load balancer to Cloud Run without public exposure |
| **Backend** | Cloud Run Ingress | `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` | **Blocks direct public access**, allows only load balancer traffic |
| **Backend** | IAM Policy | `roles/run.invoker` for `allUsers` | Allows unauthenticated access from load balancer (authenticated at edge) |
| **Network** | VPC Connector | Private connectivity | Cloud Run can access VPC resources securely |
| **Network** | Egress Firewall | Default-deny all egress | Prevents data exfiltration from compromised containers |
| **Network** | VPC Peering | Ingress ↔ Egress ↔ Demo Backend | Enables secure internal routing between VPCs |

### Access Validation

**✅ Allowed Traffic Path:**
```bash
curl -k -H "Host: example.com" https://34.117.156.60
# → Cloud Armor → Cloud CDN → HTTPS LB → Backend Service → Serverless NEG → Cloud Run
# Result: HTTP 200 OK with demo API response
```

**❌ Blocked Traffic Path:**
```bash
curl https://nonprod-demo-api-vbuysgm44q-pd.a.run.app
# → Direct to Cloud Run URL
# Result: HTTP 403/404 (blocked by INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER policy)
```

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
3.  **Configure Cloud Credentials**: For GCP, ensure your credentials are configured as environment variables (e.g., `GOOGLE_APPLICATION_CREDENTIALS`).
4.  **Enable Required GCP APIs**: Before the first deployment to a new GCP project, you **MUST** manually enable the necessary APIs. This is a one-time setup step that cannot be automated in OpenTofu without circular dependencies.

    **Why manual enablement?** API enablement requires project-level permissions that create chicken-egg problems if managed in IaC. Additionally, disabling APIs during `tofu destroy` could accidentally delete resources not managed by this project.

    First, ensure your `.env` file is created and sourced, then run:
    ```bash
    source .env
    gcloud services enable \
      --project="$TF_VAR_project_id" \
      compute.googleapis.com \
      run.googleapis.com \
      vpcaccess.googleapis.com \
      cloudresourcemanager.googleapis.com
    ```

    **Required APIs**:
    - `compute.googleapis.com` - Compute Engine (VPCs, Load Balancers, Firewalls, SSL Certificates)
    - `run.googleapis.com` - Cloud Run (Serverless container platform for demo backend)
    - `vpcaccess.googleapis.com` - VPC Access Connector (Cloud Run to VPC connectivity)
    - `cloudresourcemanager.googleapis.com` - Resource Manager (Project metadata and IAM)

    **Verification**: Confirm all APIs are enabled before running `tofu init`:
    ```bash
    gcloud services list --enabled --project="$TF_VAR_project_id" | grep -E 'compute|run|vpcaccess|cloudresourcemanager'
    ```

    If any APIs are missing, you'll encounter errors during `tofu plan` or `tofu apply`.

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
cd tests/contract
go test -v -timeout 10m
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

1.  **Install pre-commit**:
    ```bash
    pip install pre-commit
    ```

2.  **Install the hooks**:
    ```bash
    pre-commit install
    ```

3.  **Run the hooks**: The hooks will run automatically on `git commit`. You can also run them manually at any time:
    ```bash
    pre-commit run --all-files
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