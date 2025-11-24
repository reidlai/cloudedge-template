# Threagile Risk Tracking Quick Reference

This guide shows how to triage and document threat findings from Threagile.

## Quick Start

```bash
# 1. Generate threat model reports
cd threat_modelling
threagile -model threat-model.yaml -output reports \
  -generate-data-flow-diagram=false \
  -generate-data-asset-diagram=false \
  -generate-report-pdf=false \
  -generate-risks-excel=false \
  -generate-tags-excel=false

# 2. List unchecked risks that need triage
jq '.[] | select(.risk_status == "unchecked") | {severity, title, synthetic_id}' reports/risks.json

# 3. Copy the synthetic_id of the risk you want to track

# 4. Edit threat-model.yaml and add to risk_tracking section (at end of file)

# 5. Regenerate and verify
threagile -model threat-model.yaml -output reports \
  -generate-data-flow-diagram=false \
  -generate-data-asset-diagram=false \
  -generate-report-pdf=false \
  -generate-risks-excel=false \
  -generate-tags-excel=false

# 6. Confirm risk status changed
jq '.[] | select(.synthetic_id == "YOUR-RISK-ID-HERE") | {title, risk_status}' reports/risks.json
```

## Risk Status Options

| Status | Use When | Example |
|--------|----------|---------|
| `false-positive` | Risk doesn't apply to this architecture | "Unguarded Access" - auth is at app layer, not infra |
| `mitigated` | Risk has been fixed | "Missing WAF" - Cloud Armor deployed |
| `accepted` | Risk acknowledged, won't fix | "Demo backend build pipeline" - not production app |
| `in-discussion` | Team is evaluating | "Network segmentation" - pending review |
| `unchecked` | Not yet triaged (default) | New risks from latest scan |

## YAML Template

```yaml
risk_tracking:

  PASTE-SYNTHETIC-ID-HERE:
    status: false-positive  # or: mitigated, accepted, in-discussion
    justification: >
      Explain WHY this status is appropriate.

      Include:
      - What the risk is about
      - Why it doesn't apply (false-positive)
      - What was done to fix it (mitigated)
      - Why we chose not to fix (accepted)
      - What's being discussed (in-discussion)

      Reference specific code/config when applicable.
    ticket: INFRA-XXX
    date: YYYY-MM-DD
    checked_by: DevSecOps Team / Security Lead
```

## Common Mistakes

### ❌ WRONG: Abbreviated risk ID

```yaml
xxe@global-https-lb:  # Will fail with "risk id not found"
```

### ✅ CORRECT: Full synthetic_id from risks.json

```yaml
xml-external-entity@global-https-lb:  # Exact match
```

### ❌ WRONG: Typo in status

```yaml
status: accept  # Invalid
```

### ✅ CORRECT: Valid status value

```yaml
status: accepted  # Valid
```

## Viewing Current Status

```bash
# Summary by severity and status
jq '{total_risks: (. | length), by_severity: (group_by(.severity) | map({severity: .[0].severity, count: length})), by_status: (group_by(.risk_status) | map({status: .[0].risk_status, count: length}))}' reports/risks.json

# List all false-positive risks
jq '.[] | select(.risk_status == "false-positive") | {severity, title}' reports/risks.json

# List all elevated/critical unchecked risks (CI blockers)
jq '.[] | select(.risk_status == "unchecked" and (.severity == "critical" or .severity == "elevated")) | {severity, title, synthetic_id}' reports/risks.json

# View specific risk details
jq '.[] | select(.synthetic_id == "unguarded-access-from-internet@cloud-run-backend@global-https-lb@global-https-lb>lb-to-cloud-run")' reports/risks.json
```

## CI/CD Integration

To make CI/CD pass, all critical/elevated risks must be tracked:

```bash
# Check for untracked high-severity risks
UNTRACKED=$(jq '[.[] | select(.risk_status == "unchecked" and (.severity == "critical" or .severity == "elevated"))] | length' reports/risks.json)

if [ "$UNTRACKED" -gt 0 ]; then
  echo "ERROR: $UNTRACKED critical/elevated risks require triage"
  jq '.[] | select(.risk_status == "unchecked" and (.severity == "critical" or .severity == "elevated")) | {severity, title, synthetic_id}' reports/risks.json
  exit 1
fi
```

## Real Examples from This Project

See `threat-model.yaml` lines 521-580 for production examples:

1. **False Positive**: `unguarded-access-from-internet@cloud-run-backend@global-https-lb@global-https-lb>lb-to-cloud-run`
   - Why: Edge infrastructure - app teams deploy API Gateways in containers

2. **False Positive**: `xml-external-entity@global-https-lb`
   - Why: JSON-only APIs - no XML parsing at any layer

## Additional Resources

- [Threagile Documentation](https://threagile.io)
- [STRIDE Threat Modeling](https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling)
- Main README: `../README.md` section "Working with Threat Findings"
