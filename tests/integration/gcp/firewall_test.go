package gcp

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFirewall(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"region":     "us-central1",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	firewallRuleName := terraform.Output(t, terraformOptions, "firewall_rule_name")
	assert.NotEmpty(t, firewallRuleName)

	firewallRule := gcp.GetComputeFirewallRule(t, projectID, firewallRuleName)
	assert.Equal(t, firewallRuleName, firewallRule.Name)
	assert.Contains(t, firewallRule.TargetTags, "http-server")
	assert.Contains(t, firewallRule.SourceRanges, "0.0.0.0/0")
}
