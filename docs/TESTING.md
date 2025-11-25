# Testing Strategy

This project employs a two-tiered, Test-Driven Development (TDD) approach as mandated by the [constitution](.specify/memory/constitution.md).

## Tier 1: Unit Tests (Local, Pre-Commit)

Unit tests are designed to validate the logic of individual OpenTofu modules in isolation, without deploying real resources.

- **Framework**: OpenTofu Native Testing (`tofu test`)
- **Location**: `*.tftest.hcl` files within each module's directory
- **Status**: ⚠️ **Not yet implemented** - Native unit tests are planned for future iterations

**Note**: Currently, this project uses **Tier 2 integration tests only** (see below). The `tofu test` command will return `0 passed, 0 failed` because no `.tftest.hcl` files exist yet. For testing infrastructure, use the Terratest integration tests described in Tier 2.

## Tier 2: Integration & BDD Tests (Post-Deployment)

This tier validates the behavior of the fully deployed infrastructure. It is driven by Behavior-Driven Development (BDD) principles.

- **Framework**: Terratest (Go) with Cucumber for BDD.
- **Specifications**: Human-readable Gherkin scenarios are defined in `.feature` files within the `features/` directory.
- **Implementation**: The Go test files in `tests/integration/` and `tests/contract/` implement the steps defined in the Gherkin scenarios.

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

- **Continuous Integration (CI)**: On every Pull Request, the CI pipeline runs static analysis (Checkov, Semgrep) and OpenTofu validation. Unit tests (`.tftest.hcl` files) are planned for future implementation.
- **Continuous Deployment (CD)**: After a successful deployment to the `nonprod` environment, the CD pipeline will execute the **Tier 2 Integration and Smoke Tests** against the live infrastructure to ensure it is behaving as expected. This is also where post-deployment DAST scans will be run.
