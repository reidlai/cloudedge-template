package contract

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestContractCheckov(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../", // Run from the root of the repo

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // TODO: Replace with a valid project ID
			"region":     "us-central1",
		},
	}

	// Run `terraform init`
	terraform.Init(t, terraformOptions)

	// Run `terraform plan` to generate a plan file
	planFilePath := "./tfplan"
	terraform.RunTerraformCommand(t, terraformOptions, terraform.FormatArgs(terraformOptions, "plan", "-out", planFilePath)...)

	// Convert the plan to JSON
	planJSONPath := "./tfplan.json"
	terraform.RunTerraformCommand(t, terraformOptions, "show", "-json", planFilePath, ">", planJSONPath)

	// Run checkov on the JSON plan file
	checkovCmd := shell.Command{
		Command: "checkov",
		Args:    []string{"-f", planJSONPath},
	}

	// Checkov will exit with a non-zero status if there are failing checks.
	// We expect a clean run, so any error here is a test failure.
	_, err := shell.RunCommandAndGetOutputE(t, checkovCmd)
	assert.NoError(t, err, "Checkov found security issues in the Terraform plan.")
}
