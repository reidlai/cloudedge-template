package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFirewall(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // Replace with your GCP project ID
			"region":     "us-central1",
		},
		Targets: []string{"module.firewall"},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	firewallRuleName := terraform.Output(t, terraformOptions, "firewall_rule_name")

	assert.NotEmpty(t, firewallRuleName, "Firewall rule name should not be empty")
}