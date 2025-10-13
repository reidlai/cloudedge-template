package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTeardownScript(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../../",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // TODO: Replace with a valid project ID
			"region":     "us-central1",
		},
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run the teardown script
	teardownCmd := shell.Command{
		Command:    "../../../scripts/teardown.sh",
		WorkingDir: terraform.GetTerraformDir(t, terraformOptions),
	}
	shell.RunCommand(t, teardownCmd)

	// To verify teardown, we can try to read an output variable, which should now fail.
	_, err := terraform.OutputE(t, terraformOptions, "ingress_vpc_name")
	assert.Error(t, err, "Expected an error when reading output after destroy, but got none")
}
