Feature: Demo Web App Infrastructure (Independent VPC)
  As a DevOps Engineer
  I want to deploy a demo web app with its own VPC infrastructure
  So that the app runs securely without Shared VPC dependencies

  Background:
    Given the OpenTofu configuration is located at "deploy/opentofu/gcp/demo-web-app"
    And the project-singleton infrastructure is already deployed
    And NO Shared VPC resources are used
    And the web app has its own independent VPC when ALB or PSC is enabled

  @smoke @integration
  Scenario: Deploy demo web app with independent VPC
    Given I have valid GCP credentials
    And the project-singleton outputs are available via remote state
    When I run "tofu init" in the demo-web-app directory
    And I run "tofu apply -auto-approve" in the demo-web-app directory
    Then the apply should succeed with exit code 0
    And a Cloud Run service should be created
    And NO Shared VPC dependencies should exist

  @contract @vpc
  Scenario: Verify NO Shared VPC resources exist
    Given the demo web app infrastructure is deployed
    When I query all VPC resources
    Then there should be NO "google_compute_shared_vpc_host_project" resources
    And there should be NO "google_compute_shared_vpc_service_project" resources
    And the web VPC should be independently owned by the demo-web-app project

  @integration @vpc
  Scenario: Verify web VPC is created when internal ALB is enabled
    Given the demo web app infrastructure is deployed
    And the enable_demo_web_app variable is set to true
    And the enable_demo_web_app_internal_alb variable is set to true
    When I query VPC resources
    Then a web VPC named "demo-web-app-web-vpc" should exist
    And the web VPC should have "auto_create_subnetworks" set to false
    And a web subnet should exist with default CIDR "10.0.3.0/24"
    And a proxy-only subnet should exist with default CIDR "10.0.99.0/24"
    And the proxy-only subnet purpose should be "REGIONAL_MANAGED_PROXY"
    And the web subnet should have private Google access enabled

  @integration @vpc
  Scenario: Verify PSC NAT subnet is created when PSC is enabled
    Given the demo web app infrastructure is deployed
    And the enable_demo_web_app_psc_neg variable is set to true
    When I query VPC subnets
    Then a PSC NAT subnet should exist with default CIDR "10.0.100.0/24"
    And the PSC NAT subnet purpose should be "PRIVATE_SERVICE_CONNECT"

  @integration @vpc
  Scenario: Verify VPC is NOT created when both ALB and PSC are disabled
    Given the demo web app is configured
    And the enable_demo_web_app_internal_alb variable is set to false
    And the enable_demo_web_app_psc_neg variable is set to false
    When I run "tofu plan" in the demo-web-app directory
    Then NO web VPC should be planned for creation
    And NO subnets should be planned for creation

  @integration @cloud-run
  Scenario: Verify Cloud Run service is created with internal ingress
    Given the demo web app infrastructure is deployed
    And the enable_demo_web_app variable is set to true
    When I query Cloud Run services
    Then a Cloud Run service should exist named "demo-web-app" (or custom name)
    And the service ingress should be "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    And the service should use the configured container image
    And the service should listen on the configured port (default 3000)
    And deletion_protection should be false
    And scaling should be configured with min and max instances

  @integration @cloud-run
  Scenario: Verify Cloud Run IAM permissions for load balancer
    Given the demo web app infrastructure is deployed
    When I query Cloud Run IAM policies
    Then the "roles/run.invoker" role should be granted
    And the member should be the Compute Engine service agent
    And the member format should be "serviceAccount:service-<project-number>@compute-system.iam.gserviceaccount.com"

  @integration @neg
  Scenario: Verify Serverless NEG is created
    Given the demo web app infrastructure is deployed
    And the enable_demo_web_app variable is set to true
    When I query network endpoint groups
    Then a serverless NEG should exist
    And the NEG type should be "SERVERLESS" when PSC is disabled or same project
    Or the NEG type should be "PRIVATE_SERVICE_CONNECT" when PSC is enabled and cross-project
    And the NEG should reference the Cloud Run service

  @integration @backend
  Scenario: Verify backend service is created
    Given the demo web app infrastructure is deployed
    When I query backend services
    Then a regional backend service should exist
    And the backend service protocol should be "HTTPS"
    And the load balancing scheme should be "INTERNAL_MANAGED" when ALB or PSC is enabled
    Or the load balancing scheme should be "EXTERNAL_MANAGED" when ALB is disabled
    And the timeout should be 30 seconds
    And the backend should reference the serverless NEG

  @integration @internal-alb
  Scenario: Verify Internal ALB is created when enabled
    Given the demo web app infrastructure is deployed
    And the enable_demo_web_app_internal_alb variable is set to true
    When I query load balancer resources
    Then an internal ALB URL map should exist
    And an internal HTTPS proxy should exist
    And an internal forwarding rule should exist
    And the forwarding rule should use "INTERNAL_MANAGED" load balancing scheme
    And the forwarding rule should listen on port 443
    And the forwarding rule should be attached to the web VPC

  @integration @internal-alb
  Scenario: Verify Internal ALB is NOT created when disabled
    Given the demo web app is configured
    And the enable_demo_web_app_internal_alb variable is set to false
    And the enable_demo_web_app_psc_neg variable is set to false
    When I run "tofu plan" in the demo-web-app directory
    Then NO internal ALB resources should be planned for creation

  @integration @ssl
  Scenario: Verify self-signed certificate is created for Internal ALB
    Given the demo web app infrastructure is deployed
    And either enable_demo_web_app_internal_alb or enable_demo_web_app_psc_neg is true
    When I query SSL certificate resources
    Then a TLS private key should exist
    And a self-signed certificate should exist
    And the certificate common name should be "internal-alb.local"
    And the certificate validity should be 8760 hours (1 year)
    And the certificate should use RSA 2048
    And a regional SSL certificate binding should exist

  @integration @psc
  Scenario: Verify PSC Service Attachment is created when PSC is enabled
    Given the demo web app infrastructure is deployed
    And the enable_demo_web_app_psc_neg variable is set to true
    When I query PSC resources
    Then a PSC Service Attachment should exist
    And the service attachment should reference the internal ALB forwarding rule
    And the service attachment should use the PSC NAT subnet
    And the connection preference should be "ACCEPT_AUTOMATIC"
    And proxy protocol should be disabled

  @integration @psc
  Scenario: Verify PSC Service Attachment is NOT created when PSC is disabled
    Given the demo web app is configured
    And the enable_demo_web_app_psc_neg variable is set to false
    When I run "tofu plan" in the demo-web-app directory
    Then NO PSC Service Attachment should be planned for creation
    And NO PSC NAT subnet should be planned for creation

  @contract @variables
  Scenario: Validate required demo web app variables
    Given I have the OpenTofu configuration for demo-web-app
    When I inspect the variables.tf file
    Then the following variables should be defined:
      | variable                                  | type        | required |
      | project_suffix                            | string      | yes      |
      | region                                    | string      | yes      |
      | cloudedge_github_repository               | string      | yes      |
      | resource_tags                             | map(string) | no       |
      | cloudedge_project_id                      | string      | no       |
      | enable_demo_web_app                       | bool        | yes      |
      | demo_web_app_project_id                   | string      | no       |
      | demo_web_app_service_name                 | string      | no       |
      | demo_web_app_image                        | string      | no       |
      | enable_demo_web_app_self_signed_cert      | bool        | no       |
      | enable_demo_web_app_internal_alb          | bool        | no       |
      | enable_demo_web_app_psc_neg               | bool        | no       |
      | demo_web_app_web_vpc_name                 | string      | no       |
      | demo_web_app_web_subnet_cidr_range        | string      | no       |
      | demo_web_app_proxy_only_subnet_cidr_range | string      | no       |
      | demo_web_app_psc_nat_subnet_cidr_range    | string      | no       |
      | demo_web_app_port                         | number      | no       |
      | demo_web_app_min_concurrent_deployments   | number      | no       |
      | demo_web_app_max_concurrent_deployments   | number      | no       |

  @contract @variables
  Scenario: Verify NO Shared VPC variables exist
    Given I have the OpenTofu configuration for demo-web-app
    When I inspect the variables.tf file
    Then there should be NO variable named "host_project_id"
    And there should be NO variable named "shared_vpc_name"
    And there should be NO variable named "service_project_id"
    And there should be NO variable referencing Shared VPC

  @integration @remote-state
  Scenario: Verify remote state dependencies
    Given the demo web app infrastructure is deployed
    When I inspect the OpenTofu configuration
    Then the configuration should read remote state from "singleton"
    And the singleton state bucket should be "<cloudedge_project_id>-tfstate"
    And the singleton state prefix should be "<cloudedge_project_id>-singleton"

  @integration @data-sources
  Scenario: Verify data sources are properly configured
    Given the demo web app configuration
    When I inspect data sources
    Then the following data sources should be defined:
      | data_source                      |
      | terraform_remote_state.singleton |
      | google_project.current           |

  @integration @outputs
  Scenario: Verify demo web app outputs
    Given the demo web app infrastructure is deployed
    When I run "tofu output -json" in the demo-web-app directory
    Then the following outputs should be available:
      | output                                  |
      | web_app_service_name                    |
      | web_app_url                             |
      | web_vpc_id                              |
      | web_app_backend_service_id              |
      | web_app_psc_service_attachment_self_link|

  @smoke @integration
  Scenario: Access demo web app via public load balancer
    Given the baseline infrastructure is deployed
    And the core infrastructure is deployed
    And the demo web app infrastructure is deployed
    When a GET request is sent to the demo web app hostname via the external load balancer
    Then the response status code should be 200
    And the response should be from the Cloud Run service

  @security
  Scenario: Verify direct access to Cloud Run is blocked
    Given the Cloud Run service is deployed for the demo web app
    And the ingress policy is "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    When a user attempts to connect to the Cloud Run service's direct URL
    Then the connection should be refused with 403 Forbidden
    Or the connection should fail due to ingress policy

  @security @isolation
  Scenario: Verify network isolation without Shared VPC
    Given the demo web app infrastructure is deployed
    When I inspect network configurations
    Then the web VPC should be completely isolated from other VPCs
    And NO VPC peering should exist (unless explicitly configured)
    And NO Shared VPC attachments should exist
    And connectivity to core ingress VPC should only be via PSC or serverless NEG

  @smoke @teardown
  Scenario: Destroy demo web app infrastructure
    Given the demo web app infrastructure is deployed
    When I run "tofu destroy -auto-approve" in the demo-web-app directory
    Then the destroy should succeed with exit code 0
    And the Cloud Run service should be removed
    And the web VPC should be deleted if it was created
    And all PSC resources should be cleaned up
    And NO orphaned Shared VPC resources should remain
