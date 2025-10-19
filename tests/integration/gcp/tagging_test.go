package gcp

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestMandatoryResourceTagging verifies mandatory tags on all deployed resources (FR-007)
func TestMandatoryResourceTagging(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	environment := "test-tagging"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id":              projectID,
			"region":                  region,
			"environment":             environment,
			"enable_ingress_vpc":      true,
			"enable_egress_vpc":       true,
			"enable_firewall":         true,
			"enable_waf":              true,
			"enable_cdn":              true,
			"enable_dr_loadbalancer":  true,
			"enable_demo_backend":     true,
			"enable_self_signed_cert": true,
			"resource_tags": map[string]interface{}{
				"team":        "infrastructure",
				"cost-center": "engineering",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	t.Log("Verifying mandatory resource tagging per FR-007...")

	// Mandatory tags per constitution and main.tf:32-41
	mandatoryTags := []string{
		"environment",
		"project",
		"managed-by",
	}

	// Test VPC Networks
	t.Log("Checking VPC network tags...")
	ingressVPCCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			environment + "-ingress-vpc",
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
	assert.Contains(t, ingressVPCOutput, "\"environment\": \""+environment+"\"", "environment tag should match deployment")

	t.Log("✓ VPC tagging verified")

	// Test Backend Service
	t.Log("Checking backend service tags...")
	backendServiceCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "backend-services", "describe",
			environment + "-demo-api-backend",
			"--project=" + projectID,
			"--global",
			"--format=json(labels)",
		},
	}
	backendOutput := shell.RunCommandAndGetOutput(t, backendServiceCmd)

	for _, tag := range mandatoryTags {
		assert.Contains(t, backendOutput, "\""+tag+"\"", "Backend service must have tag: "+tag)
	}
	assert.Contains(t, backendOutput, "\"managed-by\": \"opentofu\"", "Backend managed-by should be 'opentofu'")

	t.Log("✓ Backend service tagging verified")

	// Test Cloud Armor Policy
	t.Log("Checking WAF policy tags...")
	wafPolicyCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "security-policies", "describe",
			environment + "-cloud-armor-policy",
			"--project=" + projectID,
			"--format=json(labels)",
		},
	}
	wafOutput := shell.RunCommandAndGetOutput(t, wafPolicyCmd)

	for _, tag := range mandatoryTags {
		assert.Contains(t, wafOutput, "\""+tag+"\"", "WAF policy must have tag: "+tag)
	}

	t.Log("✓ WAF policy tagging verified")

	// Test Cloud Run Service
	t.Log("Checking Cloud Run service tags...")
	cloudRunCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"run", "services", "describe",
			environment + "-demo-api",
			"--project=" + projectID,
			"--region=" + region,
			"--format=json(metadata.labels)",
		},
	}
	cloudRunOutput := shell.RunCommandAndGetOutput(t, cloudRunCmd)

	for _, tag := range mandatoryTags {
		assert.Contains(t, cloudRunOutput, "\""+tag+"\"", "Cloud Run must have tag: "+tag)
	}

	t.Log("✓ Cloud Run service tagging verified")

	// Test custom user-provided tags
	t.Log("Checking user-provided custom tags...")
	assert.Contains(t, backendOutput, "\"team\": \"infrastructure\"", "Custom tag 'team' should be present")
	assert.Contains(t, backendOutput, "\"cost-center\": \"engineering\"", "Custom tag 'cost-center' should exist")

	t.Log("✓ Custom user tags verified")

	// List all tagged resources
	t.Log("Checking tagging coverage across all resources...")
	resourcesCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"asset", "search-all-resources",
			"--project=" + projectID,
			"--filter=labels.environment=" + environment,
			"--format=value(name)",
		},
	}
	resourcesList := shell.RunCommandAndGetOutput(t, resourcesCmd)
	resourceCount := len(strings.Split(strings.TrimSpace(resourcesList), "\n"))

	if resourceCount > 0 {
		t.Logf("✓ Found %d resources with environment tag", resourceCount)
	} else {
		t.Log("⚠ Warning: Asset API may not be enabled or resources not yet indexed")
	}

	// Summary
	t.Log("========================================")
	t.Log("Mandatory Resource Tagging Results")
	t.Log("========================================")
	t.Log("✓ VPCs: All mandatory tags present")
	t.Log("✓ Backend Service: All mandatory tags present")
	t.Log("✓ WAF Policy: All mandatory tags present")
	t.Log("✓ Cloud Run: All mandatory tags present")
	t.Log("✓ Custom Tags: User-provided tags applied")
	t.Log("========================================")
	t.Log("Tagging Compliance: PASSED (FR-007)")
	t.Log("========================================")
}
