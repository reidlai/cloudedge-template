#
# Backend Configuration for OpenTofu State Management
#
# This file configures the backend for storing OpenTofu state.
# Backend configuration is provided via scripts/setup-backend.sh which
# detects the cloud_provider and generates the appropriate backend-config.hcl file.
#
# Usage:
#   1. Set cloud_provider in .env (e.g., TF_VAR_cloud_provider=gcp)
#   2. Run: ./scripts/setup-backend.sh
#   3. The script will initialize the backend automatically
#

terraform {
  required_version = ">= 1.6.0"

  # GCS Backend for Google Cloud Platform
  # Configuration values are provided via backend-config.hcl (auto-generated)
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0.0"
    }
  }
}
