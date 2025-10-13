#!/bin/bash
# This script runs 'tofu apply' and automatically tears down the infrastructure on failure.

set -e

echo "Starting deployment..."

# The '||' operator ensures that the teardown script is only called if 'tofu apply' fails (exits with a non-zero status)
tofu apply -auto-approve || ./scripts/teardown.sh

echo "Deployment successful."
