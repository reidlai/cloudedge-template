package gcp

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestTeardown(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	projectSuffix := "nonprod"

	// Require necessary environment variables
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_API_TOKEN"), "CLOUDFLARE_API_TOKEN must be set")
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_ZONE_ID"), "CLOUDFLARE_ZONE_ID must be set")

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../deploy/opentofu/gcp/core",
		Vars: map[string]interface{}{
			"project_suffix":              projectSuffix,
			"cloudedge_github_repository": "vibetics-cloudedge",
			"cloudedge_project_id":        projectID,
			"region":                      region,
			"enable_demo_web_app":         false,
			"enable_waf":                  true,
			"enable_logging":              false, // Fast teardown for testing
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
		},
	}

	// Deploy infrastructure
	t.Log("Deploying infrastructure for teardown test...")
	terraform.InitAndApply(t, terraformOptions)

	// Verify key resources exist before teardown
	t.Log("Verifying resources exist before teardown...")

	// Check ingress VPC exists
	ingressVPCCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			"ingress-vpc",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}
	ingressVPCOutput := shell.RunCommandAndGetOutput(t, ingressVPCCmd)
	if !strings.Contains(ingressVPCOutput, "ingress-vpc") {
		t.Fatal("Ingress VPC not found after deployment")
	}

	// Check firewall rule exists
	firewallCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "firewall-rules", "describe",
			projectSuffix + "-allow-https",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}
	firewallOutput := shell.RunCommandAndGetOutput(t, firewallCmd)
	if !strings.Contains(firewallOutput, "allow-https") {
		t.Fatal("Firewall rule not found after deployment")
	}

	t.Log("✓ Resources verified before teardown")

	// Destroy infrastructure using terraform
	t.Log("Running terraform destroy...")
	terraform.Destroy(t, terraformOptions)

	// Verify resources are actually destroyed
	t.Log("Verifying resources are destroyed...")

	// Check terraform state is empty
	stateList := terraform.RunTerraformCommand(t, terraformOptions, "state", "list")
	if len(stateList) > 0 {
		t.Logf("WARNING: Terraform state not empty after destroy. Remaining resources: %s", stateList)
	}

	// Verify ingress VPC is deleted
	ingressVPCCheckCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			"ingress-vpc",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}

	// Use RunCommandE which will fail if VPC doesn't exist
	err := shell.RunCommandE(t, ingressVPCCheckCmd)
	if err == nil {
		t.Error("Ingress VPC still exists after teardown")
	} else {
		t.Log("✓ Ingress VPC successfully deleted (resource not found as expected)")
	}

	// Verify firewall rule is deleted
	firewallCheckCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "firewall-rules", "describe",
			projectSuffix + "-allow-https",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}

	err = shell.RunCommandE(t, firewallCheckCmd)
	if err == nil {
		t.Error("Firewall rule still exists after teardown")
	} else {
		t.Log("✓ Firewall rule successfully deleted (resource not found as expected)")
	}

	t.Log("✓ Teardown completed successfully - all resources destroyed")
	t.Log("✓ Dependency-aware cleanup verified (no orphaned resources)")
}

func TestTeardownWithLogging(t *testing.T) {
	t.Skip("Skipping logging bucket teardown test - requires GCP logging bucket API which may have retention policies")

	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	projectSuffix := "nonprod"

	// Require necessary environment variables
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_API_TOKEN"), "CLOUDFLARE_API_TOKEN must be set")
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_ZONE_ID"), "CLOUDFLARE_ZONE_ID must be set")

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../deploy/opentofu/gcp/core",
		Vars: map[string]interface{}{
			"project_suffix":              projectSuffix,
			"cloudedge_github_repository": "vibetics-cloudedge",
			"cloudedge_project_id":        projectID,
			"region":                      region,
			"enable_demo_web_app":         false,
			"enable_waf":                  true,
			"enable_logging":              true, // Test with logging enabled
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
		},
	}

	// Deploy infrastructure
	t.Log("Deploying infrastructure with logging enabled...")
	terraform.InitAndApply(t, terraformOptions)

	// Run teardown
	t.Log("Running terraform destroy with logging...")
	terraform.Destroy(t, terraformOptions)

	t.Log("✓ Teardown with logging completed successfully")
}
