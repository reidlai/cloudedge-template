package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFullBaseline(t *testing.T) {
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

	ingressVpcName := terraform.Output(t, terraformOptions, "ingress_vpc_name")
	egressVpcName := terraform.Output(t, terraformOptions, "egress_vpc_name")
	firewallRuleName := terraform.Output(t, terraformOptions, "firewall_rule_name")
	wafPolicyName := terraform.Output(t, terraformOptions, "waf_policy_name")
	lbFrontendIp := terraform.Output(t, terraformOptions, "lb_frontend_ip")
	peering1Name := terraform.Output(t, terraformOptions, "peering1_name")
	peering2Name := terraform.Output(t, terraformOptions, "peering2_name")

	assert.NotEmpty(t, ingressVpcName)
	assert.NotEmpty(t, egressVpcName)
	assert.NotEmpty(t, firewallRuleName)
	assert.NotEmpty(t, wafPolicyName)
	assert.NotEmpty(t, lbFrontendIp)
	assert.NotEmpty(t, peering1Name)
	assert.NotEmpty(t, peering2Name)
}
