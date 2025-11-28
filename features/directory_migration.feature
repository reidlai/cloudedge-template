Feature: OpenTofu Directory Structure Refactoring
  As a DevOps Engineer
  I want to relocate OpenTofu configuration files to a cloud-provider-specific directory
  So that the repository root remains clean and infrastructure code is organized by provider

  Background:
    Given the repository is on branch "004-move-all-opentofu"
    And the repository root contains OpenTofu configuration files
    And a remote OpenTofu state exists in GCS backend
    And no other OpenTofu operations are in progress (state is unlocked)

  @smoke @integration
  Scenario: Successfully move OpenTofu files to new directory structure
    Given the following files exist in the repository root:
      | file                  |
      | main.tf               |
      | variables.tf          |
      | outputs.tf            |
      | backend.tf            |
      | backend-config.hcl    |
    And the "modules/" directory exists in the repository root
    And the ".terraform/" cache directory exists
    When I execute the directory migration process
    Then all ".terraform/" cache directories should be deleted
    And the file "main.tf" should exist at "deploy/opentofu/gcp/main.tf"
    And the file "variables.tf" should exist at "deploy/opentofu/gcp/variables.tf"
    And the file "outputs.tf" should exist at "deploy/opentofu/gcp/outputs.tf"
    And the file "backend.tf" should exist at "deploy/opentofu/gcp/backend.tf"
    And the file "backend-config.hcl" should exist at "deploy/opentofu/gcp/backend-config.hcl"
    And the directory "modules/" should exist at "deploy/opentofu/gcp/modules/"
    And no ".tf" files should remain in the repository root
    And the ".terraform.lock.hcl" file should exist at "deploy/opentofu/gcp/.terraform.lock.hcl"
    And the ".terraform.lock.hcl" file should still exist in the repository root

  @integration
  Scenario: Preserve module directory structure during relocation
    Given the "modules/" directory contains the following subdirectories:
      | provider |
      | gcp      |
      | aws      |
      | azure    |
    When I execute the directory migration process
    Then the directory "modules/gcp/" should exist at "deploy/opentofu/gcp/modules/gcp/"
    And the directory "modules/aws/" should exist at "deploy/opentofu/gcp/modules/aws/"
    And the directory "modules/azure/" should exist at "deploy/opentofu/gcp/modules/azure/"
    And all module files should be recursively moved to the new location
    And the "modules/" directory should not exist in the repository root

  @integration @state-migration
  Scenario: Successfully migrate OpenTofu state to new backend location
    Given the current OpenTofu state contains <resource_count> managed resources
    And a state backup is created with filename pattern "state-backup-*.tfstate"
    When I update the backend configuration key to "deploy/opentofu/gcp/terraform.tfstate"
    And I initialize the new backend in "deploy/opentofu/gcp/"
    And I push the backed-up state to the new backend location
    Then running "tofu state list" in "deploy/opentofu/gcp/" should return <resource_count> resources
    And the state lineage should match the original state lineage
    And running "tofu plan" in "deploy/opentofu/gcp/" should show zero changes
    And the GCS backend should contain state at key "deploy/opentofu/gcp/terraform.tfstate"

    Examples:
      | resource_count |
      | 10             |

  @integration
  Scenario: Module source paths remain valid after relocation
    Given the "main.tf" file contains module references with relative paths:
      """
      module "waf" {
        source = "./modules/gcp/waf"
      }
      module "cdn" {
        source = "./modules/gcp/cdn"
      }
      """
    When I execute the directory migration process
    And I run "tofu init" in "deploy/opentofu/gcp/"
    Then all modules should be successfully initialized
    And no module resolution errors should occur
    And running "tofu validate" should pass without errors

  @smoke
  Scenario: Verify OpenTofu validation succeeds after migration
    Given the directory migration process has completed
    When I run "tofu validate" in "deploy/opentofu/gcp/"
    Then the validation should pass with exit code 0
    And no syntax errors should be reported
    And all module dependencies should be resolved

  @integration
  Scenario: Provider version consistency is maintained after migration
    Given the root ".terraform.lock.hcl" file contains provider version constraints
    And the provider "registry.opentofu.org/hashicorp/google" is pinned to version "5.0.0"
    When I execute the directory migration process
    Then the file ".terraform.lock.hcl" should exist in "deploy/opentofu/gcp/"
    And the provider versions in "deploy/opentofu/gcp/.terraform.lock.hcl" should match the root lock file
    And running "tofu init" in "deploy/opentofu/gcp/" should not upgrade any providers

  @integration @rollback
  Scenario: Automatic rollback on state migration failure
    Given the directory migration process is in progress
    And a state backup exists with filename "state-backup-20251125120000.tfstate"
    And the original "backend.tf" is backed up as "backend.tf.backup-20251125120000"
    When the "tofu state push" command fails with exit code 1
    Then the migration script should detect the failure
    And the original "backend.tf" should be restored from "backend.tf.backup-20251125120000"
    And the backend should be re-initialized with the original configuration
    And the state should be verified as accessible at the original backend location
    And running "tofu state list" at the root should return the original resource count
    And the migration process should exit with a non-zero status code

  @integration @rollback
  Scenario: Rollback when state verification fails after migration
    Given the directory migration process has completed state push
    When running "tofu plan" in "deploy/opentofu/gcp/" shows unexpected changes
    Then the migration script should trigger automatic rollback
    And the backed-up state should be restored to the original backend location
    And the original "backend.tf" configuration should be restored
    And the system should return to the pre-migration state
    And an error message should be logged indicating verification failure

  @integration @edge-case
  Scenario: Handle missing .terraform cache directories gracefully
    Given the ".terraform/" directory does not exist in the repository root
    When I execute the directory migration process
    Then the cache cleanup step should complete without errors
    And the migration should proceed to the file move phase
    And running "tofu init" in "deploy/opentofu/gcp/" should succeed

  @integration @edge-case
  Scenario: Detect and prevent migration when state is locked
    Given another OpenTofu operation is holding a state lock
    When I attempt to execute the directory migration process
    Then the state pull operation should wait for lock release or timeout
    And if the lock is not released within the timeout period
    Then the migration should abort with an error message
    And no files should be moved
    And no backup files should remain in the repository

  @contract
  Scenario: Backend configuration key is correctly updated
    Given the original "backend.tf" file contains:
      """
      backend "gcs" {}
      """
    And the original "backend-config.hcl" file contains:
      """
      bucket = "vibetics-cloudedge-terraform-state"
      prefix = ""
      """
    When I execute the directory migration process
    Then the "backend-config.hcl" in "deploy/opentofu/gcp/" should contain:
      """
      bucket = "vibetics-cloudedge-terraform-state"
      prefix = "deploy/opentofu/gcp"
      """
    And the backend configuration should be syntactically valid

  @contract
  Scenario: State backup file is created with correct naming convention
    Given the current timestamp is "2025-11-25 12:30:45"
    When I execute the directory migration process
    Then a state backup file should be created with filename "state-backup-20251125123045.tfstate"
    And the backup file should contain valid OpenTofu state JSON
    And the backup file should have a "lineage" field
    And the backup file should have a "serial" field
    And the backup file should contain all managed resources from the original state

  @smoke @post-migration
  Scenario: Post-migration smoke test
    Given the directory migration process has completed successfully
    And I am in the "deploy/opentofu/gcp/" directory
    When I run the following OpenTofu commands:
      | command        |
      | tofu fmt -check -recursive |
      | tofu validate  |
      | tofu plan -detailed-exitcode |
    Then all commands should complete with exit code 0
    And no errors should be reported in the output

  @integration @compliance
  Scenario: Dot-files remain in repository root
    Given the repository root contains the following dot-files:
      | file              |
      | .checkov.yaml     |
      | .tflint.hcl       |
      | .gitignore        |
      | .terraform.lock.hcl |
    When I execute the directory migration process
    Then the file ".checkov.yaml" should still exist in the repository root
    And the file ".tflint.hcl" should still exist in the repository root
    And the file ".gitignore" should still exist in the repository root
    And the file ".terraform.lock.hcl" should still exist in the repository root
    And these files should NOT be moved to "deploy/opentofu/gcp/"

  @integration
  Scenario: Git history is preserved for moved files
    Given the "main.tf" file has 5 commits in its git history
    When I execute the directory migration process using "git mv"
    Then the file "deploy/opentofu/gcp/main.tf" should have 5 commits in its git history
  @integration @security
  Scenario: Verify CAS Pool exists and has correct tier
    Given the Private CA module is deployed
    When I inspect the "google_privateca_ca_pool" resource
    Then the pool tier should be "DEVOPS"
    And the pool location should match the region variable
    And the pool should have publishing options enabled for CA cert and CRL

  @integration @security
  Scenario: Verify Load Balancer uses managed certificate
    Given the Private CA module is enabled
    When I inspect the "google_compute_target_https_proxy" resource for the load balancer
    Then the "certificate_map" field should be set
    And the "ssl_certificates" field should be null or empty
    And the certificate map should reference the Private CA managed certificate

  @integration @security
  Scenario: Verify CAS Pool IAM bindings for cross-project access
    Given the "authorized_ca_users" variable contains external service accounts
    When I inspect the "google_privateca_ca_pool_iam_binding" resource
    Then the role "roles/privateca.certificateRequester" should be granted
    And the members list should contain the authorized service accounts
    And the binding should be attached to the created CA Pool
