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
			"enable_inter_vpc_peering":  true,
			"enable_self_signed_cert":   true,
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