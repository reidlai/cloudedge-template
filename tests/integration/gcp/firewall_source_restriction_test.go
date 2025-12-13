package gcp

import (
	"context"
	"os"
	"testing"

	gcptest "github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	compute "google.golang.org/api/compute/v1"
)

// TestFirewallSourceRestriction validates that ingress VPC firewall rules
// restrict HTTPS traffic appropriately based on configuration.
//
// When enable_cloudflare_proxy=true: Restricts to Cloudflare IP ranges
// When enable_cloudflare_proxy=false: Restricts to configured allowed_https_source_ranges
//
// Acceptance Criteria:
// - Firewall rule for HTTPS (port 443) exists on ingress VPC
// - Source ranges are either Cloudflare IPs or configured allowed ranges
// - Firewall rule direction is INGRESS
// - Firewall is applied to ingress VPC
func TestFirewallSourceRestriction(t *testing.T) {
	t.Parallel()

	// Skip if running in short mode
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	projectID := getProjectID(t)
	region := "northamerica-northeast2"
	projectSuffix := "nonprod"

	// Require necessary environment variables
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_API_TOKEN"), "CLOUDFLARE_API_TOKEN must be set")
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_ZONE_ID"), "CLOUDFLARE_ZONE_ID must be set")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../../deploy/opentofu/gcp/core",
		Vars: map[string]interface{}{
			"project_suffix":              projectSuffix,
			"cloudedge_github_repository": "vibetics-cloudedge",
			"cloudedge_project_id":        projectID,
			"region":                      region,
			"enable_demo_web_app":         false,
			"enable_cloudflare_proxy":     true, // Test with Cloudflare proxy enabled
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
		},
	})

	// Deploy infrastructure
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Expected firewall rule name based on project_suffix
	firewallRuleName := projectSuffix + "-allow-https"

	// Fetch firewall rule details from GCP using Compute API
	ctx := context.Background()
	computeService, err := compute.NewService(ctx)
	require.NoError(t, err, "Failed to create GCP Compute service")

	firewallRule, err := computeService.Firewalls.Get(projectID, firewallRuleName).Context(ctx).Do()
	require.NoError(t, err, "Failed to fetch firewall rule from GCP")

	// Validate firewall rule exists
	require.NotNil(t, firewallRule, "Firewall rule should exist")
	assert.Equal(t, firewallRuleName, firewallRule.Name, "Firewall rule name should match")

	// Validate firewall rule allows HTTPS (port 443)
	require.NotEmpty(t, firewallRule.Allowed, "Firewall rule should have allowed protocols")

	hasHTTPS := false
	for _, allowed := range firewallRule.Allowed {
		if allowed.IPProtocol == "tcp" {
			for _, port := range allowed.Ports {
				if port == "443" {
					hasHTTPS = true
					break
				}
			}
		}
	}
	assert.True(t, hasHTTPS, "Firewall rule should allow HTTPS (port 443)")

	// CRITICAL VALIDATION: Check source ranges
	require.NotEmpty(t, firewallRule.SourceRanges, "Firewall rule should have source ranges defined")

	// When Cloudflare proxy is enabled, verify Cloudflare IP ranges are used
	// Cloudflare IP ranges (from core.tf locals)
	cloudflareIPRanges := []string{
		"173.245.48.0/20",
		"103.21.244.0/22",
		"103.22.200.0/22",
		"103.31.4.0/22",
		"141.101.64.0/18",
		"108.162.192.0/18",
		"190.93.240.0/20",
		"188.114.96.0/20",
		"197.234.240.0/22",
		"198.41.128.0/17",
		"162.158.0.0/15",
		"104.16.0.0/13",
		"104.24.0.0/14",
		"172.64.0.0/13",
		"131.0.72.0/22",
	}

	// Validate source ranges match Cloudflare IPs
	assert.ElementsMatch(t, cloudflareIPRanges, firewallRule.SourceRanges,
		"Firewall source ranges should match Cloudflare IP ranges when enable_cloudflare_proxy=true")

	// CRITICAL SECURITY CHECK: Ensure 0.0.0.0/0 is NOT in source ranges
	for _, sourceRange := range firewallRule.SourceRanges {
		assert.NotEqual(t, "0.0.0.0/0", sourceRange,
			"Firewall rule MUST NOT allow unrestricted internet access (0.0.0.0/0)")
	}

	// Validate firewall direction is INGRESS
	assert.Equal(t, "INGRESS", firewallRule.Direction, "Firewall rule should be for ingress traffic")

	// Validate firewall is applied to the ingress VPC network
	assert.Contains(t, firewallRule.Network, "ingress-vpc",
		"Firewall rule should be applied to the ingress VPC")

	t.Logf("✅ Firewall source restriction validation PASSED")
	t.Logf("   - Rule: %s", firewallRuleName)
	t.Logf("   - Source Ranges: Cloudflare IP ranges (%d ranges)", len(firewallRule.SourceRanges))
	t.Logf("   - Protocol: TCP, Ports: 443 (HTTPS)")
	t.Logf("   - Direction: %s", firewallRule.Direction)
	t.Logf("   - Network: %s", firewallRule.Network)
}

// getProjectID retrieves the GCP project ID from environment variables
func getProjectID(t *testing.T) string {
	projectID := gcptest.GetGoogleProjectIDFromEnvVar(t)
	if projectID == "" {
		t.Fatal("GCP Project ID must be set via GOOGLE_PROJECT environment variable")
	}
	return projectID
}
