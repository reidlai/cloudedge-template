Feature: Core Edge Infrastructure (No Shared VPC)
  As a DevOps Engineer
  I want to deploy core edge infrastructure with direct VPC ownership
  So that I have a secure, public-facing load balancer without Shared VPC complexity

  Background:
    Given the OpenTofu configuration is located at "deploy/opentofu/gcp/core"
    And the project-singleton infrastructure is already deployed
    And NO Shared VPC resources exist
    And the ingress VPC is owned directly by the core project

  @smoke @integration
  Scenario: Deploy core infrastructure with direct VPC ownership
    Given I have valid GCP credentials
    And the project-singleton outputs are available via remote state
    When I run "tofu init" in the core directory
    And I run "tofu apply -auto-approve" in the core directory
    Then the apply should succeed with exit code 0
    And the ingress VPC should be created in the core project
    And NO Shared VPC host project should exist
    And NO Shared VPC service project attachments should exist

  @contract @vpc
  Scenario: Verify Shared VPC resources are NOT created
    Given the core infrastructure is deployed
    When I query all VPC resources in the project
    Then there should be NO "google_compute_shared_vpc_host_project" resources
    And there should be NO "google_compute_shared_vpc_service_project" resources
    And the ingress VPC should have "auto_create_subnetworks" set to false

  @integration @vpc
  Scenario: Verify ingress VPC and subnets are created
    Given the core infrastructure is deployed
    When I query VPC resources
    Then an ingress VPC named "ingress-vpc" should exist
    And an ingress subnet should exist with CIDR "10.0.1.0/24"
    And a proxy-only subnet should exist with CIDR "10.0.98.0/24"
    And the proxy-only subnet purpose should be "REGIONAL_MANAGED_PROXY"
    And the proxy-only subnet role should be "ACTIVE"
    And the ingress subnet should have private Google access enabled

  @integration @load-balancer
  Scenario: Verify Regional External HTTPS Load Balancer is created
    Given the core infrastructure is deployed
    When I query load balancer resources
    Then a regional external IP address should exist
    And the IP address type should be "EXTERNAL"
    And the network tier should be "STANDARD"
    And a regional URL map should exist named "external-https-lb"
    And a regional HTTPS proxy should exist
    And a forwarding rule should exist on port 443
    And the forwarding rule should use "EXTERNAL_MANAGED" load balancing scheme

  @integration @cloudflare
  Scenario: Verify Cloudflare integration when proxy is enabled
    Given the core infrastructure is deployed
    And the enable_cloudflare_proxy variable is set to true
    When I query Cloudflare resources
    Then a Cloudflare DNS A record should exist for the subdomain
    And the DNS record should be proxied (orange cloud enabled)
    And the DNS record TTL should be 1 (automatic)
    And a Cloudflare Origin CA certificate should be created
    And the origin certificate validity should be 5475 days (15 years)
    And the origin certificate should use RSA 2048 encryption
    And a regional SSL certificate should bind the Cloudflare origin cert

  @integration @cloudflare
  Scenario: Verify firewall restricts to Cloudflare IPs when proxy is enabled
    Given the core infrastructure is deployed
    And the enable_cloudflare_proxy variable is set to true
    When I query firewall rules
    Then a firewall rule should exist allowing HTTPS (port 443)
    And the source ranges should be restricted to Cloudflare IPv4 ranges only
    And the Cloudflare IP ranges should include:
      | cidr_range        |
      | 173.245.48.0/20   |
      | 103.21.244.0/22   |
      | 141.101.64.0/18   |
      | 108.162.192.0/18  |
      | 190.93.240.0/20   |
      | 188.114.96.0/20   |
      | 198.41.128.0/17   |
      | 162.158.0.0/15    |
      | 104.16.0.0/13     |
      | 104.24.0.0/14     |
      | 172.64.0.0/13     |

  @integration @firewall
  Scenario: Verify firewall uses custom ranges when Cloudflare proxy is disabled
    Given the core infrastructure is deployed
    And the enable_cloudflare_proxy variable is set to false
    And the allowed_https_source_ranges variable is set to custom ranges
    When I query firewall rules
    Then a firewall rule should exist allowing HTTPS (port 443)
    And the source ranges should match the allowed_https_source_ranges variable
    And the firewall should NOT be restricted to Cloudflare IPs

  @integration @waf
  Scenario: Verify GCP Cloud Armor WAF is created when enabled
    Given the core infrastructure is deployed
    And the enable_waf variable is set to true
    When I query security policies
    Then a regional security policy named "edge-waf-policy" should exist
    And the policy should have OWASP ModSecurity CRS rules enabled:
      | rule_name                  | priority | action     |
      | SQL Injection              | 1000     | deny(403)  |
      | Cross-Site Scripting (XSS) | 1001     | deny(403)  |
      | Local File Inclusion       | 1002     | deny(403)  |
      | Remote File Inclusion      | 1003     | deny(403)  |
      | Remote Code Execution      | 1004     | deny(403)  |
      | Method Enforcement         | 1006     | deny(403)  |
      | Scanner Detection          | 1007     | deny(403)  |
      | Protocol Attack            | 1008     | deny(403)  |
      | Session Fixation           | 1009     | deny(403)  |
      | NodeJS Exploits            | 1010     | deny(403)  |
    And the policy should have a default allow rule at priority 2147483647

  @integration @waf
  Scenario: Verify WAF is NOT created when disabled
    Given the core infrastructure is deployed
    And the enable_waf variable is set to false
    When I query security policies
    Then NO regional security policy should exist

  @integration @psc
  Scenario: Verify PSC NEG is created when enabled for demo web app
    Given the core infrastructure is deployed
    And the enable_demo_web_app variable is set to true
    And the enable_demo_web_app_psc_neg variable is set to true
    When I query network endpoint groups
    Then a PSC NEG named "demo-web-app-psc-neg" should exist
    And the NEG type should be "PRIVATE_SERVICE_CONNECT"
    And the NEG should reference the demo-web-app PSC service attachment
    And the NEG should be attached to the ingress VPC
    And the NEG should be attached to the ingress subnet

  @integration @psc
  Scenario: Verify backend service uses PSC NEG when enabled
    Given the core infrastructure is deployed
    And the enable_demo_web_app variable is set to true
    And the enable_demo_web_app_psc_neg variable is set to true
    When I query backend services
    Then a regional backend service should exist named "demo-web-app-external-backend"
    And the backend service protocol should be "HTTPS"
    And the backend service should use "EXTERNAL_MANAGED" load balancing scheme
    And the backend should reference the PSC NEG
    And the balancing mode should be "UTILIZATION"

  @integration @backend
  Scenario: Verify backend service uses direct Cloud Run NEG when PSC is disabled
    Given the core infrastructure is deployed
    And the enable_demo_web_app variable is set to true
    And the enable_demo_web_app_psc_neg variable is set to false
    When I query backend services
    Then the URL map default service should reference the Cloud Run backend service from demo-web-app remote state
    And NO PSC NEG should be created
    And NO separate external backend service should be created

  @contract @variables
  Scenario: Validate required core infrastructure variables
    Given I have the OpenTofu configuration for core
    When I inspect the variables.tf file
    Then the following variables should be defined:
      | variable                       | type        | required |
      | project_suffix                 | string      | yes      |
      | region                         | string      | yes      |
      | cloudedge_github_repository    | string      | yes      |
      | resource_tags                  | map(string) | no       |
      | cloudedge_project_id           | string      | no       |
      | enable_logging                 | bool        | no       |
      | billing_account_name           | string      | yes      |
      | cloudflare_api_token           | string      | yes      |
      | cloudflare_origin_ca_key       | string      | no       |
      | cloudflare_zone_id             | string      | yes      |
      | enable_cloudflare_proxy        | bool        | no       |
      | root_domain                    | string      | no       |
      | allowed_https_source_ranges    | list(string)| no       |
      | ingress_vpc_cidr_range         | string      | no       |
      | proxy_only_subnet_cidr_range   | string      | no       |
      | enable_waf                     | bool        | no       |
      | enable_psc                     | bool        | no       |
      | enable_demo_web_app            | bool        | yes      |
      | demo_web_app_project_id        | string      | no       |
      | demo_web_app_service_name      | string      | no       |
      | demo_web_app_subdomain_name    | string      | no       |
      | enable_demo_web_app_psc_neg    | bool        | no       |

  @contract @variables
  Scenario: Verify NO Shared VPC variables exist
    Given I have the OpenTofu configuration for core
    When I inspect the variables.tf file
    Then there should be NO variable named "host_project_id"
    And there should be NO variable named "shared_vpc_name"
    And there should be NO variable named "enable_shared_vpc"
    And there should be NO variable referencing Shared VPC

  @integration @remote-state
  Scenario: Verify remote state dependencies
    Given the core infrastructure is deployed
    When I inspect the OpenTofu configuration
    Then the configuration should read remote state from "singleton"
    And the singleton state bucket should be "<project_id>-tfstate"
    And the singleton state prefix should be "<project_id>-singleton"
    And the configuration should conditionally read remote state from "demo_web_app"

  @integration @data-sources
  Scenario: Verify data sources are properly configured
    Given the core infrastructure configuration
    When I inspect data sources
    Then the following data sources should be defined:
      | data_source                         |
      | terraform_remote_state.singleton    |
      | terraform_remote_state.demo_web_app |
      | google_project.current              |
      | cloudflare_zone.vibetics            |

  @integration @outputs
  Scenario: Verify core infrastructure outputs
    Given the core infrastructure is deployed
    When I run "tofu output -json" in the core directory
    Then the following outputs should be available:
      | output             |
      | external_lb_ip     |
      | ingress_vpc_id     |
      | ingress_vpc_name   |

  @security @cis
  Scenario: Verify CIS GCP Foundation Benchmark compliance
    Given the core infrastructure is deployed
    When I audit security configurations
    Then the ingress subnet should have Private Google Access enabled (CIS 3.9)
    And VPC Flow Logs should be enabled if logging is enabled
    And all firewall rules should have explicit source ranges defined

  @smoke @teardown
  Scenario: Destroy core infrastructure
    Given the core infrastructure is deployed
    When I run "tofu destroy -auto-approve" in the core directory
    Then the destroy should succeed with exit code 0
    And all core resources should be removed
    And the ingress VPC should be deleted
    And NO orphaned Shared VPC resources should remain
