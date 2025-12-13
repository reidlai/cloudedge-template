package gcp

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDemoWebApp(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"

	// Require necessary environment variables
	require.NotEmpty(t, projectID, "GCP Project ID must be set")

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../deploy/opentofu/gcp/demo-web-app",
		Vars: map[string]interface{}{
			"project_suffix":                   "nonprod",
			"cloudedge_github_repository":      "vibetics-cloudedge",
			"cloudedge_project_id":             projectID,
			"demo_web_app_project_id":          projectID,
			"region":                           region,
			"enable_demo_web_app":              true,
			"demo_web_app_image":               "us-docker.pkg.dev/cloudrun/container/hello",
			"enable_demo_web_app_psc_neg":      false,
			"enable_demo_web_app_internal_alb": true,
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify demo web app outputs
	webAppServiceName := terraform.Output(t, terraformOptions, "web_app_cloud_run_service_name")
	webAppBackendID := terraform.Output(t, terraformOptions, "web_app_backend_service_id")

	assert.NotEmpty(t, webAppServiceName, "Demo web app service name should exist")
	assert.NotEmpty(t, webAppBackendID, "Demo web app backend service ID should exist")

	t.Logf("✓ Demo web app Cloud Run service created: %s", webAppServiceName)
	t.Logf("✓ Demo web app backend service created: %s", webAppBackendID)
}
