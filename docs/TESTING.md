# Integration Testing Guide

This guide provides the correct steps for running integration tests for the GCP infrastructure.

## Quick Start

### 1. Setup Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your GCP project details
# Required: TF_VAR_project_id
# Optional: TF_VAR_environment, TF_VAR_region
```

Example `.env`:
```bash
TF_VAR_project_id=vibetics-nonprod
TF_VAR_environment=nonprod
TF_VAR_region=northamerica-northeast2
TF_VAR_cloud_provider=gcp
GOOGLE_PROJECT=vibetics-nonprod
```

### 2. Clean Environment Before Tests

```bash
# Load environment variables
source .env

# Clean up any leftover resources
./scripts/teardown.sh
```

### 3. Run Tests

```bash
# Load environment variables
source .env

# Run a specific test
cd tests/integration/gcp
go test -v -run TestFirewallSourceRestriction -timeout 20m
```

## Testing Workflow

### Option 1: Individual Test (Recommended)

Run one test at a time to avoid quota limits:

```bash
source .env
cd tests/integration/gcp

# Test firewall source restrictions
go test -v -run TestFirewallSourceRestriction -timeout 20m

# Test CIS compliance
go test -v -run TestCISCompliance -timeout 20m

# Test full baseline deployment
go test -v -run TestFullBaseline -timeout 20m
```

### Option 2: All Tests Sequentially

```bash
source .env
cd tests/integration/gcp

# Run all tests (may take 30+ minutes)
go test -v -timeout 60m
```

### Option 3: Skip Integration Tests

During rapid development, skip integration tests:

```bash
source .env
cd tests/integration/gcp

# Run only fast unit tests
go test -v -short -timeout 5m
```

## Cleanup After Tests

Tests automatically clean up via `defer terraform.Destroy()`. If a test crashes:

```bash
source .env
./scripts/teardown.sh
```

## Verifying Clean State

Check no leftover resources exist:

```bash
source .env

# Should only show "default" network
gcloud compute networks list --project=$TF_VAR_project_id

# Should show no custom security policies
gcloud compute security-policies list --project=$TF_VAR_project_id

# Should show no reserved global IPs
gcloud compute addresses list --project=$TF_VAR_project_id --global
```

## Common Issues

### Issue: Resource Already Exists (409)

**Cause**: Previous test didn't complete cleanup

**Solution**:
```bash
source .env
./scripts/teardown.sh
```

### Issue: Network Quota Exceeded (5 limit)

**Cause**: Multiple VPCs from failed tests

**Solution**:
```bash
source .env

# List all networks
gcloud compute networks list --project=$TF_VAR_project_id

# Delete leftover networks (keep "default")
gcloud compute networks delete <network-name> \
  --project=$TF_VAR_project_id --quiet
```

### Issue: VPC Connector Blocking Deletion

**Cause**: GCP auto-creates firewall rules for VPC connectors

**Solution**:
```bash
source .env

# Delete VPC connector first
gcloud compute networks vpc-access connectors delete <connector-name> \
  --region=$TF_VAR_region --project=$TF_VAR_project_id --quiet

# Then delete network
gcloud compute networks delete <network-name> \
  --project=$TF_VAR_project_id --quiet
```

## Test Interpretation

### Success
```
--- PASS: TestFirewallSourceRestriction (613.13s)
PASS
ok      vibetics-cloudedge/tests/integration/gcp        613.172s
```

### Failure
```
--- FAIL: TestFirewallSourceRestriction (54.30s)
FAIL
exit status 1
FAIL    vibetics-cloudedge/tests/integration/gcp        54.336s
```

**Important**: Always review FULL test output, not just return codes!

## Complete Workflow Example

```bash
# 1. Setup
cp .env.example .env
# Edit .env with your project ID

# 2. Load environment
source .env

# 3. Clean before test
./scripts/teardown.sh

# 4. Verify clean state
gcloud compute networks list --project=$TF_VAR_project_id

# 5. Run test
cd tests/integration/gcp
go test -v -run TestFirewallSourceRestriction -timeout 20m 2>&1 | tee test-output.log

# 6. Review output (not just return code!)
grep -E "PASS|FAIL|Error" test-output.log

# 7. Cleanup (if test crashed)
cd ../../..
source .env
./scripts/teardown.sh
```

## Best Practices

✅ **DO**:
- Always `source .env` before running scripts/tests
- Review FULL test output for errors
- Run tests sequentially to avoid quota limits
- Clean environment before each test run

❌ **DON'T**:
- Don't rely on return codes only
- Don't run multiple tests in parallel (quota limits)
- Don't assume environment is clean
- Don't forget to source .env before running tests
