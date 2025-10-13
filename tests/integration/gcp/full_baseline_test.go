package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestFullBaselineDeployment(t *testing.T) {
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

	// Run `terraform output` to get the value of an output variable
	ingressVpcName := terraform.Output(t, terraformOptions, "ingress_vpc_name")
	egressVpcName := terraform.Output(t, terraformOptions, "egress_vpc_name")
	firewallRuleName := terraform.Output(t, terraformOptions, "firewall_rule_name")
	wafPolicyName := terraform.Output(t, terraformOptions, "waf_policy_name")
	lbFrontendIp := terraform.Output(t, terraformOptions, "lb_frontend_ip")
	peering1Name := terraform.Output(t, terraformOptions, "peering1_name")
	peering2Name := terraform.Output(t, terraformOptions, "peering2_name")

	// Verify that all the resources were created
	assert.NotEmpty(t, ingressVpcName, "Ingress VPC name should not be empty")
	assert.NotEmpty(t, egressVpcName, "Egress VPC name should not be empty")
	assert.NotEmpty(t, firewallRuleName, "Firewall rule name should not be empty")
	assert.NotEmpty(t, wafPolicyName, "WAF policy name should not be empty")
	assert.NotEmpty(t, lbFrontendIp, "Load balancer frontend IP should not be empty")
	assert.NotEmpty(t, peering1Name, "Peering 1 name should not be empty")
	assert.NotEmpty(t, peering2Name, "Peering 2 name should not be empty")
}
