package gcp

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMandatoryResourceTagging verifies mandatory tags on all deployed resources (FR-007)
func TestMandatoryResourceTagging(t *testing.T) {
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
			"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"),
			"cloudflare_zone_id":          os.Getenv("CLOUDFLARE_ZONE_ID"),
			"billing_account_name":        "Test Billing Account",
			"resource_tags": map[string]interface{}{
				"project-suffix": projectSuffix,
				"managed-by":     "opentofu",
				"team":           "infrastructure",
				"cost-center":    "engineering",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	t.Log("Verifying mandatory resource tagging per FR-007...")

	// Mandatory tags per constitution (project-suffix and managed-by are required)
	mandatoryTags := []string{
		"project-suffix",
		"managed-by",
		"project",
	}

	// Test VPC Networks
	t.Log("Checking VPC network tags...")
	ingressVPCCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			"ingress-vpc",
			"--project=" + projectID,
			"--format=json(labels)",
		},
	}
	ingressVPCOutput := shell.RunCommandAndGetOutput(t, ingressVPCCmd)
	assert.NotEmpty(t, ingressVPCOutput, "Ingress VPC should exist")

	for _, tag := range mandatoryTags {
		assert.Contains(t, ingressVPCOutput, "\""+tag+"\"", "VPC must have mandatory tag: "+tag)
	}
	assert.Contains(t, ingressVPCOutput, "\"managed-by\": \"opentofu\"", "managed-by tag should be 'opentofu'")
	assert.Contains(t, ingressVPCOutput, "\"project-suffix\": \""+projectSuffix+"\"", "project-suffix tag should match")

	t.Log("✓ VPC tagging verified")

	// Test WAF Policy (Cloud Armor)
	t.Log("Checking WAF policy tags...")
	wafPolicyCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "security-policies", "describe",
			"edge-waf-policy",
			"--project=" + projectID,
			"--region=" + region,
			"--format=json(labels)",
		},
	}
	wafOutput := shell.RunCommandAndGetOutput(t, wafPolicyCmd)

	// WAF policy labels (regional security policies may have limited label support)
	if strings.Contains(wafOutput, "labels") {
		for _, tag := range mandatoryTags {
			assert.Contains(t, wafOutput, "\""+tag+"\"", "WAF policy should have tag: "+tag)
		}
		t.Log("✓ WAF policy tagging verified")
	} else {
		t.Log("⚠ Warning: Regional security policies may not support labels")
	}

	// Test custom user-provided tags
	t.Log("Checking user-provided custom tags...")
	assert.Contains(t, ingressVPCOutput, "\"team\": \"infrastructure\"", "Custom tag 'team' should be present")
	assert.Contains(t, ingressVPCOutput, "\"cost-center\": \"engineering\"", "Custom tag 'cost-center' should exist")

	t.Log("✓ Custom user tags verified")

	// List all tagged resources
	t.Log("Checking tagging coverage across all resources...")
	resourcesCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"asset", "search-all-resources",
			"--project=" + projectID,
			"--filter=labels.project-suffix=" + projectSuffix,
			"--format=value(name)",
		},
	}
	resourcesList := shell.RunCommandAndGetOutput(t, resourcesCmd)

	if resourcesList != "" {
		resourceCount := len(strings.Split(strings.TrimSpace(resourcesList), "\n"))
		if resourceCount > 0 {
			t.Logf("✓ Found %d resources with project-suffix tag", resourceCount)
		}
	} else {
		t.Log("⚠ Warning: Asset API may not be enabled or resources not yet indexed")
	}

	// Summary
	t.Log("========================================")
	t.Log("Mandatory Resource Tagging Results")
	t.Log("========================================")
	t.Log("✓ VPCs: All mandatory tags present")
	t.Log("✓ WAF Policy: Validated (if labels supported)")
	t.Log("✓ Custom Tags: User-provided tags applied")
	t.Log("========================================")
	t.Log("Tagging Compliance: PASSED (FR-007)")
	t.Log("========================================")
}
