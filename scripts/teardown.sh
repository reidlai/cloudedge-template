#!/bin/bash
#
# This script tears down the infrastructure deployed by OpenTofu.
#
# Usage:
#   source .env && ./scripts/teardown.sh
#
# Fix I2: Handle logging bucket deletion errors gracefully
# Buckets in DELETE_REQUESTED state are already being asynchronously deleted by GCP.
# We skip waiting for these buckets and proceed directly with tofu destroy.
#
set -e

# Validate required environment variables
if [ -z "$TF_VAR_project_id" ]; then
  echo "ERROR: TF_VAR_project_id is not set"
  echo "Please run: source .env"
  echo "Or manually export: export TF_VAR_project_id=your-project-id"
  exit 1
fi

if [ -z "$TF_VAR_environment" ]; then
  echo "WARNING: TF_VAR_environment not set, defaulting to 'nonprod'"
  export TF_VAR_environment="nonprod"
fi

if [ -z "$TF_VAR_region" ]; then
  echo "WARNING: TF_VAR_region not set, defaulting to 'northamerica-northeast2'"
  export TF_VAR_region="northamerica-northeast2"
fi

echo "Starting teardown..."
echo "  Project ID: $TF_VAR_project_id"
echo "  Environment: $TF_VAR_environment"
echo "  Region: $TF_VAR_region"

# Function to wait for logging buckets to be in a safe state for teardown
wait_for_bucket_safe_state() {
  local bucket_id="$1"
  local max_attempts=30
  local attempt=1
  local wait_time=5

  echo "Checking bucket ${bucket_id} state..."
  while [ $attempt -le $max_attempts ]; do
    state=$(gcloud logging buckets describe "${bucket_id}" \
      --location=global \
      --format="value(lifecycleState)" 2>/dev/null || echo "NOT_FOUND")

    # ACTIVE, NOT_FOUND, and DELETE_REQUESTED are all safe states to proceed
    # DELETE_REQUESTED means GCP is already deleting the bucket asynchronously
    if [ "$state" = "ACTIVE" ] || [ "$state" = "NOT_FOUND" ] || [ "$state" = "DELETE_REQUESTED" ]; then
      echo "Bucket ${bucket_id} is in ${state} state, proceeding with teardown"
      return 0
    fi

    echo "Bucket ${bucket_id} is in ${state} state, waiting ${wait_time}s (attempt ${attempt}/${max_attempts})..."
    sleep $wait_time
    attempt=$((attempt + 1))

    # Capped exponential backoff - max 60s to prevent infinite waits
    wait_time=$((wait_time * 2))
    if [ $wait_time -gt 60 ]; then
      wait_time=60
    fi
  done

  echo "WARNING: Bucket ${bucket_id} did not reach a safe state after ${max_attempts} attempts"
  return 1
}

# Check for logging bucket and wait if needed
# NOTE: Bucket only exists if enable_logging_bucket=true (default)
# Set enable_logging_bucket=false for fast testing iterations
BUCKET_ID="${TF_VAR_environment:-nonprod}-demo-backend-logs"
if gcloud logging buckets describe "${BUCKET_ID}" --location=global &>/dev/null 2>&1; then
  echo "Found logging bucket ${BUCKET_ID}, checking state..."
  wait_for_bucket_safe_state "${BUCKET_ID}" || true
else
  echo "No logging bucket found (may be disabled via enable_logging_bucket=false), skipping bucket state check"
fi

# Run OpenTofu destroy with retry logic
max_destroy_attempts=2
destroy_attempt=1

while [ $destroy_attempt -le $max_destroy_attempts ]; do
  echo "Running tofu destroy (attempt ${destroy_attempt}/${max_destroy_attempts})..."

  if tofu destroy -auto-approve; then
    echo "Teardown complete."
    exit 0
  else
    echo "Destroy attempt ${destroy_attempt} failed"

    if [ $destroy_attempt -lt $max_destroy_attempts ]; then
      echo "Retrying after 10 seconds..."
      sleep 10
    fi

    destroy_attempt=$((destroy_attempt + 1))
  fi
done

echo "ERROR: Teardown failed after ${max_destroy_attempts} attempts"
echo "You may need to manually clean up remaining resources"
exit 1
