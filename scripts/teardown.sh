#!/bin/bash
#
# This script tears down the infrastructure deployed by OpenTofu.
#
set -e

echo "Starting teardown..."
tofu destroy -auto-approve
echo "Teardown complete."
