Feature: Project Singleton Infrastructure
  As a DevOps Engineer
  I want to deploy project-wide singleton resources
  So that shared infrastructure components are available for all modules

  Background:
    Given the OpenTofu configuration is located at "deploy/opentofu/gcp/project-singleton"
    And the project ID follows the pattern "<cloudedge_github_repository>-<project_suffix>"
    And the project suffix is either "nonprod" or "prod"

  @smoke @integration
  Scenario: Deploy project singleton infrastructure
    Given I have valid GCP credentials
    And the billing account is configured
    And I have set the project_suffix variable to "nonprod"
    When I run "tofu init" in the project-singleton directory
    And I run "tofu apply -auto-approve" in the project-singleton directory
    Then the apply should succeed with exit code 0
    And the project should be created or configured
    And GCP APIs should be enabled

  @integration
  Scenario: Verify required GCP APIs are enabled
    Given the project singleton infrastructure is deployed
    When I query enabled GCP APIs for the project
    Then the following APIs should be enabled:
      | api                           |
      | billingbudgets.googleapis.com |
      | cloudbilling.googleapis.com   |
      | compute.googleapis.com        |
      | logging.googleapis.com        |

  @integration @billing
  Scenario: Verify billing budget is configured
    Given the project singleton infrastructure is deployed
    And the budget_amount variable is set to 1000 HKD
    When I query the billing budget for the project
    Then a billing budget should exist
    And the budget amount should be 1000 HKD
    And budget alerts should be configured at 50%, 80%, and 100%
    And alerts should be sent to billing admins

  @integration @logging
  Scenario: Verify centralized logging is configured when enabled
    Given the project singleton infrastructure is deployed
    And the enable_logging variable is set to true
    When I query the logging configuration
    Then a centralized logging bucket should exist
    And the bucket location should be "global"
    And the retention period should be 30 days
    And the bucket ID should be "_Default"

  @integration @logging
  Scenario: Verify logging is not created when disabled
    Given the project singleton infrastructure is deployed
    And the enable_logging variable is set to false
    When I query the logging configuration
    Then no custom logging bucket should be created
    And the output "logs_bucket_id" should be null

  @integration @ssl
  Scenario: Verify self-signed SSL certificate is created for testing
    Given the project singleton infrastructure is deployed
    And the enable_self_signed_cert variable is set to true
    When I query the SSL certificate resources
    Then a TLS private key should be created
    And a self-signed certificate should be created
    And the certificate validity should be 365 days
    And the certificate algorithm should be RSA 2048
    And a regional SSL certificate binding should exist

  @integration @ssl
  Scenario: Verify Google-managed certificate configuration for production
    Given the project singleton infrastructure is deployed
    And the enable_self_signed_cert variable is set to false
    When I query the SSL certificate resources
    Then a Google-managed SSL certificate should be configured
    And the certificate should have auto-renewal enabled

  @integration @remote-state
  Scenario: Verify remote state is properly configured
    Given the project singleton infrastructure is deployed
    When I query the remote state backend
    Then the backend type should be "gcs"
    And the bucket should be "<project_id>-tfstate"
    And the prefix should be "<project_id>-singleton"

  @integration @outputs
  Scenario: Verify singleton outputs are available
    Given the project singleton infrastructure is deployed
    When I run "tofu output -json" in the project-singleton directory
    Then the following outputs should be available:
      | output                      |
      | project_suffix              |
      | project_id                  |
      | billing_budget_id           |
      | enable_logging              |
      | external_https_lb_cert_id   |

  @contract
  Scenario: Validate project_suffix variable constraint
    Given I have the OpenTofu configuration for project-singleton
    When I set the project_suffix variable to "<invalid_value>"
    And I run "tofu validate"
    Then the validation should fail
    And the error message should indicate "project_suffix must be 'nonprod' or 'prod'"

    Examples:
      | invalid_value |
      | development   |
      | staging       |
      | production    |
      | test          |

  @contract
  Scenario: Validate required variables are defined
    Given I have the OpenTofu configuration for project-singleton
    When I inspect the variables.tf file
    Then the following variables should be defined:
      | variable                  | type   | required |
      | project_suffix            | string | yes      |
      | region                    | string | yes      |
      | cloudedge_github_repository | string | yes      |
      | resource_tags             | map    | no       |
      | budget_amount             | number | no       |
      | enable_logging            | bool   | no       |
      | enable_self_signed_cert   | bool   | no       |

  @integration @tagging
  Scenario: Verify resource tagging compliance
    Given the project singleton infrastructure is deployed
    And the resource_tags variable contains required keys
    When I inspect deployed resources
    Then all resources should have the following tags:
      | tag_key        | tag_value  |
      | managed-by     | opentofu   |
      | project-suffix | <project_suffix> |

  @smoke @teardown
  Scenario: Destroy project singleton infrastructure
    Given the project singleton infrastructure is deployed
    When I run "tofu destroy -auto-approve" in the project-singleton directory
    Then the destroy should succeed with exit code 0
    And all singleton resources should be removed
    But the GCS state bucket should remain for audit purposes
