# CI Quick Reference

## Pipeline Overview

```
┌─────────────────┐
│   PR Created    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Pre-commit     │◄── Secrets, SAST, Linting
│  (3-5 min)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Threat Modeling │◄── Threagile Analysis
│  (2-4 min)      │
└────┬───────┬────┘
     │       │
     │       └──────────────┐
     ▼                      ▼
┌─────────────┐      ┌──────────────┐
│ PR Comment  │      │ Threat Gate  │◄── Blocks if untracked risks
└─────────────┘      └──────┬───────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ Untracked?   │
                     └──┬────────┬──┘
                   YES  │        │ NO
                        │        │
                        ▼        ▼
                  ┌──────────┐  ┌──────┐
                  │PO Label? │  │ PASS │
                  └──┬────┬──┘  └──────┘
                 YES │    │ NO
                     │    │
                     ▼    ▼
                  ┌────┐┌────┐
                  │PASS││FAIL│
                  └────┘└────┘
```

## Developer Cheat Sheet

### ✅ Fix Pre-commit Failures

```bash
# Run all hooks locally
poetry run pre-commit run --all-files

# Auto-fix formatting
poetry run pre-commit run --all-files --hook-stage manual

# Fix specific hook
poetry run pre-commit run <hook-id> --all-files
```

### ✅ Track Security Risks

1. Download `risks.json` from workflow artifacts
2. Add to `threat_modelling/threat-model.yaml`:

```yaml
risk_tracking:
  - synthetic_id: "@risk-id-from-json"
    status: "accepted"  # or: mitigated, in-progress, in-discussion
    justification: "Why this risk is acceptable"
    ticket: "JIRA-1234"
    date: "2025-10-18"
    checked_by: "team-name"
```

1. Commit and push

### ✅ Request PO Approval

1. Review risks with Product Owner
2. PO adds `po-approved` label to PR
3. Document acceptance in PR description
4. Merge (risk acceptance logged)

### ✅ Test Locally

```bash
# Generate threat model
./scripts/generate-threat-model.sh --local

# Check untracked risks
jq '.[] | select(.risk_status == "unchecked")' \
  threat_modelling/reports/risks.json

# Run pre-commit
poetry run pre-commit run --all-files
```

## CI Job Reference

| Job | Duration | Blocks PR | Artifacts |
|-----|----------|-----------|-----------|
| Pre-commit | 3-5 min | ✅ Yes | Logs (7d) |
| Threat Modeling | 2-4 min | ❌ No | Reports (30d) |
| PR Comment | <1 min | ❌ No | - |
| Threat Gate | <1 min | ✅ Yes* | - |
| OpenTofu | 2-3 min | ✅ Yes | Plan (7d) |
| Summary | <1 min | ❌ No | - |

*Blocks unless `po-approved` label present

## Risk Status Values

| Status | Meaning | Blocks PR? |
|--------|---------|------------|
| `unchecked` | Not reviewed | ✅ Yes |
| `accepted` | Risk accepted | ❌ No |
| `mitigated` | Risk mitigated | ❌ No |
| `in-progress` | Fix in progress | ❌ No |
| `in-discussion` | Under review | ❌ No |
| `false-positive` | Not a real risk | ❌ No |

## Common Issues

### Pre-commit fails in CI but passes locally

```bash
# Clear cache and reinstall
poetry run pre-commit clean
poetry run pre-commit install-hooks
poetry run pre-commit run --all-files
```

### Threat gate blocks incorrectly

```bash
# Check synthetic_id matches exactly
jq '.[] | .synthetic_id' threat_modelling/reports/risks.json

# Verify tracking entry
grep -A 5 "synthetic_id:" threat_modelling/threat-model.yaml
```

### Need to re-run CI

```bash
# Push empty commit
git commit --allow-empty -m "chore: trigger CI"
git push
```

## Labels

- `po-approved` - PO accepts security risks (bypasses threat gate)

## Secrets Required

- `GCP_PROJECT_ID` - GCP project for OpenTofu plans

## Full Documentation

See [docs/CI_WORKFLOW.md](../docs/CI_WORKFLOW.md) for complete guide.
