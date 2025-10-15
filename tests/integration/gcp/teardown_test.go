package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTeardown(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"region":     "us-central1",
		},
	}

	terraform.InitAndApply(t, terraformOptions)

	// Run the teardown script
	teardownCmd := shell.Command{
		Command:    "bash",
		Args:       []string{"../../../scripts/teardown.sh"},
		WorkingDir: terraform.GetTerraformDir(t, terraformOptions),
	}
	shell.RunCommand(t, teardownCmd)

	// Verify that the resources are destroyed
	ingressVpcName := terraform.Output(t, terraformOptions, "ingress_vpc_name")
	assert.Empty(t, ingressVpcName, "Ingress VPC should be destroyed")
}