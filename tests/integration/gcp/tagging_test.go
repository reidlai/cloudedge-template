package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TestResourceTagging verifies that the resource_tags variable validation works correctly (FR-007)
func TestResourceTagging(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	environment := "nonprod"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id":  projectID,
			"region":      region,
			"environment": environment,
			"resource_tags": map[string]interface{}{
				"environment": environment,
				"managed-by":  "opentofu",
			},
		},
	}

	// Just run plan to verify validation passes
	terraform.InitAndPlan(t, terraformOptions)

	t.Logf("✓ resource_tags validation passed with environment=%s, managed-by=opentofu", environment)
}
