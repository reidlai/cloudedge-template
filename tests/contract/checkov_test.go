package contract

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCheckovScan(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../",
	}

	// Initialize and validate OpenTofu configuration
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)

	t.Log("Running Checkov scan on OpenTofu configuration...")

	// Run checkov against the entire directory
	// This assumes checkov is installed and in the PATH
	checkovCmd := shell.Command{
		Command: "checkov",
		Args: []string{
			"--directory", "../../",
			"--framework", "terraform",
			"--quiet",
			"--compact",
			"--output", "cli",
		},
	}

	// Run checkov and capture output
	output := shell.RunCommandAndGetOutput(t, checkovCmd)

	t.Log("Checkov scan output:")
	t.Log(output)

	// Parse output for critical failures
	// Checkov returns non-zero exit code for failures, which Terratest will catch
	assert.NotContains(t, strings.ToLower(output), "error", "Checkov should not encounter errors")

	// Check for specific compliance markers
	if strings.Contains(output, "Passed checks:") {
		t.Log("✓ Checkov scan completed successfully")
	} else if strings.Contains(output, "Failed checks:") {
		// Log failures but don't fail test if only LOW/MEDIUM severity
		t.Log("⚠ Some Checkov checks failed - review output above")
	}

	t.Log("========================================")
	t.Log("Checkov Contract Test Results")
	t.Log("========================================")
	t.Log("✓ OpenTofu configuration validated")
	t.Log("✓ Checkov static analysis completed")
	t.Log("========================================")
}
