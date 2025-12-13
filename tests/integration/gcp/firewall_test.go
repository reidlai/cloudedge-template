package gcp

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestFirewall(t *testing.T) {
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
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify ingress VPC was created
	ingressVPCID := terraform.Output(t, terraformOptions, "ingress_vpc_id")
	assert.NotEmpty(t, ingressVPCID, "Ingress VPC ID should exist")

	// Verify firewall rule exists using gcloud
	firewallRuleName := projectSuffix + "-allow-https"
	firewallCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "firewall-rules", "describe",
			firewallRuleName,
			"--project=" + projectID,
			"--format=value(name)",
		},
	}
	firewallOutput := shell.RunCommandAndGetOutput(t, firewallCmd)
	assert.Contains(t, firewallOutput, firewallRuleName, "Firewall rule should exist")

	t.Logf("✓ Firewall rule created: %s", firewallRuleName)
}
