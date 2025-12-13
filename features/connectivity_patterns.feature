Feature: Connectivity Patterns (PSC vs Direct Backend)
  As a DevOps Engineer
  I want to choose between PSC and direct backend connectivity patterns
  So that I can balance network isolation, cost, and complexity based on my requirements

  Background:
    Given the project-singleton infrastructure is deployed
    And NO Shared VPC architecture is used
    And the architecture supports two connectivity patterns

  @integration @pattern
  Scenario Outline: Deploy infrastructure with Pattern 1 - PSC with Internal ALB (Maximum Isolation)
    Given I configure the infrastructure with the following variables:
      | variable                        | value  |
      | enable_demo_web_app             | true   |
      | enable_demo_web_app_psc_neg     | true   |
      | enable_demo_web_app_internal_alb| true   |
    When I deploy the core infrastructure
    And I deploy the demo-web-app infrastructure
    Then the traffic flow should follow Pattern 1:
      """
      Internet → Cloudflare → External HTTPS LB → PSC NEG →
        PSC Service Attachment → Internal ALB → Serverless NEG → Cloud Run
      """
    And the following resources should exist:
      | resource_type                              | module       |
      | google_compute_network (ingress-vpc)       | core         |
      | google_compute_network (web-vpc)           | demo-web-app |
      | google_compute_region_network_endpoint_group (PSC NEG) | core |
      | google_compute_service_attachment          | demo-web-app |
      | google_compute_region_url_map (internal)   | demo-web-app |
      | google_compute_subnetwork (psc-nat)        | demo-web-app |
    And the VPCs should be completely isolated from each other
    And connectivity should only be via Private Service Connect

    Examples:
      | scenario_name           |
      | Cross-project with PSC  |
      | Same-project with PSC   |

  @integration @pattern
  Scenario: Deploy infrastructure with Pattern 2 - Direct Backend Service (Simplest)
    Given I configure the infrastructure with the following variables:
      | variable                        | value  |
      | enable_demo_web_app             | true   |
      | enable_demo_web_app_psc_neg     | false  |
      | enable_demo_web_app_internal_alb| false  |
    When I deploy the core infrastructure
    And I deploy the demo-web-app infrastructure
    Then the traffic flow should follow Pattern 2:
      """
      Internet → Cloudflare → External HTTPS LB → Backend Service → Serverless NEG → Cloud Run
      """
    And the following resources should exist:
      | resource_type                            | module       |
      | google_compute_network (ingress-vpc)     | core         |
      | google_cloud_run_v2_service              | demo-web-app |
      | google_compute_region_network_endpoint_group (Serverless) | demo-web-app |
      | google_compute_region_backend_service    | demo-web-app |
    And the following resources should NOT exist:
      | resource_type                     |
      | google_compute_network (web-vpc)  |
      | google_compute_service_attachment |
      | PSC NAT subnet                    |
      | Internal ALB                      |

  @integration @pattern
  Scenario: Verify Pattern 1 provides maximum network isolation
    Given the infrastructure is deployed with Pattern 1 (PSC enabled)
    When I inspect network architecture
    Then the ingress VPC and web VPC should be completely isolated
    And there should be NO VPC peering between ingress-vpc and web-vpc
    And there should be NO Shared VPC configuration
    And traffic should traverse Private Service Connect only
    And IP address spaces can overlap without conflict
    And the demo-web-app VPC should be invisible to the core project

  @integration @pattern
  Scenario: Verify Pattern 2 provides simplified architecture
    Given the infrastructure is deployed with Pattern 2 (PSC disabled)
    When I count infrastructure resources
    Then the resource count should be lower than Pattern 1
    And there should be NO web VPC in the demo-web-app project
    And there should be NO PSC Service Attachment
    And there should be NO Internal ALB
    And the Cloud Run service should connect directly to the external load balancer via Serverless NEG

  @integration @cost
  Scenario Outline: Compare resource costs between patterns
    Given the infrastructure is deployed with <pattern>
    When I analyze GCP resource costs
    Then the pattern should have <cost_profile>
    And the following resources contribute to cost:
      | resource                  | pattern_1 | pattern_2 |
      | External Load Balancer    | yes       | yes       |
      | Internal Load Balancer    | yes       | no        |
      | PSC Service Attachment    | yes       | no        |
      | NAT Gateway (PSC NAT)     | yes       | no        |
      | VPC (Web VPC)             | yes       | no        |
      | Cloud Run                 | yes       | yes       |

    Examples:
      | pattern   | cost_profile      |
      | Pattern 1 | Higher cost       |
      | Pattern 2 | Lower cost        |

  @integration @cross-project
  Scenario: Deploy Pattern 1 across different GCP projects
    Given I have two GCP projects:
      | project_type | project_id              |
      | core         | cloudedge-nonprod       |
      | demo-web-app | cloudedge-demo-nonprod  |
    And I configure the infrastructure with:
      | variable                    | value                  |
      | cloudedge_project_id        | cloudedge-nonprod      |
      | demo_web_app_project_id     | cloudedge-demo-nonprod |
      | enable_demo_web_app_psc_neg | true                   |
    When I deploy the core infrastructure to cloudedge-nonprod
    And I deploy the demo-web-app infrastructure to cloudedge-demo-nonprod
    Then the PSC Service Attachment should be in cloudedge-demo-nonprod
    And the PSC NEG should be in cloudedge-nonprod
    And the PSC NEG should reference the Service Attachment across projects
    And traffic should flow across project boundaries via PSC

  @integration @same-project
  Scenario: Deploy Pattern 2 in a single GCP project
    Given I have one GCP project "cloudedge-nonprod"
    And I configure the infrastructure with:
      | variable                    | value              |
      | cloudedge_project_id        | cloudedge-nonprod  |
      | demo_web_app_project_id     | ""                 |
      | enable_demo_web_app_psc_neg | false              |
    When I deploy both core and demo-web-app to cloudedge-nonprod
    Then all resources should be in the same project
    And the backend service should directly reference the Serverless NEG
    And NO cross-project references should exist

  @security @pattern
  Scenario Outline: Verify security layers for each pattern
    Given the infrastructure is deployed with <pattern>
    When I analyze security configurations
    Then the following security layers should be active:
      | security_layer                    | pattern_1 | pattern_2 |
      | Cloudflare WAF (optional)         | yes       | yes       |
      | GCP Cloud Armor WAF (optional)    | yes       | yes       |
      | Cloudflare DDoS protection        | yes       | yes       |
      | Origin IP hidden by Cloudflare    | yes       | yes       |
      | Firewall (Cloudflare IPs only)    | yes       | yes       |
      | Cloud Run ingress policy (internal)| yes      | yes       |
      | VPC isolation via PSC             | yes       | no        |
      | Internal ALB additional layer     | yes       | no        |

    Examples:
      | pattern   |
      | Pattern 1 |
      | Pattern 2 |

  @integration @toggle
  Scenario: Toggle between patterns by changing variables
    Given the infrastructure is deployed with Pattern 2
    And the current configuration has enable_demo_web_app_psc_neg = false
    When I change the variable enable_demo_web_app_psc_neg to true
    And I change the variable enable_demo_web_app_internal_alb to true
    And I run "tofu plan" in both core and demo-web-app directories
    Then the plan should show creation of:
      | resource                     |
      | Web VPC                      |
      | PSC NAT subnet               |
      | Internal ALB                 |
      | PSC Service Attachment       |
      | PSC NEG in core              |
    And the plan should show modification of:
      | resource                     |
      | Backend service reference    |

  @integration @performance
  Scenario Outline: Measure latency differences between patterns
    Given the infrastructure is deployed with <pattern>
    When I send 100 HTTP requests to the demo web app
    Then the average latency should be approximately <expected_latency>
    And the latency should include:
      | hop                          | pattern_1 | pattern_2 |
      | Cloudflare edge → GCP        | yes       | yes       |
      | External LB → PSC NEG        | yes       | no        |
      | PSC traversal                | yes       | no        |
      | Internal ALB processing      | yes       | no        |
      | External LB → Serverless NEG | no        | yes       |
      | Cloud Run processing         | yes       | yes       |

    Examples:
      | pattern   | expected_latency |
      | Pattern 1 | 50-100ms         |
      | Pattern 2 | 30-60ms          |

  @contract @pattern
  Scenario: Validate pattern selection via variable combinations
    Given I have the OpenTofu configuration
    When I inspect the conditional resource creation logic
    Then the following variable combinations should be valid:
      | enable_demo_web_app_psc_neg | enable_demo_web_app_internal_alb | pattern     | web_vpc_created |
      | true                        | true                             | Pattern 1   | yes             |
      | true                        | false                            | Pattern 1   | yes             |
      | false                       | true                             | Hybrid      | yes             |
      | false                       | false                            | Pattern 2   | no              |
    And the conditional logic should use:
      """
      count = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
      """

  @integration @outputs
  Scenario Outline: Verify outputs differ between patterns
    Given the infrastructure is deployed with <pattern>
    When I run "tofu output -json" in both core and demo-web-app directories
    Then the core outputs should include:
      | output                               | pattern_1 | pattern_2 |
      | external_lb_ip                       | yes       | yes       |
      | ingress_vpc_id                       | yes       | yes       |
      | psc_neg_id (if PSC enabled)          | yes       | no        |
    And the demo-web-app outputs should include:
      | output                               | pattern_1 | pattern_2 |
      | web_app_service_name                 | yes       | yes       |
      | web_vpc_id                           | yes       | no        |
      | web_app_psc_service_attachment_self_link | yes   | no        |
      | web_app_backend_service_id           | yes       | yes       |

    Examples:
      | pattern   |
      | Pattern 1 |
      | Pattern 2 |

  @contract @no-shared-vpc
  Scenario: Verify NO Shared VPC resources in any pattern
    Given I deploy infrastructure with Pattern 1
    And I deploy infrastructure with Pattern 2
    When I query all GCP resources across both patterns
    Then there should be ZERO "google_compute_shared_vpc_host_project" resources
    And there should be ZERO "google_compute_shared_vpc_service_project" resources
    And there should be ZERO references to "host_project_id" variable
    And connectivity should be achieved via:
      | pattern   | connectivity_method     |
      | Pattern 1 | Private Service Connect |
      | Pattern 2 | Serverless NEG          |

  @documentation
  Scenario: Document architecture decision for pattern selection
    Given a development team is choosing between patterns
    When they review the architecture documentation
    Then they should consider the following factors:
      | factor                  | pattern_1_advantage | pattern_2_advantage |
      | Network isolation       | Maximum             | Basic               |
      | Cost                    | Higher              | Lower               |
      | Complexity              | Higher              | Lower               |
      | Cross-project support   | Yes                 | Yes                 |
      | Setup time              | Longer              | Shorter             |
      | Troubleshooting         | More complex        | Simpler             |
      | IP address flexibility  | Overlapping allowed | Standard rules      |
      | Multi-tenant ready      | Yes                 | Limited             |
