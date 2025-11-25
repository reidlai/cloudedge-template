# Quick Start Guide

This guide provides detailed prerequisites, setup instructions, and troubleshooting steps for deploying Vibetics CloudEdge.

## Prerequisites

1. **Install OpenTofu**: Follow the official instructions at [https://opentofu.org/docs/intro/install/](https://opentofu.org/docs/intro/install/).
2. **Install Go**: Required for running Terratest. Follow instructions at [https://golang.org/doc/install](https://golang.org/doc/install).
3. **Install Poetry**: Required for Python dependency management (Checkov, Semgrep). Follow instructions at [https://python-poetry.org/docs/#installation](https://python-poetry.org/docs/#installation).

    ```bash
    # After installing Poetry, install project dependencies
    poetry install
    ```

4. **Install TFLint**: Required for linting OpenTofu/Terraform code. Follow instructions at [https://github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint).

    ```bash
    # macOS/Linux (using install script):
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

    # Or via Homebrew (macOS):
    brew install tflint

    # Or via Chocolatey (Windows):
    choco install tflint

    # Verify installation:
    tflint --version
    ```

5. **Configure Cloud Credentials**: For GCP, ensure your credentials are configured as environment variables (e.g., `GOOGLE_APPLICATION_CREDENTIALS`).
6. **Enable Required GCP APIs**: Before the first deployment to a new GCP project, you **MUST** manually enable the necessary APIs. This is a one-time setup step that cannot be automated in OpenTofu without circular dependencies.

    **Why manual enablement?** API enablement requires project-level permissions that create chicken-egg problems if managed in IaC. Additionally, disabling APIs during `tofu destroy` could accidentally delete resources not managed by this project.

    First, ensure your `.env` file is created and sourced, then run:

    ```bash
    source .env
    gcloud services enable \
      --project="$TF_VAR_project_id" \
      compute.googleapis.com \
      run.googleapis.com \
      cloudresourcemanager.googleapis.com
    ```

    **Required APIs**:
    - `compute.googleapis.com` - Compute Engine (VPCs, Load Balancers, Firewalls, SSL Certificates, Serverless NEG)
    - `run.googleapis.com` - Cloud Run (Serverless container platform for demo backend)
    - `cloudresourcemanager.googleapis.com` - Resource Manager (Project metadata and IAM)

    **Note**: VPC Access Connector API (`vpcaccess.googleapis.com`) is **NOT required** - Serverless NEG provides direct connectivity without VPC Connector.

    **Verification**: Confirm all APIs are enabled before running `tofu init`:

    ```bash
    gcloud services list --enabled --project="$TF_VAR_project_id" | grep -E 'compute|run|cloudresourcemanager'
    ```

    If any APIs are missing, you'll encounter errors during `tofu plan` or `tofu apply`.
7. **Grant Deployment IAM Roles (Project Owner/Admin Only)**: This is a **one-time bootstrap step** that must be performed by a GCP project owner or admin. If you are a developer without owner/admin access, skip to step 9 and ask your admin to complete steps 7-8.

    **Who should perform this step?**
    - ✅ GCP Project Owner
    - ✅ User with `roles/owner` OR both `roles/resourcemanager.projectIamAdmin` + `roles/iam.serviceAccountAdmin`
    - ❌ Regular developers (you'll get "Permission denied" errors)

    **Why manual IAM role assignment?** OpenTofu cannot grant itself the permissions it needs to run (chicken-and-egg problem). A privileged user must bootstrap the initial permissions. Additionally, managing IAM credentials or service account keys in code would violate security best practices.

    ---

    ### Choose Your Deployment Approach

    **Option A: Local Development with User Account** (Simpler, for testing/development)
    - ✅ Best for: Individual developers, quick testing, local development
    - ✅ Setup: Grant deployment roles directly to your user account
    - ❌ Not recommended for: Production, CI/CD pipelines, shared environments

    **Option B: Service Account** (Recommended for production/CI/CD)
    - ✅ Best for: CI/CD pipelines, automation, production deployments, team environments
    - ✅ Setup: Create dedicated service account with deployment roles
    - ✅ Security: Better auditability, key rotation, and access control

    ---

    ### Required Deployment IAM Roles

    The deployment account (user or service account) needs these roles to provision all infrastructure:

    | Role | Purpose | Resources Managed |
    |------|---------|-------------------|
    | `roles/run.admin` | Cloud Run administration | Create/update/delete Cloud Run services, configure ingress policies, manage IAM bindings |
    | `roles/compute.networkAdmin` | Network resource management | Create VPCs, subnets, firewall rules, load balancers, forwarding rules, backend services, NEGs |
    | `roles/compute.securityAdmin` | Security policy management | Create/manage Cloud Armor (WAF) security policies, SSL certificates |
    | `roles/compute.loadBalancerAdmin` | Load balancer configuration | Configure global external HTTPS load balancers, URL maps, target proxies, health checks |
    | `roles/iam.serviceAccountUser` | Service account impersonation | Allow Cloud Run services to use service accounts for authentication |

    ---

    ### Option A: Grant Roles to Your User Account

    **Prerequisites**: You must already have `roles/owner` or `roles/resourcemanager.projectIamAdmin` to run these commands.

    ```bash
    # Load environment variables from .env file
    source .env

    # Get your current account
    ACCOUNT=$(gcloud config get-value account)

    # Grant all required deployment roles
    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/compute.networkAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/compute.securityAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/compute.loadBalancerAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="user:$ACCOUNT" \
      --role="roles/iam.serviceAccountUser"
    ```

    **Verification**: Confirm IAM roles are assigned (may take 60-120 seconds to propagate):

    ```bash
    gcloud projects get-iam-policy $TF_VAR_project_id \
      --flatten="bindings[].members" \
      --filter="bindings.members:user:$ACCOUNT" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see all 5 deployment roles listed.

    **Next steps**:
    - ✅ If successful → Proceed to **Step 9** (Configure Application Default Credentials)
    - ❌ If you chose Option A → **Skip Step 8** (Service Account setup not needed)

    ---

    ### Option B: Setup via Service Account

    **Prerequisites**: You must already have `roles/owner` OR both `roles/resourcemanager.projectIamAdmin` + `roles/iam.serviceAccountAdmin`.

    **For full service account setup instructions, see Step 8 below.**

    **Next steps after completing Option B**:
    - ✅ Complete **Step 8** (Create Service Account for Deployment)
    - ✅ Then proceed to **Step 9** (Configure Application Default Credentials)

    ---

    **Troubleshooting**:
    - **Error: "Permission denied"** during role assignment → You need `roles/owner` or `roles/resourcemanager.projectIamAdmin`. Contact your GCP project owner.
    - **Error: "Error 403: Permission 'X' denied"** during deployment → The listed permission is missing; re-run the role assignment commands above
    - **Roles not showing in verification** → IAM changes can take up to 2 minutes to propagate; wait and re-run verification

    **Security Note**: These roles follow the **principle of least privilege** for infrastructure deployment. The `roles/editor` or `roles/owner` roles grant excessive permissions and should NOT be used for deployment accounts.
8. **Create Service Account for Deployment (CI/CD and Production)**: This section is for **Option B** from Step 7. If you chose **Option A** (user account), skip this step entirely and proceed to Step 9.

    **Who should perform this step?**
    - ✅ GCP Project Owner or Admin (same person who completed Step 7)
    - ❌ Regular developers without `roles/iam.serviceAccountAdmin`

    **Why use a service account?**
    - ✅ **CI/CD pipelines**: GitHub Actions, Jenkins, GitLab CI require non-interactive authentication
    - ✅ **Production deployments**: Better security boundaries and auditability
    - ✅ **Team environments**: Multiple developers can share the same service account credentials
    - ✅ **Key rotation**: Service account keys can be rotated without affecting user accounts

    ---

    ### Create the Service Account

    ```bash
    # Load environment variables
    source .env

    # Define service account name
    SERVICE_ACCOUNT_NAME="opentofu-deployer"
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${TF_VAR_project_id}.iam.gserviceaccount.com"

    # Create the service account
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
      --display-name="OpenTofu Deployment Service Account" \
      --description="Service account for automated OpenTofu infrastructure deployments" \
      --project=$TF_VAR_project_id
    ```

    **Verification**: Confirm service account was created:

    ```bash
    gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id \
      --format="value(email)"
    ```

    **Expected output**: `opentofu-deployer@your-project-id.iam.gserviceaccount.com`

    ---

    ### Grant Deployment Roles to Service Account

    ```bash
    # Grant all required deployment roles
    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/run.admin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/compute.networkAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/compute.securityAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/compute.loadBalancerAdmin"

    gcloud projects add-iam-policy-binding $TF_VAR_project_id \
      --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --role="roles/iam.serviceAccountUser"
    ```

    **Verification**: Confirm IAM roles are assigned (may take 60-120 seconds to propagate):

    ```bash
    gcloud projects get-iam-policy $TF_VAR_project_id \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see all 5 deployment roles listed.

    ---

    ### Create Service Account Key (For Local Development)

    **⚠️ Security Warning**: Service account keys are long-lived credentials. Use Workload Identity Federation for production CI/CD instead of keys when possible.

    ```bash
    # Create and download the key file
    gcloud iam service-accounts keys create ~/${TF_VAR_project_id}-opentofu-deployer-key.json \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id

    # Restrict key file permissions (critical for security)
    chmod 600 ~/${TF_VAR_project_id}-opentofu-deployer-key.json

    # Verify the key file was created
    ls -lh ~/${TF_VAR_project_id}-opentofu-deployer-key.json
    ```

    **Expected output**: A file with `-rw-------` permissions (only owner can read/write)

    ---

    ### Share Service Account Key with Team (If Needed)

    **For individual developers**:
    1. Admin shares the key file via secure channel (1Password, Google Secret Manager, etc.)
    2. Developer saves it to `~/${TF_VAR_project_id}-opentofu-deployer-key.json`
    3. Developer runs `chmod 600 ~/${TF_VAR_project_id}-opentofu-deployer-key.json`

    **For CI/CD pipelines**:
    1. Store the key content as a secret in your CI/CD system:
       - GitHub Actions: Repository Settings → Secrets → Actions → New repository secret
       - GitLab CI: Settings → CI/CD → Variables → Add Variable (Protected, Masked)
       - Jenkins: Manage Jenkins → Credentials → Add Credentials
    2. Secret name: `GCP_SA_KEY` or `GOOGLE_APPLICATION_CREDENTIALS`
    3. Secret value: Paste the entire JSON key file content

    **Security Best Practices**:
    - ✅ **Never commit key files to git**: Already in `.gitignore` as `*.json`
    - ✅ **Rotate keys every 90 days**: See rotation commands below
    - ✅ **Use Workload Identity Federation for CI/CD**: Eliminates need for long-lived keys (recommended for production)
    - ✅ **Audit key usage**: Monitor Cloud Logging for service account activity

    **Key Rotation** (every 90 days):

    ```bash
    # List existing keys
    gcloud iam service-accounts keys list \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id

    # Create new key
    gcloud iam service-accounts keys create ~/${TF_VAR_project_id}-opentofu-deployer-key-new.json \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id

    # Test new key works before deleting old one
    # ... test deployment with new key ...

    # Delete old key (replace KEY_ID with actual ID from list above)
    gcloud iam service-accounts keys delete KEY_ID \
      --iam-account=$SERVICE_ACCOUNT_EMAIL \
      --project=$TF_VAR_project_id
    ```

    ---

    **Troubleshooting**:
    - **Error: "Permission denied" when creating service account** → You need `roles/iam.serviceAccountAdmin`. Contact your GCP project owner.
    - **Error: "Permission denied" when creating key** → You need `roles/iam.serviceAccountKeyAdmin` or be the project owner
    - **Error: "Service account does not exist"** → Check project ID in `.env` is correct and matches where you created the service account
    - **Key file not found after creation** → Verify the path `~/${TF_VAR_project_id}-opentofu-deployer-key.json` is correct

    **Next steps**: Proceed to **Step 9** to configure Application Default Credentials using this service account.

9. **Configure Application Default Credentials (ADC)**: After granting IAM roles in steps 7-8, you **MUST** configure Application Default Credentials so that OpenTofu can authenticate and use your permissions. This is a **critical step** that is often missed.

    **Why is this required?** Google Cloud uses two separate credential systems:

    | Credential Type | Command | Used By | When to Configure |
    |-----------------|---------|---------|-----------------|
    | **User Credentials** | `gcloud auth login` | gcloud CLI commands | When switching Google accounts |
    | **Application Default Credentials (ADC)** | See methods below | OpenTofu, GCP client libraries, SDKs | **After granting IAM roles** |

    ---

    **⚠️ IMPORTANT: Choose the correct method based on what you did in Steps 7-8:**

    | What You Did | Use This Method |
    |------------------------|-----------------|
    | ✅ **Step 7 Option A**: Granted IAM roles to **your user account** | **Method A: User Account ADC** (below) |
    | ✅ **Step 8**: Created and granted IAM roles to a **service account** | **Method B: Service Account ADC** (below) |

    ---

    ### Method A: User Account ADC (For Local Development)

    **Use this method if you completed Step 7 Option A and granted IAM roles to your personal Google account.**

    **Step 1: Refresh ADC credentials**:

    ```bash
    gcloud auth application-default login
    ```

    This command will:
    1. Open your browser automatically
    2. Prompt you to sign in with your Google account (use the same account from step 6)
    3. Ask you to grant permissions to "Google Auth Library"
    4. Save the new credentials to `~/.config/gcloud/application_default_credentials.json`

    **Wait for the terminal to show**: `Credentials saved to file: [/home/user/.config/gcloud/application_default_credentials.json]`

    **Step 2: Verify ADC credentials are working**:

    ```bash
    # Check that a new access token is generated
    gcloud auth application-default print-access-token | cut -c1-50
    ```

    You should see an access token starting with `ya29.` (first 50 characters shown).

    **Common Errors if ADC is Not Refreshed**:
    - `Error: Error creating Network: googleapi: Error 403: Required 'compute.networks.create' permission`
    - `Error: Error creating FirewallRule: googleapi: Error 403: Insufficient Permission`
    - `Error: Error creating Address: googleapi: Error 403: Required 'compute.addresses.create' permission`

    If you see any 403 permission errors during `tofu apply` **even after granting IAM roles**, it means you forgot this step. Simply run `gcloud auth application-default login` and retry.

    **When to Refresh User Account ADC**:
    - ✅ **Required**: After granting new IAM roles to your user account (first-time setup)
    - ✅ **Required**: After switching to a different Google Cloud project
    - ✅ **Required**: If you see 403 permission errors during OpenTofu operations
    - ❌ **Not required**: When running regular `gcloud` commands (those use user credentials)

    ---

    ### Method B: Service Account ADC (For Automation/CI/CD)

    **Use this method if you completed Step 8 and created a service account with deployment IAM roles.**

    **⚠️ Note**: If you already created the service account key in **Step 8** (subsection "Create Service Account Key"), you can skip Step 1 below and proceed directly to Step 2.

    **Step 1: Load Environment and Set Service Account Email** (if not already set):

    ```bash
    # Load environment variables
    source .env

    # Set service account email
    SERVICE_ACCOUNT_NAME="opentofu-deployer"
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${TF_VAR_project_id}.iam.gserviceaccount.com"
    ```

    **Step 2: Configure ADC to Use the Service Account Key**:

    ```bash
    # Set the GOOGLE_APPLICATION_CREDENTIALS environment variable
    # Use the key file path from Step 8 (subsection "Create Service Account Key")
    export GOOGLE_APPLICATION_CREDENTIALS="$HOME/${TF_VAR_project_id}-opentofu-deployer-key.json"

    # Verify it's set
    echo $GOOGLE_APPLICATION_CREDENTIALS
    ```

    **Step 3: Make It Permanent** (add to shell profile):

    ```bash
    # Add to ~/.bashrc or ~/.zshrc (replace with your actual project ID)
    echo 'export GOOGLE_APPLICATION_CREDENTIALS="$HOME/your-project-id-opentofu-deployer-key.json"' >> ~/.bashrc
    source ~/.bashrc
    ```

    **Step 4: (Optional) Activate the service account for gcloud CLI commands**:

    ```bash
    # This allows gcloud commands to also use the service account
    gcloud auth activate-service-account $SERVICE_ACCOUNT_EMAIL \
      --key-file=$GOOGLE_APPLICATION_CREDENTIALS

    # Verify which account is active
    gcloud auth list
    ```

    **Step 5: Verify Service Account Authentication**:

    ```bash
    # Check that ADC is using the service account
    gcloud auth application-default print-access-token | head -c 50
    ```

    You should see an access token starting with `ya29.` (first 50 characters shown).

    **Security Best Practices**:

    Service account key security best practices are covered in **Step 8** (subsection "Share Service Account Key with Team"). Key reminders:
    - ✅ Never commit key files to git (already in `.gitignore`)
    - ✅ Restrict key file permissions: `chmod 600 ~/${TF_VAR_project_id}-opentofu-deployer-key.json`
    - ✅ Rotate keys every 90 days (see Step 8 subsection "Share Service Account Key with Team" for rotation commands)
    - ✅ Use Workload Identity Federation for production CI/CD instead of key files when possible

    **Troubleshooting Method B**:
    - **Error: "Permission denied" when creating key** → You need `roles/iam.serviceAccountKeyAdmin` on the service account or project
    - **Error: "403: Permission denied" during `tofu apply`** → Verify the service account has all required IAM roles (Step 8 subsection "Grant Deployment Roles to Service Account")
    - **Error: "Could not load the default credentials"** → Verify `GOOGLE_APPLICATION_CREDENTIALS` is set and points to a valid key file
    - **Error: "Key file not found"** → Check the path in `GOOGLE_APPLICATION_CREDENTIALS` is correct and file exists

    ---

    **When to Use Each Method**:

    | Scenario | Use Method | Why |
    |----------|------------|-----|
    | **Local development** (your laptop) | Method A (User Account) | Simpler, no key file management |
    | **CI/CD pipelines** (GitHub Actions, Jenkins) | Method B (Service Account) | Required for automation |
    | **Shared development server** | Method B (Service Account) | Avoid sharing personal credentials |
    | **Testing with specific permissions** | Method B (Service Account) | Service account has different IAM roles than your user |

10. **Configure Remote State Backend**: By default, OpenTofu stores state locally in a `terraform.tfstate` file. For production use and team collaboration, you should configure a remote backend to store state in Google Cloud Storage (GCS).

    **Why use remote state?**
    - ✅ **Team collaboration**: Multiple team members can work on the same infrastructure
    - ✅ **State locking**: Prevents concurrent modifications that could corrupt state
    - ✅ **Version history**: GCS bucket versioning provides state file history
    - ✅ **Security**: State files can contain sensitive data and should be stored securely
    - ✅ **Disaster recovery**: State is backed up in cloud storage, not local disk

    **Automated Backend Setup**:

    The `scripts/setup-backend.sh` script automates the entire backend configuration process:

    ```bash
    # Ensure .env is configured first (see step 3 below under Deployment)
    source .env
    ./scripts/setup-backend.sh
    ```

    This script will:
    1. Detect your cloud provider from `TF_VAR_cloud_provider` variable
    2. For GCP: Create a GCS bucket named `${TF_VAR_project_id}-${ENVIRONMENT}-tfstate`
    3. Enable versioning on the bucket for state history
    4. Generate a `backend-config.hcl` file with your bucket configuration
    5. Initialize OpenTofu with the remote backend
    6. Migrate local state to GCS if a local `terraform.tfstate` file exists
    7. Create a backup of your local state file after successful migration

    **Backend Configuration Details** (GCP):
    - **Bucket name pattern**: `<project-id>-<environment>-tfstate`
    - **State path pattern**: `terraform/state/<environment>/default.tfstate`
    - **Versioning**: Enabled (protects against accidental deletion/corruption)
    - **Access**: Uniform bucket-level access (modern IAM-based access control)

    **Manual Backend Setup** (if you prefer):

    If you want to manually configure the backend:

    ```bash
    # 1. Create GCS bucket
    source .env
    BUCKET_NAME="${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"
    gsutil mb -p "${TF_VAR_project_id}" -l "${TF_VAR_region}" "gs://${BUCKET_NAME}"
    gsutil versioning set on "gs://${BUCKET_NAME}"

    # 2. Create backend-config.hcl
    cat > backend-config.hcl <<EOF
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state/${TF_VAR_environment}"
    EOF

    # 3. Initialize with backend
    tofu init -backend-config=backend-config.hcl -migrate-state
    ```

    **Verification**: After backend setup, verify state is stored remotely:

    ```bash
    # Check bucket exists
    gsutil ls -b "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"

    # List state files
    gsutil ls "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate/terraform/state/"
    ```

    **When to Skip Backend Setup**:
    - ❌ **Skip for**: Quick local testing or experiments
    - ❌ **Skip for**: Single-user development without state sharing needs
    - ✅ **Required for**: Production deployments
    - ✅ **Required for**: Team collaboration
    - ✅ **Required for**: CI/CD pipelines

    **Troubleshooting**:
    - **Error: "Backend initialization required"** → Run `./scripts/setup-backend.sh`
    - **Error: "bucket does not exist"** → The script will create it automatically
    - **Error: "Permission denied" when creating bucket** → Verify you have `roles/storage.admin` or `roles/owner`

11. **Grant Service Account Access to State Bucket** (Required if using service account from Step 8):

    If you created a service account in **Step 8** for OpenTofu deployments, you **MUST** grant it permissions to read and write to the Terraform state bucket. The `setup-backend.sh` script only grants permissions to your current user account by default.

    **Why is this required?** The service account needs to:
    - Read the current state file before making changes
    - Write updated state files after applying infrastructure changes
    - Create and manage state lock files to prevent concurrent modifications

    **Grant state bucket permissions**:

    ```bash
    # Ensure .env is loaded
    source .env

    # Grant storage.objectAdmin role (read/write access to state files)
    gcloud storage buckets add-iam-policy-binding "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate" \
      --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
      --role="roles/storage.objectAdmin"
    ```

    **Verification**: Confirm the service account has the correct permissions:

    ```bash
    # View all IAM policies on the bucket
    gcloud storage buckets get-iam-policy "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"

    # Or filter for just the service account
    gcloud storage buckets get-iam-policy "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate" \
      --flatten="bindings[].members" \
      --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
      --format="table(bindings.role)"
    ```

    **Expected output**: You should see the service account listed with `roles/storage.objectAdmin` role.

    **Alternative using gsutil** (if you prefer the legacy command):

    ```bash
    # Ensure .env is loaded and set bucket name
    source .env

    # Grant permissions using gsutil
    gsutil iam ch "serviceAccount:${SERVICE_ACCOUNT_EMAIL}:roles/storage.objectAdmin" \
      "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate"

    # Verify permissions
    gsutil iam get "gs://${TF_VAR_project_id}-${TF_VAR_environment}-tfstate" | grep -A 2 "${SERVICE_ACCOUNT_EMAIL}"
    ```

    **Troubleshooting**:
    - **Error: "CommandException: 'IAM' command does not support provider-only URLs"** → The bucket name variable is not set. Ensure you've run `source .env` first
    - **Error: "Permission denied" when granting IAM** → You need `roles/storage.admin` or `roles/owner` to modify bucket IAM policies
    - **Error: "ServiceAccount not found"** → Verify the service account was created in **Step 8** using `gcloud iam service-accounts list`
    - **Error: "403 Permission denied" during `tofu apply` with service account** → The service account lacks state bucket permissions; re-run the command above
    - **Error: "BucketNotFoundException"** → The state bucket doesn't exist yet. Run `./scripts/setup-backend.sh` first

    **Security Note**: The `roles/storage.objectAdmin` role is the recommended permission level for OpenTofu state management. It follows the principle of least privilege while providing all necessary permissions for state file operations (create, read, update, delete objects).

## Deployment

1. **Clone the repository**:

    ```bash
    git clone <repository-url>
    cd vibetics-cloudedge
    ```

2. **Set Environment Variables**: Create a `.env` file in the root of the project from the example template.

    ```bash
    cp .env.example .env
    ```

    Edit `.env` and configure your GCP project settings:

    ```bash
    TF_VAR_cloud_provider="gcp"
    TF_VAR_project_id="your-gcp-project-id"
    TF_VAR_region="northamerica-northeast2"
    TF_VAR_environment="nonprod"
    TF_VAR_billing_account="your-billing-account-id"
    ```

    **IMPORTANT**: The `.env` file is already in `.gitignore` to prevent committing secrets.

3. **Configure Remote State Backend** (RECOMMENDED):

    ```bash
    source .env
    ./scripts/setup-backend.sh
    ```

    This will:
    - Create a GCS bucket for state storage with versioning enabled
    - Generate backend configuration
    - Initialize OpenTofu with remote backend
    - Migrate any existing local state to GCS

    **Skip this step** for quick local testing. For production and team collaboration, remote state is required.

4. **Deploy the infrastructure**:

    ```bash
    source .env
    ./scripts/deploy.sh
    ```

    **Note**: If you ran `setup-backend.sh` in step 3, OpenTofu is already initialized. Otherwise, `deploy.sh` will run `tofu init` automatically.

## Teardown

To destroy all infrastructure managed by this deployment, run the following command:

```bash
./scripts/teardown.sh
```
