#!/bin/bash
#
# Verification Script: Test I1 and I2 Fixes
#
# This script verifies that the critical fixes for VPC peering removal (I1)
# and logging bucket lifecycle errors (I2) have been successfully applied.
#
# Usage: ./scripts/verify-deployment-fixes.sh
#
# Prerequisites:
# - GCP project configured with required APIs enabled
# - TF_VAR_project_id and TF_VAR_region environment variables set
# - OpenTofu installed and configured

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Deployment Fixes Verification"
echo "=========================================="
echo ""

# Check required environment variables
if [[ -z "${TF_VAR_project_id}" ]]; then
  echo -e "${RED}ERROR: TF_VAR_project_id environment variable not set${NC}"
  echo "Run: export TF_VAR_project_id=your-gcp-project-id"
  exit 1
fi

if [[ -z "${TF_VAR_region}" ]]; then
  echo -e "${YELLOW}WARNING: TF_VAR_region not set, using default: northamerica-northeast2${NC}"
  export TF_VAR_region="northamerica-northeast2"
fi

PROJECT_ID="${TF_VAR_project_id}"
REGION="${TF_VAR_region}"

echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# Verification Phase 1: Check Fix I1 - VPC Peering Removal
echo "=========================================="
echo "Phase 1: Verifying Fix I1 (VPC Peering Removal)"
echo "=========================================="
echo ""

echo "[1.1] Checking inter_vpc_peering module directory removed..."
if [[ -d "${REPO_ROOT}/modules/gcp/inter_vpc_peering" ]]; then
  echo -e "${RED}❌ FAIL: inter_vpc_peering module directory still exists${NC}"
  exit 1
else
  echo -e "${GREEN}✓ PASS: inter_vpc_peering module directory removed${NC}"
fi

echo "[1.2] Checking main.tf for peering module references..."
if grep -q "module \"inter_vpc_peering\"" "${REPO_ROOT}/main.tf"; then
  echo -e "${RED}❌ FAIL: main.tf still references inter_vpc_peering module${NC}"
  exit 1
else
  echo -e "${GREEN}✓ PASS: main.tf does not reference inter_vpc_peering module${NC}"
fi

echo "[1.3] Checking variables.tf for enable_inter_vpc_peering..."
if grep -q "variable \"enable_inter_vpc_peering\"" "${REPO_ROOT}/variables.tf"; then
  echo -e "${RED}❌ FAIL: variables.tf still defines enable_inter_vpc_peering${NC}"
  exit 1
else
  echo -e "${GREEN}✓ PASS: enable_inter_vpc_peering variable removed${NC}"
fi

echo "[1.4] Checking test files for peering references..."
if grep -q "\"enable_inter_vpc_peering\": true" "${REPO_ROOT}/tests/integration/gcp/full_baseline_test.go"; then
  echo -e "${RED}❌ FAIL: full_baseline_test.go still enables peering${NC}"
  exit 1
else
  echo -e "${GREEN}✓ PASS: Test files do not enable VPC peering${NC}"
fi

echo ""
echo -e "${GREEN}✓ Fix I1 verification complete - VPC peering successfully removed${NC}"
echo ""

# Verification Phase 2: Check Fix I2 - Logging Bucket Lifecycle
echo "=========================================="
echo "Phase 2: Verifying Fix I2 (Logging Bucket Lifecycle)"
echo "=========================================="
echo ""

echo "[2.1] Checking logging bucket lifecycle block in demo_backend..."
if grep -q "ignore_changes = \[lifecycle_state\]" "${REPO_ROOT}/modules/gcp/demo_backend/main.tf"; then
  echo -e "${GREEN}✓ PASS: Logging bucket has lifecycle ignore_changes block${NC}"
else
  echo -e "${RED}❌ FAIL: Logging bucket missing lifecycle ignore_changes block${NC}"
  exit 1
fi

echo "[2.2] Checking teardown.sh for bucket state handling..."
if grep -q "wait_for_bucket_active" "${REPO_ROOT}/scripts/teardown.sh"; then
  echo -e "${GREEN}✓ PASS: Teardown script has bucket state waiting logic${NC}"
else
  echo -e "${RED}❌ FAIL: Teardown script missing bucket state handling${NC}"
  exit 1
fi

echo "[2.3] Checking teardown.sh for retry logic..."
if grep -q "max_destroy_attempts" "${REPO_ROOT}/scripts/teardown.sh"; then
  echo -e "${GREEN}✓ PASS: Teardown script has retry logic${NC}"
else
  echo -e "${RED}❌ FAIL: Teardown script missing retry logic${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ Fix I2 verification complete - Logging bucket lifecycle fixed${NC}"
echo ""

# Verification Phase 3: OpenTofu Plan Check
echo "=========================================="
echo "Phase 3: OpenTofu Plan Validation"
echo "=========================================="
echo ""

cd "${REPO_ROOT}"

echo "[3.1] Running OpenTofu init..."
if tofu init -upgrade > /dev/null 2>&1; then
  echo -e "${GREEN}✓ PASS: OpenTofu init successful${NC}"
else
  echo -e "${RED}❌ FAIL: OpenTofu init failed${NC}"
  exit 1
fi

echo "[3.2] Running OpenTofu validate..."
if tofu validate > /dev/null 2>&1; then
  echo -e "${GREEN}✓ PASS: OpenTofu configuration valid${NC}"
else
  echo -e "${RED}❌ FAIL: OpenTofu validation failed${NC}"
  tofu validate
  exit 1
fi

echo "[3.3] Generating OpenTofu plan..."
PLAN_OUTPUT=$(tofu plan -detailed-exitcode -var="project_id=${PROJECT_ID}" -var="region=${REGION}" 2>&1 || true)

echo "[3.4] Checking plan for VPC peering resources..."
if echo "${PLAN_OUTPUT}" | grep -q "google_compute_network_peering"; then
  echo -e "${RED}❌ FAIL: Plan still contains VPC peering resources${NC}"
  echo "Found in plan:"
  echo "${PLAN_OUTPUT}" | grep "google_compute_network_peering"
  exit 1
else
  echo -e "${GREEN}✓ PASS: Plan does not contain VPC peering resources${NC}"
fi

echo "[3.5] Checking plan for logging bucket configuration..."
if echo "${PLAN_OUTPUT}" | grep -q "google_logging_project_bucket_config"; then
  echo -e "${GREEN}✓ PASS: Plan contains logging bucket configuration${NC}"
else
  echo -e "${YELLOW}⚠ WARNING: Logging bucket not in plan (may not be enabled)${NC}"
fi

echo ""
echo -e "${GREEN}✓ OpenTofu plan validation complete${NC}"
echo ""

# Summary
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ All critical fixes verified successfully:${NC}"
echo ""
echo "  I1 - VPC Peering Removal:"
echo "    • Module directory deleted"
echo "    • main.tf references removed"
echo "    • Variable definitions removed"
echo "    • Test configurations updated"
echo ""
echo "  I2 - Logging Bucket Lifecycle:"
echo "    • Lifecycle ignore_changes added"
echo "    • Teardown script has wait logic"
echo "    • Retry mechanism implemented"
echo ""
echo "  OpenTofu Configuration:"
echo "    • Init successful"
echo "    • Validation passed"
echo "    • No VPC peering in plan"
echo ""
echo -e "${GREEN}=========================================="
echo "✓ READY FOR DEPLOYMENT"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/deploy.sh"
echo "  2. Test load balancer access"
echo "  3. Run: ./scripts/teardown.sh"
echo ""
