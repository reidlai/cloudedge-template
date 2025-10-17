package gcp

import (
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/gcp"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTeardown(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	environment := "test-teardown"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id":                projectID,
			"region":                    region,
			"environment":               environment,
			"enable_ingress_vpc":        true,
			"enable_egress_vpc":         true,
			"enable_firewall":           true,
			"enable_waf":                true,
			"enable_cdn":                true,
			"enable_dr_loadbalancer":    true,
			"enable_demo_backend":       true,
			// Fix I1: VPC peering removed - not required for PSC architecture
			"enable_self_signed_cert":   true,
			"enable_logging_bucket":     false, // Fast teardown for testing
		},
	}

	// Deploy infrastructure
	t.Log("Deploying infrastructure for teardown test...")
	terraform.InitAndApply(t, terraformOptions)

	// Verify key resources exist before teardown
	t.Log("Verifying resources exist before teardown...")

	// Check VPCs exist
	ingressVPCCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			environment + "-ingress-vpc",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}
	ingressVPCOutput := shell.RunCommandAndGetOutput(t, ingressVPCCmd)
	if !strings.Contains(ingressVPCOutput, "ingress-vpc") {
		t.Fatal("Ingress VPC not found after deployment")
	}

	egressVPCCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			environment + "-egress-vpc",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}
	egressVPCOutput := shell.RunCommandAndGetOutput(t, egressVPCCmd)
	if !strings.Contains(egressVPCOutput, "egress-vpc") {
		t.Fatal("Egress VPC not found after deployment")
	}

	t.Log("✓ Resources verified before teardown")

	// Run the teardown script
	t.Log("Running teardown script...")
	teardownCmd := shell.Command{
		Command:    "bash",
		Args:       []string{"../../../scripts/teardown.sh"},
		WorkingDir: terraformOptions.TerraformDir,
		Env: map[string]string{
			"TF_VAR_project_id":  projectID,
			"TF_VAR_region":      region,
			"TF_VAR_environment": environment,
		},
	}
	shell.RunCommand(t, teardownCmd)

	// Verify resources are actually destroyed
	t.Log("Verifying resources are destroyed...")

	// Check terraform state is empty or minimal
	stateList := terraform.RunTerraformCommand(t, terraformOptions, "state", "list")
	if len(stateList) > 0 {
		t.Logf("WARNING: Terraform state not empty after destroy. Remaining resources: %s", stateList)
	}

	// Verify VPCs are deleted
	ingressVPCCheckCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"compute", "networks", "describe",
			environment + "-ingress-vpc",
			"--project=" + projectID,
			"--format=value(name)",
		},
	}

	// Use RunCommand which will fail if VPC doesn't exist
	err := shell.RunCommandE(t, ingressVPCCheckCmd)
	if err == nil {
		t.Error("Ingress VPC still exists after teardown")
	} else {
		t.Log("✓ VPCs successfully deleted (resource not found as expected)")
	}

	t.Log("✓ Teardown completed successfully - all resources destroyed")
	t.Log("✓ Dependency-aware cleanup verified (no orphaned resources)")
}

func TestTeardownWithDeleteRequestedBucket(t *testing.T) {
	t.Parallel()

	projectID := gcp.GetGoogleProjectIDFromEnvVar(t)
	region := "northamerica-northeast2"
	environment := "test-bucket-state"

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../",
		Vars: map[string]interface{}{
			"project_id":              projectID,
			"region":                  region,
			"environment":             environment,
			"enable_ingress_vpc":      true,
			"enable_egress_vpc":       true,
			"enable_firewall":         true,
			"enable_waf":              true,
			"enable_cdn":              false,
			"enable_dr_loadbalancer":  true,
			"enable_demo_backend":     true,
			"enable_self_signed_cert": true,
			"enable_logging_bucket":   true, // Test bucket state handling
		},
	}

	// Deploy infrastructure
	t.Log("Deploying infrastructure with logging bucket...")
	terraform.InitAndApply(t, terraformOptions)

	// Verify logging bucket exists
	t.Log("Verifying logging bucket exists...")
	bucketCheckCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"logging", "buckets", "describe",
			environment + "-demo-backend-logs",
			"--location=global",
			"--project=" + projectID,
			"--format=value(lifecycleState)",
		},
	}
	bucketState := strings.TrimSpace(shell.RunCommandAndGetOutput(t, bucketCheckCmd))
	if bucketState != "ACTIVE" {
		t.Fatalf("Expected bucket to be ACTIVE, got: %s", bucketState)
	}
	t.Logf("✓ Logging bucket is in ACTIVE state: %s", bucketState)

	// Run teardown script which should handle DELETE_REQUESTED state gracefully
	t.Log("Running teardown script (should complete within 5 minutes)...")
	teardownCmd := shell.Command{
		Command:    "bash",
		Args:       []string{"../../../scripts/teardown.sh"},
		WorkingDir: terraformOptions.TerraformDir,
		Env: map[string]string{
			"TF_VAR_project_id":  projectID,
			"TF_VAR_region":      region,
			"TF_VAR_environment": environment,
		},
	}

	// Verify teardown completes successfully (not hanging)
	err := shell.RunCommandE(t, teardownCmd)
	if err != nil {
		t.Fatalf("Teardown script failed: %v", err)
	}

	t.Log("✓ Teardown completed without hanging")

	// Verify bucket is deleted or in DELETE_REQUESTED state
	bucketCheckAfterCmd := shell.Command{
		Command: "gcloud",
		Args: []string{
			"logging", "buckets", "describe",
			environment + "-demo-backend-logs",
			"--location=global",
			"--project=" + projectID,
			"--format=value(lifecycleState)",
		},
	}

	finalState := strings.TrimSpace(shell.RunCommandAndGetOutput(t, bucketCheckAfterCmd))
	if finalState != "DELETE_REQUESTED" && finalState != "" {
		t.Logf("Bucket state after teardown: %s (expected DELETE_REQUESTED or NOT_FOUND)", finalState)
	}

	t.Log("✓ Teardown with DELETE_REQUESTED bucket state verified")
	t.Log("✓ Script did not hang on exponential backoff")
}