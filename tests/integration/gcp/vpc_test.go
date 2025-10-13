package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpc(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
		Vars: map[string]interface{}{
			"project_id": "your-gcp-project-id", // Replace with your GCP project ID
			"region":     "us-central1",
		},
		Targets: []string{"module.ingress_vpc", "module.egress_vpc"},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ingressVpcName := terraform.Output(t, terraformOptions, "ingress_vpc_name")
	egressVpcName := terraform.Output(t, terraformOptions, "egress_vpc_name")

	assert.NotEmpty(t, ingressVpcName, "Ingress VPC name should not be empty")
	assert.NotEmpty(t, egressVpcName, "Egress VPC name should not be empty")
}