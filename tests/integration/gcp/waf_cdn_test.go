package gcp

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestWafCdn(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "us-central1"

	// Require necessary environment variables
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_API_TOKEN"), "CLOUDFLARE_API_TOKEN must be set")
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_ZONE_ID"), "CLOUDFLARE_ZONE_ID must be set")

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../deploy/opentofu/gcp/core",
		Vars: map[string]interface{}{
			"project_suffix":              "nonprod",
			"cloudedge_github_repository": "vibetics-cloudedge",
			"cloudedge_project_id":        projectID,
			"region":                      region,
			"enable_waf":                  true, // Enable Cloud Armor WAF
			"enable_demo_web_app":         false,
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify WAF policy ID output exists
	wafPolicyID := terraform.Output(t, terraformOptions, "waf_policy_id")
	assert.NotEmpty(t, wafPolicyID, "WAF policy ID should be present when enable_waf=true")

	// Verify Cloud Armor is enabled
	cloudArmorEnabled := terraform.Output(t, terraformOptions, "cloud_armor_enabled")
	assert.Equal(t, "true", cloudArmorEnabled, "Cloud Armor should be enabled")

	t.Logf("✓ WAF policy created: %s", wafPolicyID)
}
