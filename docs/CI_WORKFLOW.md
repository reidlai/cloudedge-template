# CI Workflow Documentation

## Overview

The CI pipeline runs automatically on every pull request and push to `main`/`master` branches. It performs comprehensive security, quality, and threat modeling checks.

## Workflow Jobs

### 1. Pre-commit Hooks (`pre-commit`)

**Purpose**: Run all pre-commit hooks configured in `.pre-commit-config.yaml`

**Checks include**:

- **Secrets scanning** (gitleaks)
- **Security scanning**
  - Python dependencies (pip-audit)
  - Go dependencies (govulncheck)
  - Go code (gosec)
  - IaC compliance (checkov)
- **Code quality**
  - OpenTofu formatting and validation
  - TFLint
  - Python formatting (black, isort)
  - Go formatting
  - Markdown linting
  - YAML linting
- **General quality**
  - Large file detection
  - Trailing whitespace
  - File endings
  - Executable permissions

**Duration**: ~3-5 minutes

**Failure impact**: Blocks entire pipeline

---

### 2. Threat Modeling (`threat-modeling`)

**Purpose**: Generate threat model reports using Threagile and analyze risks

**Process**:

1. Pulls Threagile Docker image
2. Generates threat analysis from `threat_modelling/threat-model.yaml`
3. Creates reports in `threat_modelling/reports/`:
   - `risks.json` - Machine-readable findings
   - `risks.xlsx` - Excel report
   - `report.pdf` - Comprehensive PDF
   - `data-flow-diagram.png` - Architecture diagram
   - `data-asset-diagram.png` - Data flow diagram
4. Analyzes risk counts by severity
5. Identifies untracked critical/elevated risks

**Outputs** (passed to other jobs):

- `critical_count` - Number of critical risks
- `elevated_count` - Number of elevated risks
- `untracked_critical` - Number of untracked critical risks
- `untracked_elevated` - Number of untracked elevated risks
- `total_risks` - Total number of risks
- `risk_summary` - Formatted summary for PR comments

**Artifacts**:

- Threat model reports (30-day retention)
- Untracked risks markdown file

**Duration**: ~2-4 minutes

**Failure impact**: Does not block pipeline (continues with warnings)

---

### 3. PR Comment (`pr-comment`)

**Purpose**: Post or update PR comment with security and threat analysis summary

**Comment includes**:

- Pre-commit check status
- Threat modeling results summary
- Risk counts by severity
- Untracked critical/elevated risks (if any)
- Action items for developers
- PO approval instructions

**Example comment**:

```markdown
## 🛡️ Security & Threat Analysis

### Pre-commit Checks
✅ All pre-commit hooks passed

### Threat Modeling
**Threat Modeling Results**

- 🔴 Critical: 2 (1 untracked)
- 🟠 Elevated: 3 (2 untracked)
- 🟡 High: 5
- 🔵 Medium: 8
- 🟢 Low: 12
- **Total**: 30 risks identified

### ⚠️ Action Required

**1 critical** and **2 elevated** risk(s) are untracked.

## Untracked Critical/Elevated Risks
- [CRITICAL] **SQL Injection in API Gateway** - @critical-sql-injection-api-gateway
- [ELEVATED] **Unencrypted data in transit** - @elevated-unencrypted-transit-lb
- [ELEVATED] **Missing authentication on admin endpoint** - @elevated-missing-auth-admin

#### Next Steps:
1. Review untracked risks in threat model reports
2. Add `risk_tracking` entries to `threat_modelling/threat-model.yaml`
3. Update PR, or request **Product Owner** approval with `po-approved` label

#### Product Owner Override
If risks are accepted, Product Owner can:
- Add label: `po-approved` to bypass this check
- Document acceptance rationale in PR description
```

**Duration**: <1 minute

**Runs**: Only on pull requests

---

### 4. Threat Gate (`threat-gate`)

**Purpose**: Block PR if critical/elevated risks are untracked (unless PO approves)

**Logic**:

```
IF untracked critical OR elevated risks exist:
  IF PR has 'po-approved' label:
    ✅ PASS (with warning)
  ELSE:
    ❌ FAIL (blocks PR merge)
ELSE:
  ✅ PASS
```

**Error message** (when blocked):

```
═══════════════════════════════════════════════════════════════
  ⛔ THREAT MODEL GATE: PR BLOCKED
═══════════════════════════════════════════════════════════════

Found untracked threats:
  - Critical: 1
  - Elevated: 2

To resolve:
  1. Add risk_tracking entries to threat_modelling/threat-model.yaml
  2. OR request Product Owner to add 'po-approved' label

═══════════════════════════════════════════════════════════════
```

**Duration**: <1 minute

**Failure impact**: **BLOCKS PR MERGE** until resolved

---

### 5. OpenTofu Validation (`terraform-validate`)

**Purpose**: Validate infrastructure-as-code syntax and generate plan

**Checks**:

- OpenTofu formatting
- OpenTofu initialization
- Configuration validation
- Plan generation (for PRs)

**Artifacts**:

- `plan.tfplan` - OpenTofu plan file (7-day retention)

**Duration**: ~2-3 minutes

**Failure impact**: Blocks entire pipeline

---

### 6. CI Summary (`ci-summary`)

**Purpose**: Generate overall CI pipeline summary

**Creates GitHub Actions summary** with:

- Status of all jobs
- Risk statistics
- Links to artifacts

**Duration**: <1 minute

**Failure impact**: Reports overall pipeline status

---

## Developer Workflows

### Scenario 1: Normal PR (No Untracked Risks)

1. **Create PR** → CI runs automatically
2. **All checks pass** → Green checkmarks
3. **Merge PR** → No blockers

**Timeline**: 5-10 minutes total

---

### Scenario 2: PR with Untracked Critical/Elevated Risks

#### Option A: Track Risks (Recommended)

1. **Create PR** → CI runs, threat gate fails
2. **Review PR comment** with untracked risks list
3. **Download risks.json** from workflow artifacts
4. **Add risk tracking** to `threat_modelling/threat-model.yaml`:

```yaml
risk_tracking:
  # Example: Accept risk with mitigation
  - synthetic_id: "@critical-sql-injection-api-gateway"
    status: "accepted"
    justification: "Parameterized queries implemented in v2.1"
    ticket: "JIRA-1234"
    date: "2025-10-18"
    checked_by: "security-team"

  # Example: Mitigate risk
  - synthetic_id: "@elevated-unencrypted-transit-lb"
    status: "mitigated"
    justification: "TLS 1.3 enforced on all load balancers"
    ticket: "JIRA-5678"
    date: "2025-10-18"
    checked_by: "devops-team"

  # Example: Risk in progress
  - synthetic_id: "@elevated-missing-auth-admin"
    status: "in-progress"
    justification: "OAuth2 integration scheduled for Sprint 42"
    ticket: "JIRA-9012"
    date: "2025-10-18"
    checked_by: "backend-team"
```

1. **Commit and push** → CI re-runs
2. **Threat gate passes** → Merge PR

**Timeline**: 15-30 minutes (including risk review)

---

#### Option B: Request PO Approval (Risk Acceptance)

**When to use**: Business decision to accept security risk temporarily

1. **Create PR** → CI runs, threat gate fails
2. **Review untracked risks** with Product Owner
3. **PO adds `po-approved` label** to PR
4. **Document acceptance** in PR description:

```markdown
## Risk Acceptance (PO Approved)

**Accepted Risks**:
- Critical SQL injection in API Gateway
  - **Rationale**: Fixing in next major release (v3.0)
  - **Mitigation**: Rate limiting + WAF rules deployed
  - **Review date**: 2025-12-01

**Approved by**: @product-owner-username
**Date**: 2025-10-18
```

1. **CI re-runs** → Threat gate passes with warning
2. **Merge PR** (with documented risk acceptance)

**Timeline**: Depends on PO availability

---

### Scenario 3: Pre-commit Failures

1. **Create PR** → Pre-commit job fails
2. **Check workflow logs** for specific failures
3. **Fix issues locally**:

```bash
# Run pre-commit locally
poetry run pre-commit run --all-files

# Auto-fix formatting issues
poetry run pre-commit run --all-files --hook-stage manual
```

1. **Commit and push** → CI re-runs
2. **Merge PR**

---

## CI Configuration

### Required GitHub Secrets

Add these secrets in repository settings:

- `GCP_PROJECT_ID` - GCP project ID for OpenTofu plans

### Required Permissions

The workflow requires these GitHub token permissions:

- `contents: read` - Checkout code
- `pull-requests: write` - Comment on PRs
- `checks: write` - Report check status
- `issues: write` - Manage labels

### Labels

Create these labels in your repository:

- `po-approved` - Product Owner approval for risk acceptance
  - Color: `#d73a4a` (red)
  - Description: "Product Owner approved risk acceptance"

---

## Troubleshooting

### Threat Modeling Job Fails

**Problem**: Threagile Docker container fails to run

**Solutions**:

1. Check `threat_modelling/threat-model.yaml` syntax
2. Review workflow logs for Threagile errors
3. Test locally:

```bash
./scripts/generate-threat-model.sh --local
```

---

### Pre-commit Hook Failures

**Problem**: Specific hook fails in CI but passes locally

**Solutions**:

1. Ensure tool versions match (see `.pre-commit-config.yaml`)
2. Clear cache:

```bash
poetry run pre-commit clean
poetry run pre-commit install-hooks
```

1. Run specific hook:

```bash
poetry run pre-commit run <hook-id> --all-files
```

---

### Threat Gate Blocks PR Incorrectly

**Problem**: Risks are tracked but gate still blocks

**Solutions**:

1. Verify `synthetic_id` matches exactly in `risks.json`
2. Check `status` is one of: `accepted`, `mitigated`, `in-progress`, `in-discussion`
3. Re-run workflow to regenerate reports
4. Contact Product Owner for `po-approved` label if needed

---

### OpenTofu Plan Fails

**Problem**: OpenTofu validation or plan fails

**Solutions**:

1. Check for syntax errors:

```bash
tofu fmt -check
tofu validate
```

1. Ensure GCP credentials are configured in secrets
2. Review error messages in workflow logs

---

## Advanced Usage

### Skipping Specific Checks

To skip specific pre-commit hooks in CI:

```yaml
- name: Run pre-commit hooks
  run: poetry run pre-commit run --all-files
  env:
    SKIP: hook-id-1,hook-id-2
```

### Manual Workflow Trigger

To manually trigger CI on a branch:

```bash
# Push empty commit
git commit --allow-empty -m "chore: trigger CI"
git push
```

### Local Threat Modeling

To generate threat reports locally:

```bash
# Generate reports
./scripts/generate-threat-model.sh --local

# Analyze results
jq '.[] | select(.risk_status == "unchecked")' threat_modelling/reports/risks.json
```

---

## Performance Optimization

### Caching

The workflow uses caching for:

- Pre-commit hooks (`~/.cache/pre-commit`)
- Python packages (Poetry)
- Go modules
- Node modules

**Cache keys** are based on:

- `.pre-commit-config.yaml` hash
- `poetry.lock` hash
- `go.sum` hash
- `package-lock.json` hash

### Concurrency

The workflow uses concurrency groups to cancel in-progress runs when new commits are pushed to the same PR.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

---

## Security Considerations

### Secrets Handling

- **Never commit secrets** to threat model YAML files
- Use GitHub Secrets for sensitive configuration
- Gitleaks scans for accidental secret commits

### Artifact Retention

- Threat model reports: 30 days
- OpenTofu plans: 7 days
- Pre-commit logs: 7 days

### PO Approval Audit Trail

When PO approves risks:

- Label is visible in PR timeline
- Approval is logged in PR description
- Risk acceptance is documented in commit history

---

## Integration with Other Workflows

This CI workflow can be extended with:

- **CD workflows** - Deploy after CI passes
- **Dependency updates** - Dependabot/Renovate integration
- **Security scanning** - Additional DAST/container scanning
- **Compliance reporting** - Export results to compliance dashboards

See `.github/workflows/cd-*.yaml` for deployment workflows (coming soon).

---

## References

- [Pre-commit Configuration](../docs/PRE_COMMIT_SETUP.md)
- [Threat Modeling Guide](../threat_modelling/RISK_TRACKING_GUIDE.md)
- [Threagile Documentation](https://threagile.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
