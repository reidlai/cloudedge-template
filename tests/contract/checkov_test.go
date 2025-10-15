package contract

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCheckovScan(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
	}

	// Run `terraform init` and `terraform plan` and save the plan to a file
	planFilePath := terraform.InitAndPlan(t, terraformOptions)

	// Run checkov on the plan file
	// This assumes checkov is installed and in the PATH
	// You may need to customize the command to fit your environment
	options := &terraform.Options{
		TerraformDir: "../../",
		PlanFilePath: planFilePath,
	}
	checkovResult := terraform.RunCheckov(t, options)

	// For this example, we'll just assert that the command ran without error
	// In a real-world scenario, you would parse the output and assert on specific checks
	assert.NoError(t, checkovResult)
}
