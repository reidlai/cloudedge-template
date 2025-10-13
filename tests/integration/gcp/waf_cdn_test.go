package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestWafCdnCreation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../../../",

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // TODO: Replace with a valid project ID
			"region":     "us-central1",
		},

		// Targets to apply
		Targets: []string{"module.waf"}, // Assuming WAF and CDN are in the same module for now
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	wafPolicyName := terraform.Output(t, terraformOptions, "waf_policy_name")

	// Verify that the WAF policy was created
	assert.NotEmpty(t, wafPolicyName, "WAF policy name should not be empty")
}
