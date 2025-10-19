#!/usr/bin/env bash
#
# Backend Setup Script
#
# This script detects the cloud provider and configures the appropriate
# OpenTofu backend for state storage.
#
# Usage:
#   ./scripts/setup-backend.sh [--force] [--service-account SERVICE_ACCOUNT_EMAIL]
#
# Options:
#   --force                              Force recreation of backend configuration even if it exists
#   --service-account SERVICE_ACCOUNT_EMAIL  Grant state bucket permissions to specified service account
#
# Examples:
#   # Create backend and grant permissions to current user only
#   ./scripts/setup-backend.sh
#
#   # Create backend and grant permissions to service account
#   ./scripts/setup-backend.sh --service-account opentofu-deployer@project-id.iam.gserviceaccount.com
#
#   # Recreate backend config and grant permissions to service account
#   ./scripts/setup-backend.sh --force --service-account opentofu-deployer@project-id.iam.gserviceaccount.com
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_CONFIG_FILE="${REPO_ROOT}/backend-config.hcl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
FORCE=false
SERVICE_ACCOUNT=""

while [[ $# -gt 0 ]]; do
    case "${1}" in
        --force)
            FORCE=true
            shift
            ;;
        --service-account)
            SERVICE_ACCOUNT="${2:-}"
            if [[ -z "${SERVICE_ACCOUNT}" ]]; then
                log_error "--service-account requires an email argument"
                exit 1
            fi
            shift 2
            ;;
        *)
            log_error "Unknown option: ${1}"
            echo "Usage: ./scripts/setup-backend.sh [--force] [--service-account SERVICE_ACCOUNT_EMAIL]"
            exit 1
            ;;
    esac
done

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [[ ! -f "${REPO_ROOT}/.env" ]]; then
    log_error ".env file not found. Please create .env from .env.example"
    exit 1
fi

# Load environment variables
log_info "Loading environment variables from .env"
set -a
source "${REPO_ROOT}/.env"
set +a

# Validate required variables
if [[ -z "${TF_VAR_cloud_provider:-}" ]]; then
    log_error "TF_VAR_cloud_provider not set in .env"
    exit 1
fi

log_info "Cloud provider: ${TF_VAR_cloud_provider}"

# Check if backend config already exists
if [[ -f "${BACKEND_CONFIG_FILE}" ]] && [[ "${FORCE}" != "true" ]]; then
    log_warn "Backend configuration already exists at ${BACKEND_CONFIG_FILE}"
    log_warn "Use --force to recreate it"
    exit 0
fi

# Configure backend based on cloud provider
case "${TF_VAR_cloud_provider}" in
    gcp)
        log_info "Configuring GCS backend for Google Cloud Platform"

        # Validate GCP-specific variables
        if [[ -z "${TF_VAR_project_id:-}" ]]; then
            log_error "TF_VAR_project_id not set in .env"
            exit 1
        fi

        if [[ -z "${TF_VAR_region:-}" ]]; then
            log_error "TF_VAR_region not set in .env"
            exit 1
        fi

        if [[ -z "${TF_VAR_environment:-}" ]]; then
            log_error "TF_VAR_environment not set in .env"
            exit 1
        fi

        # Define bucket name
        STATE_BUCKET="${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"
        STATE_PREFIX="terraform/state/${TF_VAR_environment}"

        log_info "State bucket: ${STATE_BUCKET}"
        log_info "State prefix: ${STATE_PREFIX}"

        # Check if bucket exists
        log_info "Checking if GCS bucket exists..."
        if gsutil ls -b "gs://${STATE_BUCKET}" &>/dev/null; then
            log_info "Bucket ${STATE_BUCKET} already exists"
        else
            log_info "Creating GCS bucket: ${STATE_BUCKET}"

            # Create bucket with versioning enabled
            gsutil mb -p "${TF_VAR_project_id}" -l "${TF_VAR_region}" "gs://${STATE_BUCKET}"

            # Enable versioning for state file protection
            gsutil versioning set on "gs://${STATE_BUCKET}"

            # Set uniform bucket-level access
            gsutil uniformbucketlevelaccess set on "gs://${STATE_BUCKET}"

            log_info "Bucket created successfully with versioning enabled"
        fi

        # Grant IAM permissions to the current user
        CURRENT_USER=$(gcloud config get-value account 2>/dev/null)
        if [[ -n "${CURRENT_USER}" ]]; then
            log_info "Granting storage.objectAdmin role to current user: ${CURRENT_USER}"
            gsutil iam ch "user:${CURRENT_USER}:roles/storage.objectAdmin" "gs://${STATE_BUCKET}" || {
                log_warn "Failed to grant permissions to current user (may already exist)"
            }
        fi

        # Grant IAM permissions to service account if specified
        if [[ -n "${SERVICE_ACCOUNT}" ]]; then
            log_info "Granting storage.objectAdmin role to service account: ${SERVICE_ACCOUNT}"

            # Validate service account exists
            if gcloud iam service-accounts describe "${SERVICE_ACCOUNT}" --project="${TF_VAR_project_id}" &>/dev/null; then
                gsutil iam ch "serviceAccount:${SERVICE_ACCOUNT}:roles/storage.objectAdmin" "gs://${STATE_BUCKET}" || {
                    log_error "Failed to grant permissions to service account"
                    exit 1
                }
                log_info "Successfully granted permissions to service account"
            else
                log_error "Service account ${SERVICE_ACCOUNT} not found in project ${TF_VAR_project_id}"
                log_error "Create the service account first or check the email address"
                exit 1
            fi
        fi

        # Generate backend-config.hcl
        log_info "Generating backend configuration..."
        cat > "${BACKEND_CONFIG_FILE}" <<EOF
# Auto-generated GCS backend configuration
# Generated by: scripts/setup-backend.sh
# Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Cloud Provider: ${TF_VAR_cloud_provider}
# Environment: ${TF_VAR_environment}

bucket = "${STATE_BUCKET}"
prefix = "${STATE_PREFIX}"
EOF

        log_info "Backend configuration created at ${BACKEND_CONFIG_FILE}"
        ;;

    aws)
        log_error "AWS backend configuration not yet implemented"
        exit 1
        ;;

    azure)
        log_error "Azure backend configuration not yet implemented"
        exit 1
        ;;

    *)
        log_error "Unknown cloud provider: ${TF_VAR_cloud_provider}"
        log_error "Supported providers: gcp, aws, azure"
        exit 1
        ;;
esac

# Initialize OpenTofu with the backend
log_info "Initializing OpenTofu with backend configuration..."
cd "${REPO_ROOT}"

# Check if we need to migrate state
if [[ -f "terraform.tfstate" ]]; then
    log_warn "Local state file detected. Migration will be required."
    log_info "Running: tofu init -backend-config=${BACKEND_CONFIG_FILE} -migrate-state"
    tofu init -backend-config="${BACKEND_CONFIG_FILE}" -migrate-state

    # Backup local state after migration
    if [[ -f "terraform.tfstate" ]]; then
        BACKUP_FILE="terraform.tfstate.local.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up local state to ${BACKUP_FILE}"
        cp terraform.tfstate "${BACKUP_FILE}"
        log_info "You can safely delete terraform.tfstate and terraform.tfstate.backup after verifying remote state"
    fi
else
    log_info "Running: tofu init -backend-config=${BACKEND_CONFIG_FILE}"
    tofu init -backend-config="${BACKEND_CONFIG_FILE}"
fi

log_info "✅ Backend setup complete!"
log_info ""
log_info "Next steps:"
log_info "  1. Verify state backend: tofu state list"
log_info "  2. Deploy infrastructure: ./scripts/deploy.sh"
log_info ""
log_info "Backend details:"
case "${TF_VAR_cloud_provider}" in
    gcp)
        log_info "  Provider: Google Cloud Storage"
        log_info "  Bucket: ${STATE_BUCKET}"
        log_info "  Prefix: ${STATE_PREFIX}"
        log_info "  Versioning: Enabled"
        log_info ""
        log_info "Granted permissions to:"
        if [[ -n "${CURRENT_USER}" ]]; then
            log_info "  - User: ${CURRENT_USER}"
        fi
        if [[ -n "${SERVICE_ACCOUNT}" ]]; then
            log_info "  - Service Account: ${SERVICE_ACCOUNT}"
        fi
        log_info ""
        log_info "Verify permissions with:"
        log_info "  gsutil iam get gs://${STATE_BUCKET}"
        ;;
esac
