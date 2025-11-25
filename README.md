# Vibetics CloudEdge

This repository contains the Infrastructure as Code (IaC) for the Vibetics CloudEdge platform, managed by OpenTofu. The purpose of this project is to provide a secure, standardized, and cloud-agnostic baseline infrastructure that can be deployed rapidly and consistently across multiple cloud providers.

## Infrastructure Architecture

### Overview

The Vibetics CloudEdge platform provides a **modular secure baseline infrastructure** with 9 configurable components designed for cloud-agnostic deployments. This MVP (Feature 001) focuses on establishing the foundational security and networking layers with a demo Cloud Run backend for validation.

For detailed architecture documentation, including scope definitions, future roadmap, and deep dives, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).


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
| **Ingress VPC** | Firewall Source Restriction | Restricts HTTPS traffic to configurable source ranges (default: Google Cloud Load Balancer IPs `35.191.0.0/16`, `130.211.0.0/22`) | **Defense-in-depth**: Even if WAF is bypassed, only allowed IPs can reach the ingress layer. Configure via `allowed_https_source_ranges` variable in firewall module. Use `["0.0.0.0/0"]` for testing only. |
| **Load Balancer** | SSL Certificate | TLS 1.2+ encryption | Encrypts data in transit |
| **Load Balancer** | URL Map | Domain-based routing via Host header | Routes traffic to correct backend based on hostname |
| **Backend** | Serverless NEG | Serverless network endpoint | Connects load balancer to Cloud Run without public exposure |
| **Backend** | Cloud Run Ingress | `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` | **Blocks direct public access**, allows only load balancer traffic |
| **Backend** | IAM Policy | `roles/run.invoker` for `allUsers` | **INTENTIONAL for load balancer forwarding**: Cloud Run requires IAM authentication, but Google Cloud Load Balancers cannot provide service account credentials when forwarding traffic. The `allUsers` binding allows the LB to invoke the service. Security is enforced at network layer (WAF, firewall, ingress policy) NOT at Cloud Run IAM layer. |
| **Backend** | Serverless NEG | Google-managed networking | Direct Load Balancer → Cloud Run connectivity via Google's private network (no VPC Connector needed for serverless backends) |


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

## Module Dependency Graph

For the complete module dependency diagram and details, see [docs/MODULES.md](docs/MODULES.md).

### Module Output Wiring Summary

The root `main.tf` wires module outputs to inputs to create a cohesive infrastructure:

| **Consumer Module**   | **Input Variable**       | **Source Module**          | **Output**                    | **Reference Location** |
|-----------------------|--------------------------|----------------------------|-------------------------------|------------------------|
| `firewall`            | `network_name`           | `ingress_vpc`              | `ingress_vpc_name`            | main.tf:83             |
| `cdn`                 | `bucket_name`            | `google_storage_bucket`    | `cdn_content.name`            | main.tf:125            |
| `dr_loadbalancer`     | `default_service_id`     | `demo_backend`             | `backend_service_id`          | main.tf:178            |
| `dr_loadbalancer`     | `ssl_certificates`       | `self_signed_cert`         | `self_link`                   | main.tf:179            |

### Root Module Outputs

All module outputs are exposed at the root level for external consumption:

- **Load Balancer**: `load_balancer_ip`, `load_balancer_url`, `access_instructions`
- **VPC Networks**: `ingress_vpc_name`, `ingress_vpc_id`, `egress_vpc_name`, `egress_vpc_id`
- **Security**: `waf_policy_name`, `waf_policy_id`, `firewall_rule_name`
- **Backend Services**: `demo_backend_service_name`, `cloud_run_service_name`, `cloud_run_service_url`
- **CDN**: `cdn_backend_name`
- **Billing**: `billing_budget_id`
- **Tags**: `resource_tags`

**Note**: The `access_instructions` output provides a complete guide for accessing the deployed infrastructure, including curl examples with the correct Host header for domain-based routing.

## Quick Start

For detailed prerequisites, setup instructions, and troubleshooting, see [docs/QUICKSTART.md](docs/QUICKSTART.md).

### Core Deployment Commands

1. **Clone and Setup**:

   ```bash
   git clone <repository-url>
   cd vibetics-cloudedge
   cp .env.example .env
   # Edit .env with your project details
   ```

2. **Deploy**:

   ```bash
   source .env
   ./scripts/setup-backend.sh  # First time only
   ./scripts/deploy.sh
   ```

3. **Teardown**:

   ```bash
   ./scripts/teardown.sh
   ```

### Configuration

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for feature flags and environment variables.

## Testing Strategy

This project employs a two-tiered, Test-Driven Development (TDD) approach:

- **Tier 1**: Unit tests for individual OpenTofu modules (planned)
- **Tier 2**: Integration tests using Terratest (Go) with BDD scenarios

For detailed test execution commands, troubleshooting, and CI/CD pipeline integration, see [docs/TESTING.md](docs/TESTING.md).

## Security Documentation

This project implements defense-in-depth security with multiple layers of protection. For the security controls table, see the [Key Security Controls](#key-security-controls) section in the Architecture Overview above.

### Threat Modeling

This project requires threat modeling as mandated by the [constitution](.specify/memory/constitution.md) (§7). We use **Threagile** - an open-source threat modeling toolkit that automatically generates threat reports via CI/CD pipelines.

- **Automated CI Validation**: Threat model reports generated on every PR
- **STRIDE Analysis**: Manual threat modeling required for major architecture changes
- **Pre-Commit Hooks**: Validates threat model YAML syntax before commits

For detailed threat modeling workflows, local execution guides, risk tracking procedures, and STRIDE methodology, see [docs/SECURITY.md](docs/SECURITY.md).

## Documentation

This README provides a high-level overview and quick start guide. For detailed documentation, see the `docs/` directory:

| Document | Description |
|----------|-------------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture diagrams, MVP scope, future roadmap, and design decisions |
| [docs/SECURITY.md](docs/SECURITY.md) | Threat modeling workflows, STRIDE analysis, CI/CD security validation, and risk tracking |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Comprehensive setup guide including prerequisites, GCP setup, authentication, and troubleshooting |
| [docs/TESTING.md](docs/TESTING.md) | Testing strategy, execution commands, BDD scenarios, and CI/CD test integration |
| [docs/MODULES.md](docs/MODULES.md) | Module dependency graphs, directory structure, and output wiring details |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Feature flags, environment variables, and customization guides |

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

#### YAML Files (*.YAML,*.yml)

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

Pre-commit hooks automatically run security and quality checks before each commit, mirroring the CI pipeline gates to provide fast local feedback. These hooks catch issues early, before they reach the CI pipeline.

**What pre-commit hooks check**:

- ✅ Code formatting (OpenTofu, Python, Go, Markdown, YAML)
- ✅ Secrets scanning (gitleaks)
- ✅ IaC compliance (checkov - CIS benchmarks)
- ✅ Security vulnerabilities (semgrep SAST)
- ✅ OpenTofu validation and linting (tflint)
- ✅ Conventional commit message format
- ✅ File quality (trailing spaces, newlines, large files)

#### Prerequisites

Before installing pre-commit hooks, ensure you have the following tools installed:

```bash
# 1. Verify Python 3.12+ and Poetry are installed
python --version  # Should be 3.12 or higher
poetry --version

# 2. Install TFLint (for OpenTofu/Terraform linting)
# macOS:
brew install tflint

# Linux:
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Windows (WSL):
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# 3. Install gitleaks (for secrets scanning)
# macOS:
brew install gitleaks

# Linux/WSL:
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.2/gitleaks_8.18.2_linux_x64.tar.gz
tar -xzf gitleaks_8.18.2_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/

# Or via Go:
go install github.com/gitleaks/gitleaks/v8@latest

# 4. Verify installations
tflint --version
gitleaks version
```

#### Installation Steps

1. **Install project dependencies** (includes pre-commit framework):

    ```bash
    poetry install
    ```

2. **Install pre-commit hooks into Git**:

    ```bash
    # Install both pre-commit and commit-msg hooks
    poetry run pre-commit install --install-hooks --hook-type pre-commit --hook-type commit-msg
    ```

    **Expected output**:

    ```
    pre-commit installed at .git/hooks/pre-commit
    pre-commit installed at .git/hooks/commit-msg
    [INFO] Installing environment for https://github.com/pre-commit/pre-commit-hooks.
    [INFO] Installing environment for https://github.com/gitleaks/gitleaks.
    ... (multiple hook installations)
    [INFO] Installation complete.
    ```

    **Note**: The first installation downloads and installs all hook dependencies. This may take 5-10 minutes.

3. **Initialize TFLint plugins**:

    ```bash
    # Download TFLint plugins (Terraform and GCP rulesets)
    tflint --init
    ```

    **Expected output**:

    ```
    Installing "terraform" plugin...
    Installing "google" plugin...
    Installed "terraform" (source: github.com/terraform-linters/tflint-ruleset-terraform, version: 0.5.0)
    Installed "google" (source: github.com/terraform-linters/tflint-ruleset-google, version: 0.27.1)
    ```

4. **Verify installation** (first run will be slow):

    ```bash
    # Test hooks on all files (downloads hook environments on first run)
    poetry run pre-commit run --all-files
    ```

    **First run**: Takes 5-10 minutes as it downloads and caches all hook dependencies.

    **Subsequent runs**: Much faster (< 1 minute for typical changes).

#### Usage

**Automatic execution** (recommended):

Hooks run automatically on every `git commit`:

```bash
# Make changes
vim main.tf

# Stage changes
git add main.tf

# Commit (hooks run automatically before commit)
git commit -m "feat: add WAF rate limiting rules"
```

**Hook execution flow**:

```
git commit
  ├─ File quality checks (5s)
  ├─ Secrets scan - gitleaks (10s)
  ├─ OpenTofu format - tofu fmt (15s)
  ├─ OpenTofu validate (20s)
  ├─ OpenTofu lint - tflint (30s)
  ├─ IaC compliance - checkov (45s)
  ├─ SAST - semgrep (45s)
  ├─ Python/Go formatting (10s)
  ├─ Markdown/YAML linting (5s)
  └─ Conventional commit check (1s)

  ✅ All hooks passed → Commit succeeds
  ❌ Any hook failed → Commit blocked, fix issues and retry
```

**Manual execution**:

Run hooks without committing:

```bash
# Run all hooks on all files
poetry run pre-commit run --all-files

# Run all hooks on staged files only
poetry run pre-commit run

# Run specific hook
poetry run pre-commit run terraform_fmt --all-files
poetry run pre-commit run gitleaks --all-files
poetry run pre-commit run checkov --all-files
```

**Bypass hooks** (use sparingly):

```bash
# Skip hooks for work-in-progress commits (feature branches only)
git commit --no-verify -m "wip: debugging firewall rules"

# Or use shorthand
git commit -n -m "wip: incomplete changes"
```

**⚠️ WARNING**:

- Only bypass for WIP commits on feature branches
- Never bypass secrets scanning (gitleaks)
- Never bypass for commits to `main`, `nonprod`, or `prod` branches

#### Configuration Files

Pre-commit hooks use these configuration files (already created):

| File | Purpose |
|------|---------|
| `.pre-commit-config.yaml` | Main hook configuration (30+ checks) |
| `.tflint.hcl` | TFLint rules and GCP plugin configuration |
| `.tflintignore` | Files/directories excluded from TFLint |
| `.checkov.yaml` | Checkov IaC compliance rules (CIS benchmarks) |
| `.markdownlint.yaml` | Markdown linting rules |
| `.yamllint.yaml` | YAML linting rules |

#### Troubleshooting

**Error: `tflint: command not found`**

```bash
# Install TFLint (see Prerequisites section above)
brew install tflint  # macOS
# or
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash  # Linux/WSL
```

**Error: `gitleaks: command not found`**

```bash
# Install gitleaks (see Prerequisites section above)
brew install gitleaks  # macOS
# or
go install github.com/gitleaks/gitleaks/v8@latest
```

**Error: `terraform_validate` fails**

```bash
# Initialize OpenTofu with backend disabled (for validation only)
tofu init -backend=false

# Retry hook
poetry run pre-commit run terraform_validate --all-files
```

**Error: `terraform_tflint` fails with "Failed to initialize plugins"**

```bash
# Initialize TFLint plugins
tflint --init

# Retry hook
poetry run pre-commit run terraform_tflint --all-files
```

**Hooks are too slow**:

```bash
# Option 1: Run only on changed files (default)
git commit  # Only checks staged files

# Option 2: Skip specific slow hooks temporarily
SKIP=semgrep,terraform_checkov git commit -m "wip: fast commit"

# Option 3: Bypass for WIP commits (feature branches only)
git commit --no-verify -m "wip: debugging"
```

#### Updating Hooks

Update hooks monthly to get latest security rules:

```bash
# Update to latest hook versions
poetry run pre-commit autoupdate

# Test updated hooks
poetry run pre-commit run --all-files

# Commit updates
git add .pre-commit-config.yaml
git commit -m "chore: update pre-commit hooks"
```

#### Additional Documentation

For comprehensive setup instructions, troubleshooting, and best practices, see:

- **[Pre-commit Setup Guide](docs/PRE_COMMIT_SETUP.md)** - Complete 50+ page guide
- **Constitution §7** - DevSecOps gates and requirements
- **CI/CD Section** (below) - How pre-commit mirrors CI pipeline

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

## Contributing

This project follows the branching strategy and Git workflow described in the [Branching Strategy & Git Workflow](#branching-strategy--git-workflow) section. All contributions must:

1. Follow the constitution guidelines defined in [.specify/memory/constitution.md](.specify/memory/constitution.md)
2. Create feature branches from GitHub issues
3. Pass all CI/CD checks (linting, security scans, tests)
4. Include threat model updates for architectural changes
5. Follow the promotion flow: feature → main → nonprod → prod

For more details on the development workflow, see the [Development Workflow](#development-workflow) section.

## License

This project is under a proprietary license. See [LICENSE.md](./LICENSE.md) for more details.
