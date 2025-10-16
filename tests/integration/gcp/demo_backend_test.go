package gcp

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestDemoBackend(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	backendServiceID := terraform.Output(t, terraformOptions, "demo_backend_service_id")
	assert.NotEmpty(t, backendServiceID)

	lbIpAddress := terraform.Output(t, terraformOptions, "lb_frontend_ip")
	assert.NotEmpty(t, lbIpAddress)

	url := fmt.Sprintf("https://%s", lbIpAddress)

	// It can take a few minutes for the load balancer to be fully provisioned.
	// Retry the request until we get a 200 OK response.
	http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello from Cloud Run", 30, 5*time.Second)
}
