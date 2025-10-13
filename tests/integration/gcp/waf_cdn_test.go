package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestWafCdn(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // Replace with your GCP project ID
			"region":     "us-central1",
		},
		Targets: []string{"module.waf"},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	wafPolicyName := terraform.Output(t, terraformOptions, "waf_policy_name")

	assert.NotEmpty(t, wafPolicyName, "WAF policy name should not be empty")
}