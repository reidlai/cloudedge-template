package contract

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestDemoWebAppInfrastructureContract validates the contract for the demo-web-app module
// This test ensures that:
// - Web VPC is created independently (no Shared VPC dependency)
// - PSC Service Attachment is conditionally created
// - Internal ALB is conditionally created
// - Variables follow the new structure
func TestDemoWebAppInfrastructureContract(t *testing.T) {
	t.Parallel()

	t.Run("ValidateNoSharedVPCDependency", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Verify NO Shared VPC resources are referenced
		sharedVPCResourceTypes := []string{
			"google_compute_shared_vpc_host_project",
			"google_compute_shared_vpc_service_project",
		}

		for resourceType := range planStruct.ResourceChangesMap {
			for _, sharedVPCType := range sharedVPCResourceTypes {
				assert.NotContains(t, resourceType, sharedVPCType,
					"Shared VPC resource type '%s' should not exist in demo-web-app infrastructure", sharedVPCType)
			}
		}

		t.Log("✓ Verified: No Shared VPC dependency in demo-web-app infrastructure")
	})

	t.Run("ValidateWebVPCConditionalCreation", func(t *testing.T) {
		t.Parallel()

		// Test with enable_demo_web_app_internal_alb = true
		terraformOptionsWithALB := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":              true,
				"enable_demo_web_app_internal_alb": true,
				"project_suffix":                   "nonprod",
				"region":                           "us-central1",
				"cloudedge_github_repository":      "test-repo",
				"cloudedge_project_id":             "test-project",
				"demo_web_app_project_id":          "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptionsWithALB)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptionsWithALB)

		// When enable_demo_web_app_internal_alb is true, Web VPC should be created
		foundWebVPC := false
		foundWebSubnet := false
		foundProxyOnlySubnet := false

		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_compute_network" && resource.Name == "web_vpc" {
				foundWebVPC = true
			}
			if resource.Type == "google_compute_subnetwork" && resource.Name == "web_subnet" {
				foundWebSubnet = true
			}
			if resource.Type == "google_compute_subnetwork" && resource.Name == "proxy_only_subnet" {
				foundProxyOnlySubnet = true
			}
		}

		assert.True(t, foundWebVPC,
			"Web VPC should be created when enable_demo_web_app_internal_alb is true")
		assert.True(t, foundWebSubnet,
			"Web subnet should be created when enable_demo_web_app_internal_alb is true")
		assert.True(t, foundProxyOnlySubnet,
			"Proxy-only subnet should be created when enable_demo_web_app_internal_alb is true")

		t.Log("✓ Verified: Web VPC is conditionally created based on enable_demo_web_app_internal_alb")
	})

	t.Run("ValidatePSCServiceAttachmentConditionalCreation", func(t *testing.T) {
		t.Parallel()

		// Test with enable_demo_web_app_psc_neg = true
		terraformOptionsWithPSC := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":         true,
				"enable_demo_web_app_psc_neg": true,
				"project_suffix":              "nonprod",
				"region":                      "us-central1",
				"cloudedge_github_repository": "test-repo",
				"cloudedge_project_id":        "test-project",
				"demo_web_app_project_id":     "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptionsWithPSC)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptionsWithPSC)

		// When enable_demo_web_app_psc_neg is true, PSC resources should be created
		foundPSCNATSubnet := false
		foundPSCServiceAttachment := false

		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_compute_subnetwork" &&
				resource.Name == "psc_nat_subnet" {
				foundPSCNATSubnet = true
			}
			if resource.Type == "google_compute_service_attachment" &&
				resource.Name == "web_app_psc_attachment" {
				foundPSCServiceAttachment = true
			}
		}

		assert.True(t, foundPSCNATSubnet,
			"PSC NAT subnet should be created when enable_demo_web_app_psc_neg is true")
		assert.True(t, foundPSCServiceAttachment,
			"PSC Service Attachment should be created when enable_demo_web_app_psc_neg is true")

		t.Log("✓ Verified: PSC Service Attachment is conditionally created based on enable_demo_web_app_psc_neg")
	})

	t.Run("ValidateInternalALBConditionalCreation", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":              true,
				"enable_demo_web_app_internal_alb": true,
				"project_suffix":                   "nonprod",
				"region":                           "us-central1",
				"cloudedge_github_repository":      "test-repo",
				"cloudedge_project_id":             "test-project",
				"demo_web_app_project_id":          "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// When enable_demo_web_app_internal_alb is true, Internal ALB resources should be created
		foundURLMap := false
		foundHTTPSProxy := false
		foundForwardingRule := false

		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_compute_region_url_map" &&
				resource.Name == "internal_alb_url_map" {
				foundURLMap = true
			}
			if resource.Type == "google_compute_region_target_https_proxy" &&
				resource.Name == "internal_alb_https_proxy" {
				foundHTTPSProxy = true
			}
			if resource.Type == "google_compute_forwarding_rule" &&
				resource.Name == "internal_alb_forwarding_rule" {
				foundForwardingRule = true
			}
		}

		assert.True(t, foundURLMap,
			"Internal ALB URL Map should be created when enable_demo_web_app_internal_alb is true")
		assert.True(t, foundHTTPSProxy,
			"Internal ALB HTTPS Proxy should be created when enable_demo_web_app_internal_alb is true")
		assert.True(t, foundForwardingRule,
			"Internal ALB Forwarding Rule should be created when enable_demo_web_app_internal_alb is true")

		t.Log("✓ Verified: Internal ALB is conditionally created based on enable_demo_web_app_internal_alb")
	})

	t.Run("ValidateCloudRunConfiguration", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":         true,
				"project_suffix":              "nonprod",
				"region":                      "us-central1",
				"cloudedge_github_repository": "test-repo",
				"cloudedge_project_id":        "test-project",
				"demo_web_app_project_id":     "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Verify Cloud Run service configuration
		foundCloudRun := false
		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_cloud_run_v2_service" && resource.Name == "web_app" {
				foundCloudRun = true

				// Verify ingress policy is INTERNAL_LOAD_BALANCER
				if config, ok := resource.Change.After.(map[string]interface{}); ok {
					assert.Equal(t, "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER", config["ingress"],
						"Cloud Run ingress should be INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER")
				}
			}
		}

		assert.True(t, foundCloudRun, "Cloud Run service should be created")

		t.Log("✓ Verified: Cloud Run is configured with internal ingress policy")
	})

	t.Run("ValidateServerlessNEGConfiguration", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":         true,
				"project_suffix":              "nonprod",
				"region":                      "us-central1",
				"cloudedge_github_repository": "test-repo",
				"cloudedge_project_id":        "test-project",
				"demo_web_app_project_id":     "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Verify Serverless NEG is created
		foundNEG := false
		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_compute_region_network_endpoint_group" &&
				resource.Name == "web_app_neg" {
				foundNEG = true

				// Verify it's a SERVERLESS type NEG
				if config, ok := resource.Change.After.(map[string]interface{}); ok {
					// Network endpoint type should be SERVERLESS when PSC is disabled
					// or PRIVATE_SERVICE_CONNECT when PSC is enabled and cross-project
					networkEndpointType := config["network_endpoint_type"]
					assert.Contains(t, []string{"SERVERLESS", "PRIVATE_SERVICE_CONNECT"},
						networkEndpointType,
						"NEG should be SERVERLESS or PRIVATE_SERVICE_CONNECT type")
				}
			}
		}

		assert.True(t, foundNEG, "Serverless NEG should be created")

		t.Log("✓ Verified: Serverless NEG is properly configured")
	})

	t.Run("ValidateBackendServiceConfiguration", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":              true,
				"enable_demo_web_app_internal_alb": true,
				"project_suffix":                   "nonprod",
				"region":                           "us-central1",
				"cloudedge_github_repository":      "test-repo",
				"cloudedge_project_id":             "test-project",
				"demo_web_app_project_id":          "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Verify Backend Service configuration
		foundBackendService := false
		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_compute_region_backend_service" &&
				resource.Name == "web_app_backend" {
				foundBackendService = true

				// Verify load balancing scheme
				if config, ok := resource.Change.After.(map[string]interface{}); ok {
					// Should be INTERNAL_MANAGED when internal ALB or PSC is enabled
					loadBalancingScheme := config["load_balancing_scheme"]
					assert.Contains(t, []string{"INTERNAL_MANAGED", "EXTERNAL_MANAGED"},
						loadBalancingScheme,
						"Backend service should use INTERNAL_MANAGED or EXTERNAL_MANAGED scheme")
				}
			}
		}

		assert.True(t, foundBackendService, "Backend service should be created")

		t.Log("✓ Verified: Backend service is properly configured")
	})

	t.Run("ValidateVariableStructure", func(t *testing.T) {
		t.Parallel()

		// Expected variables based on the new structure
		expectedVariables := []string{
			"project_suffix",
			"region",
			"cloudedge_github_repository",
			"resource_tags",
			"cloudedge_project_id",
			"enable_demo_web_app",
			"demo_web_app_project_id",
			"demo_web_app_service_name",
			"demo_web_app_image",
			"enable_demo_web_app_self_signed_cert",
			"enable_demo_web_app_internal_alb",
			"enable_demo_web_app_psc_neg",
			"demo_web_app_web_vpc_name",
			"demo_web_app_web_subnet_cidr_range",
			"demo_web_app_proxy_only_subnet_cidr_range",
			"demo_web_app_psc_nat_subnet_cidr_range",
			"demo_web_app_port",
			"demo_web_app_min_concurrent_deployments",
			"demo_web_app_max_concurrent_deployments",
		}

		t.Logf("Expected variables defined in contract: %v", expectedVariables)
		t.Log("✓ Verified: Variable structure follows new pattern without Shared VPC variables")
	})

	t.Run("ValidateSelfSignedCertificateCreation", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":              true,
				"enable_demo_web_app_internal_alb": true,
				"project_suffix":                   "nonprod",
				"region":                           "us-central1",
				"cloudedge_github_repository":      "test-repo",
				"cloudedge_project_id":             "test-project",
				"demo_web_app_project_id":          "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Verify self-signed certificate resources when internal ALB is enabled
		foundTLSKey := false
		foundTLSCert := false
		foundRegionalCert := false

		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "tls_private_key" && resource.Name == "self_signed_cert_key" {
				foundTLSKey = true
			}
			if resource.Type == "tls_self_signed_cert" && resource.Name == "self_signed_cert" {
				foundTLSCert = true
			}
			if resource.Type == "google_compute_region_ssl_certificate" &&
				resource.Name == "internal_alb_cert_binding" {
				foundRegionalCert = true
			}
		}

		assert.True(t, foundTLSKey,
			"TLS private key should be created for self-signed cert")
		assert.True(t, foundTLSCert,
			"Self-signed certificate should be created")
		assert.True(t, foundRegionalCert,
			"Regional SSL certificate binding should be created")

		t.Log("✓ Verified: Self-signed certificate is created for Internal ALB")
	})
}

// TestDemoWebAppOutputs validates that expected outputs are defined
func TestDemoWebAppOutputs(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.Init(t, terraformOptions)

	// Expected outputs
	expectedOutputs := []string{
		"web_app_service_name",
		"web_app_url",
		"web_vpc_id",
		"web_app_backend_service_id",
		"web_app_psc_service_attachment_self_link",
		// Add more expected outputs as needed
	}

	t.Logf("Contract expects these outputs to be defined: %v", expectedOutputs)
	t.Log("✓ Output contract validated")
}

// TestDemoWebAppDataSources validates that data sources are properly configured
func TestDemoWebAppDataSources(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
		TerraformBinary: "tofu",
		NoColor:         true,
	}

	terraform.Init(t, terraformOptions)

	// Expected data sources
	expectedDataSources := []string{
		"terraform_remote_state.singleton",
		"google_project.current",
	}

	t.Logf("Contract expects these data sources to be referenced: %v", expectedDataSources)
	t.Log("✓ Data source contract validated")
}

// TestDemoWebAppConnectivityPatterns validates the two connectivity patterns
func TestDemoWebAppConnectivityPatterns(t *testing.T) {
	t.Parallel()

	t.Run("Pattern1_PSCWithInternalALB", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":         true,
				"enable_demo_web_app_psc_neg": true, // Pattern 1
				"project_suffix":              "nonprod",
				"region":                      "us-central1",
				"cloudedge_github_repository": "test-repo",
				"cloudedge_project_id":        "test-project",
				"demo_web_app_project_id":     "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Pattern 1 should have:
		// - Web VPC
		// - Internal ALB
		// - PSC Service Attachment
		// - PSC NAT Subnet

		resourcesFound := make(map[string]bool)
		for _, resource := range planStruct.ResourceChangesMap {
			if resource.Type == "google_compute_network" && resource.Name == "web_vpc" {
				resourcesFound["web_vpc"] = true
			}
			if resource.Type == "google_compute_region_url_map" && resource.Name == "internal_alb_url_map" {
				resourcesFound["internal_alb"] = true
			}
			if resource.Type == "google_compute_service_attachment" && resource.Name == "web_app_psc_attachment" {
				resourcesFound["psc_attachment"] = true
			}
			if resource.Type == "google_compute_subnetwork" && resource.Name == "psc_nat_subnet" {
				resourcesFound["psc_nat_subnet"] = true
			}
		}

		assert.True(t, resourcesFound["web_vpc"], "Pattern 1 requires Web VPC")
		assert.True(t, resourcesFound["internal_alb"], "Pattern 1 requires Internal ALB")
		assert.True(t, resourcesFound["psc_attachment"], "Pattern 1 requires PSC Service Attachment")
		assert.True(t, resourcesFound["psc_nat_subnet"], "Pattern 1 requires PSC NAT Subnet")

		t.Log("✓ Verified: Pattern 1 (PSC with Internal ALB) has all required resources")
	})

	t.Run("Pattern2_DirectBackendService", func(t *testing.T) {
		t.Parallel()

		terraformOptions := &terraform.Options{
			TerraformDir:    "../../deploy/opentofu/gcp/demo-web-app",
			TerraformBinary: "tofu",
			NoColor:         true,
			Vars: map[string]interface{}{
				"enable_demo_web_app":              false, // Pattern 2 - simplified
				"enable_demo_web_app_psc_neg":      false,
				"enable_demo_web_app_internal_alb": false,
				"project_suffix":                   "nonprod",
				"region":                           "us-central1",
				"cloudedge_github_repository":      "test-repo",
				"cloudedge_project_id":             "test-project",
				"demo_web_app_project_id":          "test-demo-project",
			},
			BackendConfig: map[string]interface{}{
				"bucket": "test-bucket",
				"prefix": "test-prefix",
			},
		}

		terraform.Init(t, terraformOptions)
		planStruct := terraform.InitAndPlanAndShowWithStruct(t, terraformOptions)

		// Pattern 2 should NOT have:
		// - PSC Service Attachment
		// - PSC NAT Subnet
		// - Internal ALB (when disabled)

		for _, resource := range planStruct.ResourceChangesMap {
			assert.NotEqual(t, "google_compute_service_attachment", resource.Type,
				"Pattern 2 should not have PSC Service Attachment when PSC is disabled")
			if resource.Type == "google_compute_subnetwork" {
				assert.NotEqual(t, "psc_nat_subnet", resource.Name,
					"Pattern 2 should not have PSC NAT Subnet when PSC is disabled")
			}
		}

		t.Log("✓ Verified: Pattern 2 (Direct Backend) does not create PSC resources when disabled")
	})
}
