#!/bin/bash
# This script tears down the infrastructure deployed by OpenTofu.

set -e

echo "Tearing down infrastructure..."
tofu destroy -auto-approve
echo "Teardown complete."