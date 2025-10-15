package gcp

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpc(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id": projectID,
			"region":     region,
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	ingressVpcName := terraform.Output(t, terraformOptions, "ingress_vpc_name")
	egressVpcName := terraform.Output(t, terraformOptions, "egress_vpc_name")

	assert.NotEmpty(t, ingressVpcName)
	assert.NotEmpty(t, egressVpcName)
}
