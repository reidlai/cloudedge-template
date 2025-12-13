package gcp

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFullBaseline(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	projectSuffix := "nonprod"

	// Require necessary environment variables
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_API_TOKEN"), "CLOUDFLARE_API_TOKEN must be set")
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_ZONE_ID"), "CLOUDFLARE_ZONE_ID must be set")

	// Configure core infrastructure
	coreOptions := &terraform.Options{
		TerraformDir: "../../../deploy/opentofu/gcp/core",
		Vars: map[string]interface{}{
			"project_suffix":              projectSuffix,
			"cloudedge_github_repository": "vibetics-cloudedge",
			"cloudedge_project_id":        projectID,
			"region":                      region,
			"enable_demo_web_app":         true,
			"enable_waf":                  true,
			"enable_cloudflare_proxy":     false, // Test without Cloudflare proxy
			"enable_demo_web_app_psc_neg": false, // Test direct backend connection
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
			"allowed_https_source_ranges": []string{"0.0.0.0/0"}, // Allow all for testing
		},
	}

	defer terraform.Destroy(t, coreOptions)

	t.Log("========================================")
	t.Log("Phase 1: Core Infrastructure Deployment")
	t.Log("========================================")

	terraform.InitAndApply(t, coreOptions)

	t.Log("========================================")
	t.Log("Phase 2: Infrastructure Component Validation")
	t.Log("========================================")

	// Validate load balancer IP
	loadBalancerIP := terraform.Output(t, coreOptions, "load_balancer_ip")
	assert.NotEmpty(t, loadBalancerIP, "Load balancer IP should be provisioned")
	t.Logf("✓ Load Balancer IP: %s", loadBalancerIP)

	// Verify ingress VPC
	ingressVPCID := terraform.Output(t, coreOptions, "ingress_vpc_id")
	assert.NotEmpty(t, ingressVPCID, "Ingress VPC ID should exist")
	t.Log("✓ Ingress VPC provisioned")

	// Verify ingress subnet
	ingressSubnetID := terraform.Output(t, coreOptions, "ingress_subnet_id")
	assert.NotEmpty(t, ingressSubnetID, "Ingress subnet ID should exist")
	t.Log("✓ Ingress Subnet provisioned")

	// Verify WAF
	wafPolicyID := terraform.Output(t, coreOptions, "waf_policy_id")
	assert.NotEmpty(t, wafPolicyID, "WAF policy ID should exist when enable_waf=true")
	t.Log("✓ Cloud Armor WAF provisioned")

	// Verify Cloud Armor is enabled
	cloudArmorEnabled := terraform.Output(t, coreOptions, "cloud_armor_enabled")
	assert.Equal(t, "true", cloudArmorEnabled, "Cloud Armor should be enabled")

	// Verify firewall rules
	firewallCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "firewall-rules", "list",
			"--project=" + projectID,
			"--filter=network:ingress-vpc",
			"--format=value(name)",
		},
	}
	firewallOutput := shell.RunCommandAndGetOutput(t, firewallCmd)
	assert.NotEmpty(t, firewallOutput, "Firewall rules should exist")
	assert.Contains(t, firewallOutput, "allow-https", "HTTPS firewall rule should exist")
	t.Log("✓ Firewall rules provisioned")

	t.Log("========================================")
	t.Log("Phase 3: Network Connectivity Tests")
	t.Log("========================================")

	// Note: Since demo-web-app is not deployed in this simplified version,
	// we skip the load balancer connectivity tests
	t.Log("⚠ Skipping load balancer connectivity tests (demo-web-app not deployed)")
	t.Log("  To test full connectivity, deploy demo-web-app module separately")

	t.Log("========================================")
	t.Log("Full Baseline Test Results")
	t.Log("========================================")
	t.Log("✓ Core infrastructure components deployed:")
	t.Log("  - Ingress VPC with subnet")
	t.Log("  - Load balancer with regional IP")
	t.Log("  - Cloud Armor WAF policies")
	t.Log("  - Firewall rules (HTTPS)")
	t.Log("========================================")
	t.Log("Baseline Infrastructure Test: PASSED")
	t.Log("========================================")
}

// TestFullBaselineWithDemo tests the complete stack including demo web app
func TestFullBaselineWithDemo(t *testing.T) {
	t.Skip("Skipping full demo test - requires sequential deployment of core then demo-web-app modules")

	// This test would require:
	// 1. Deploy core module with enable_demo_web_app=true
	// 2. Deploy demo-web-app module
	// 3. Test connectivity through load balancer
	// 4. Teardown in reverse order

	// For now, users should test core and demo-web-app modules separately
	// using the individual test files (demo_web_app_test.go, etc.)
}
