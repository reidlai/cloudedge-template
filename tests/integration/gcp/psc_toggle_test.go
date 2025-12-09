package gcp_test

import (
	"fmt"
	"os"
	// Re-adding for potential use or for consistency with other files
	"testing"
	// Re-adding for potential use or for consistency with other files

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	compute "google.golang.org/api/compute/v1" // Import for GCP Compute API
)

func TestPSCToggle(t *testing.T) {
	t.Parallel()

	// Define the path to the root of your OpenTofu modules
	fixturePath := "./../.."

	// Generate a unique suffix for resource names to avoid conflicts
	projectSuffix := random.UniqueId()
	projectId := fmt.Sprintf("gcp-proj-%s", projectSuffix)
	// Get project ID from environment variables, fallback to generated
	gcpProjectId := os.Getenv("GOOGLE_CLOUD_PROJECT")
	if gcpProjectId == "" {
		gcpProjectId = os.Getenv("GOOGLE_PROJECT")
	}
	if gcpProjectId == "" {
		gcpProjectId = projectId // Use generated if env vars not set, though this may fail if project doesn't exist.
	}

	// Define common module variables for core and demo-vpc modules
	baseModuleVars := map[string]interface{}{
		"project_suffix":              projectSuffix,
		"cloudedge_github_repository": "vibetics",                        // Placeholder value, adjust if needed
		"cloudflare_api_token":        os.Getenv("CLOUDFLARE_API_TOKEN"), // Ensure this env var is set for tests
		"project_id":                  gcpProjectId,
	}

	// Make sure these environment variables are set for GCP authentication
	require.NotEmpty(t, os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"), "GOOGLE_APPLICATION_CREDENTIALS must be set")
	require.NotEmpty(t, os.Getenv("CLOUDFLARE_API_TOKEN"), "CLOUDFLARE_API_TOKEN must be set")

	// Initialize GCP Compute Service client for direct API calls
	computeService, err := gcp.NewComputeServiceE(t)
	require.NoError(t, err, "Failed to initialize GCP Compute Service client")

	// -----------------------------------------------------------------------------------------------------------------
	// T002: TestPSCEnabledByDefaultCore - Ensure PSC is enabled by default in the core module
	// -----------------------------------------------------------------------------------------------------------------
	test_structure.RunTestStage(t, "core_enabled_setup", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/core", fixturePath)
		tempTerraformDir := test_structure.CopyTerraformFolderToTemp(t, terraformDir, fmt.Sprintf("core-enabled-%s", projectSuffix))

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: tempTerraformDir,
			Vars:         baseModuleVars,
		})
		test_structure.SaveTerraformOptions(t, tempTerraformDir, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "core_enabled_validate", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/core", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)

		// Get the PSC enabled output
		pscEnabled := terraform.Output(t, terraformOptions, "psc_enabled")
		assert.Equal(t, "true", pscEnabled)

		// Verify the PSC NEG resource exists using GCP Go SDK
		pscNegName := "demo-web-app-psc-neg" // As per core.tf
		region := "us-central1"              // Hardcoded region for testing. In a real scenario, this would come from a test var or output. // Use gcp.GetRegion
		_, err := computeService.NetworkEndpointGroups.Get(gcpProjectId, region, pscNegName).Do()
		assert.NoError(t, err, "PSC NEG should exist when PSC is enabled by default")
	})

	test_structure.RunTestStage(t, "core_enabled_teardown", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/core", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)
		terraform.Destroy(t, terraformOptions)
		test_structure.CleanupTestDataFolder(t, terraformOptions.TerraformDir)
	})

	// -----------------------------------------------------------------------------------------------------------------
	// T003: TestPSCDisabledCore - Ensure PSC can be disabled in the core module
	// -----------------------------------------------------------------------------------------------------------------
	test_structure.RunTestStage(t, "core_disabled_setup", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/core", fixturePath)
		tempTerraformDir := test_structure.CopyTerraformFolderToTemp(t, terraformDir, fmt.Sprintf("core-disabled-%s", projectSuffix))

		disabledModuleVars := map[string]interface{}{}
		for k, v := range baseModuleVars {
			disabledModuleVars[k] = v
		}
		disabledModuleVars["enable_psc"] = false

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: tempTerraformDir,
			Vars:         disabledModuleVars,
		})
		test_structure.SaveTerraformOptions(t, tempTerraformDir, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "core_disabled_validate", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/core", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)

		// Get the PSC enabled output
		pscEnabled := terraform.Output(t, terraformOptions, "psc_enabled")
		assert.Equal(t, "false", pscEnabled)

		// Verify the PSC NEG resource does NOT exist using GCP Go SDK
		pscNegName := "demo-web-app-psc-neg"
		region := "us-central1" // Hardcoded region for testing. In a real scenario, this would come from a test var or output.
		_, err := computeService.NetworkEndpointGroups.Get(gcpProjectId, region, pscNegName).Do()
		assert.Error(t, err, "PSC NEG should NOT exist when PSC is explicitly disabled")
		require.Contains(t, err.Error(), "was not found", "Error message should indicate resource not found")
	})

	test_structure.RunTestStage(t, "core_disabled_teardown", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/core", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)
		terraform.Destroy(t, terraformOptions)
		test_structure.CleanupTestDataFolder(t, terraformOptions.TerraformDir)
	})

	// -----------------------------------------------------------------------------------------------------------------
	// T004: TestPSCEnabledByDefaultDemoVPC - Ensure PSC is enabled by default in the demo-vpc module
	// -----------------------------------------------------------------------------------------------------------------
	test_structure.RunTestStage(t, "demo_vpc_enabled_setup", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/demo-vpc", fixturePath)
		tempTerraformDir := test_structure.CopyTerraformFolderToTemp(t, terraformDir, fmt.Sprintf("demovpc-enabled-%s", projectSuffix))

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: tempTerraformDir,
			Vars:         baseModuleVars,
		})
		test_structure.SaveTerraformOptions(t, tempTerraformDir, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "demo_vpc_enabled_validate", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/demo-vpc", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)

		// Get the PSC enabled output
		pscEnabled := terraform.Output(t, terraformOptions, "psc_enabled")
		assert.Equal(t, "true", pscEnabled)

		// Verify the PSC Service Attachment resource exists using GCP Go SDK
		pscAttachmentName := "demo-web-app-psc-attachment" // As per demo-vpc.tf
		region := "us-central1"                            // Hardcoded region for testing. In a real scenario, this would come from a test var or output.
		_, err := computeService.ServiceAttachments.Get(gcpProjectId, region, pscAttachmentName).Do()
		assert.NoError(t, err, "PSC Service Attachment should exist when PSC is enabled by default")
	})

	test_structure.RunTestStage(t, "demo_vpc_enabled_teardown", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/demo-vpc", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)
		terraform.Destroy(t, terraformOptions)
		test_structure.CleanupTestDataFolder(t, terraformOptions.TerraformDir)
	})

	// -----------------------------------------------------------------------------------------------------------------
	// T005: TestPSCDisabledDemoVPC - Ensure PSC can be disabled in the demo-vpc module
	// -----------------------------------------------------------------------------------------------------------------
	test_structure.RunTestStage(t, "demo_vpc_disabled_setup", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/demo-vpc", fixturePath)
		tempTerraformDir := test_structure.CopyTerraformFolderToTemp(t, terraformDir, fmt.Sprintf("demovpc-disabled-%s", projectSuffix))

		disabledModuleVars := map[string]interface{}{}
		for k, v := range baseModuleVars {
			disabledModuleVars[k] = v
		}
		disabledModuleVars["enable_psc"] = false

		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			TerraformDir: tempTerraformDir,
			Vars:         disabledModuleVars,
		})
		test_structure.SaveTerraformOptions(t, tempTerraformDir, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "demo_vpc_disabled_validate", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/demo-vpc", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)

		// Get the PSC enabled output
		pscEnabled := terraform.Output(t, terraformOptions, "psc_enabled")
		assert.Equal(t, "false", pscEnabled)

		// Verify the PSC Service Attachment resource does NOT exist using GCP Go SDK
		pscAttachmentName := "demo-web-app-psc-attachment"
		region := "us-central1" // Hardcoded region for testing. In a real scenario, this would come from a test var or output.
		_, err := computeService.ServiceAttachments.Get(gcpProjectId, region, pscAttachmentName).Do()
		assert.Error(t, err, "PSC Service Attachment should NOT exist when PSC is explicitly disabled")
		require.Contains(t, err.Error(), "was not found", "Error message should indicate resource not found")
	})

	test_structure.RunTestStage(t, "demo_vpc_disabled_teardown", func() {
		terraformDir := fmt.Sprintf("%s/deploy/opentofu/gcp/demo-vpc", fixturePath)
		terraformOptions := test_structure.LoadTerraformOptions(t, terraformDir)
		terraform.Destroy(t, terraformOptions)
		test_structure.CleanupTestDataFolder(t, terraformOptions.TerraformDir)
	})
}
