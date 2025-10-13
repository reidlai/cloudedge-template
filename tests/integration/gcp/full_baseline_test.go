package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFullBaseline(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // Replace with your GCP project ID
			"region":     "us-central1",
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	outputs := terraform.OutputAll(t, terraformOptions)
	assert.NotEmpty(t, outputs["ingress_vpc_name"], "Ingress VPC name should not be empty")
	assert.NotEmpty(t, outputs["egress_vpc_name"], "Egress VPC name should not be empty")
	assert.NotEmpty(t, outputs["firewall_rule_name"], "Firewall rule name should not be empty")
	assert.NotEmpty(t, outputs["waf_policy_name"], "WAF policy name should not be empty")
	assert.NotEmpty(t, outputs["lb_frontend_ip"], "Load balancer IP should not be empty")
	assert.NotEmpty(t, outputs["peering1_name"], "Peering 1 name should not be empty")
	assert.NotEmpty(t, outputs["peering2_name"], "Peering 2 name should not be empty")
}