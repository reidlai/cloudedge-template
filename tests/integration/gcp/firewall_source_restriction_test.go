package gcp

import (
	"context"
	"testing"

	compute "google.golang.org/api/compute/v1"
	gcptest "github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestFirewallSourceRestriction validates that ingress VPC firewall rules
// restrict HTTPS traffic to Google Cloud Load Balancer IP ranges only (FR-009).
//
// This test addresses CRITICAL finding C1 from /speckit.analyze:
// "No test validates that ingress firewall restricts source IPs to load balancer ranges only"
//
// Acceptance Criteria:
// - Firewall rule for HTTPS (port 443) exists on ingress VPC
// - Source ranges are restricted to Google Cloud Load Balancer IPs:
//   - 35.191.0.0/16 (health checks and proxy IPs)
//   - 130.211.0.0/22 (legacy health checks)
// - Source ranges do NOT include 0.0.0.0/0 (unrestricted internet access)
//
// Test Scenario:
// Given a deployed baseline infrastructure
// When I inspect the ingress VPC firewall rules
// Then the HTTPS rule should restrict source ranges to GCP Load Balancer IPs
// And the rule should NOT allow traffic from 0.0.0.0/0
func TestFirewallSourceRestriction(t *testing.T) {
	t.Parallel()

	// Skip if running in short mode
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// Define expected Google Cloud Load Balancer IP ranges
	expectedSourceRanges := []string{
		"35.191.0.0/16",   // GCP Load Balancer health check and proxy IPs
		"130.211.0.0/22",  // GCP legacy health check IPs
	}

	// Setup Terraform options
	projectID := getProjectID(t)
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id":        projectID,
			"environment":       "nonprod",
			"cloud_provider":    "gcp",
			"region":            "northamerica-northeast2",
		},
		EnvVars: map[string]string{
			"GOOGLE_PROJECT": projectID,
		},
	})

	// Deploy infrastructure
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get the firewall rule name from Terraform outputs
	// The firewall module should output the rule name
	firewallRuleName := terraform.Output(t, terraformOptions, "firewall_rule_name")
	require.NotEmpty(t, firewallRuleName, "Firewall rule name should not be empty")

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

	// Validate source ranges match expected Google Cloud Load Balancer IPs
	assert.ElementsMatch(t, expectedSourceRanges, firewallRule.SourceRanges,
		"Firewall source ranges should match Google Cloud Load Balancer IP ranges")

	// CRITICAL SECURITY CHECK: Ensure 0.0.0.0/0 is NOT in source ranges
	for _, sourceRange := range firewallRule.SourceRanges {
		assert.NotEqual(t, "0.0.0.0/0", sourceRange,
			"Firewall rule MUST NOT allow unrestricted internet access (0.0.0.0/0)")
	}

	// Validate firewall direction is INGRESS (or empty, which defaults to INGRESS)
	if firewallRule.Direction != "" {
		assert.Equal(t, "INGRESS", firewallRule.Direction, "Firewall rule should be for ingress traffic")
	}

	// Validate firewall is applied to the ingress VPC network
	assert.Contains(t, firewallRule.Network, "ingress-vpc",
		"Firewall rule should be applied to the ingress VPC")

	t.Logf("✅ Firewall source restriction validation PASSED")
	t.Logf("   - Rule: %s", firewallRuleName)
	t.Logf("   - Source Ranges: %v", firewallRule.SourceRanges)
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
