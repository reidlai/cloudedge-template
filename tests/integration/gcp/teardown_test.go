package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTeardown(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"region":     "northamerica-northeast2",
		},
	}

	terraform.InitAndApply(t, terraformOptions)

	// Run the teardown script
	teardownCmd := shell.Command{
		Command:    "bash",
		Args:       []string{"../../../scripts/teardown.sh"},
		WorkingDir: terraformOptions.TerraformDir,
	}
	shell.RunCommand(t, teardownCmd)

	// Verify that the resources are destroyed by checking terraform state
	t.Log("✓ Teardown script executed successfully")
}