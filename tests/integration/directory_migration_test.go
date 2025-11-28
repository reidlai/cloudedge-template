package integration

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"testing"

	"github.com/cucumber/godog"
)

func TestDirectoryMigration(t *testing.T) {
	opts := godog.Options{
		Format: "pretty",
		Paths:  []string{"../../specs/004-move-all-opentofu/contracts/directory_migration.feature"},
		Tags:   "@integration",
	}

	status := godog.TestSuite{
		Name:                "directory_migration",
		ScenarioInitializer: InitializeMigrationScenario,
		Options:             &opts,
	}.Run()

	if status != 0 {
		t.Fatal("non-zero status returned, failed to run feature tests")
	}
}

// TofuOptions holds common OpenTofu CLI options
type TofuOptions struct {
	TerraformDir  string
	Vars          map[string]string
	BackendConfig []string
	ForceCopy     bool
	Reconfigure   bool
	Upgrade       bool
	NoColor       bool
}

// executeTofuCommand runs a OpenTofu CLI command
func executeTofuCommand(t *testing.T, command string, options *TofuOptions, args ...string) (string, error) {
	t.Helper()

	cmdArgs := []string{command}

	if options != nil {
		if options.Reconfigure {
			cmdArgs = append(cmdArgs, "-reconfigure")
		}
		if options.Upgrade {
			cmdArgs = append(cmdArgs, "-upgrade")
		}
		if options.ForceCopy {
			cmdArgs = append(cmdArgs, "-force-copy")
		}
		if options.NoColor {
			cmdArgs = append(cmdArgs, "-no-color")
		}
		for k, v := range options.Vars {
			cmdArgs = append(cmdArgs, fmt.Sprintf("-var=%s=%s", k, v))
		}
		for _, bc := range options.BackendConfig {
			cmdArgs = append(cmdArgs, fmt.Sprintf("-backend-config=%s", bc))
		}
	}

	cmdArgs = append(cmdArgs, args...)

	cmd := exec.Command("tofu", cmdArgs...)
	if options != nil && options.TerraformDir != "" {
		cmd.Dir = options.TerraformDir
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("Error executing 'tofu %s': %s\nOutput: %s", command, err, string(output))
		return string(output), err
	}

	return string(output), nil
}

// testWorld struct to hold shared context for Cucumber steps
type testWorld struct {
	t                       *testing.T   // For logging in step definitions
	RootPath                string       // Root directory of the repository
	SingletonDir            string       // Path to the project-singleton directory
	EnvironmentDir          string       // Path to the environment-specific directory
	OriginalStateBackupFile string       // Path to the full pre-migration state backup
	SingletonStateFile      string       // Path to the filtered singleton state file
	EnvironmentStateFile    string       // Path to the filtered environment state file
	TofuOptions             *TofuOptions // Current OpenTofu options for commands
	CommandOutput           string       // Output from the last executed command
	CommandError            error        // Error from the last executed command
}

func InitializeMigrationScenario(ctx *godog.ScenarioContext) {
	// Initialize the world struct once per scenario
	world := &testWorld{
		t:                       nil,      // Will be set by godog
		RootPath:                "../../", // Assuming relative to tests/integration
		SingletonDir:            "../../deploy/opentofu/gcp/project-singleton",
		EnvironmentDir:          "../../deploy/opentofu/gcp/environment-specific",
		OriginalStateBackupFile: "../../deploy/opentofu/gcp/full-state-backup.tfstate", // Assuming this is where it lands
		SingletonStateFile:      "",                                                    // Will be set during migration
		EnvironmentStateFile:    "",                                                    // Will be set during migration
	}

	// BeforeScenario runs before each scenario
	ctx.BeforeScenario(func(sc *godog.Scenario) {
		world.TofuOptions = &TofuOptions{
			Vars: make(map[string]string),
			BackendConfig: []string{
				"bucket=vibetics-cloudedge-nonprod-tfstate",
				"prefix=vibetics-cloudedge-nonprod-singleton", // Default for singleton context
			},
			Reconfigure: true,
			Upgrade:     true,
			NoColor:     true,
		}
	})

	// AfterScenario runs after each scenario
	ctx.AfterScenario(func(sc *godog.Scenario, err error) {
		// Clean up any temporary files or states if necessary
		// For now, no specific cleanup, rely on Testify/Godog's test cleanup
	})

	// US3: Private CA Steps
	ctx.Step(`^the Private CA module is deployed$`, world.thePrivateCAModuleIsDeployed)
	ctx.Step(`^I inspect the "([^"]*)" resource$`, world.iInspectTheResource)
	ctx.Step(`^the pool tier should be "([^"]*)"$`, world.thePoolTierShouldBe)
	ctx.Step(`^the pool location should match the region variable$`, world.thePoolLocationShouldMatchRegion)
	ctx.Step(`^the pool should have publishing options enabled for CA cert and CRL$`, world.publishingOptionsEnabled)

	// US3: Load Balancer Steps
	ctx.Step(`^the Private CA module is enabled$`, world.privateCAModuleEnabled)
	ctx.Step(`^I inspect the "([^"]*)" resource for the load balancer$`, world.inspectLBResource)
	ctx.Step(`^the "([^"]*)" field should be set$`, world.fieldShouldBeSet)
	ctx.Step(`^the "([^"]*)" field should be null or empty$`, world.fieldShouldBeNull)
	ctx.Step(`^the certificate map should reference the Private CA managed certificate$`, world.mapReferencesCert)

	// US3: IAM Steps
	ctx.Step(`^the "([^"]*)" variable contains external service accounts$`, world.authorizedUsersVariableSet)
	ctx.Step(`^the role "([^"]*)" should be granted$`, world.roleShouldBeGranted)
	ctx.Step(`^the members list should contain the authorized service accounts$`, world.membersListCheck)
	ctx.Step(`^the binding should be attached to the created CA Pool$`, world.bindingAttachedToPool)
}

// Implementations (Stubs)

func (w *testWorld) thePrivateCAModuleIsDeployed() error {
	return nil
}

func (w *testWorld) iInspectTheResource(resourceName string) error {
	return nil
}

func (w *testWorld) thePoolTierShouldBe(tier string) error {
	return nil
}

func (w *testWorld) thePoolLocationShouldMatchRegion() error {
	return nil
}

func publishingOptionsEnabled() error {
	return nil
}

func privateCAModuleEnabled() error {
	return nil
}

func inspectLBResource(resourceName string) error {
	return nil
}

func fieldShouldBeSet(field string) error {
	return nil
}

func fieldShouldBeNull(field string) error {
	return nil
}

func mapReferencesCert() error {
	return nil
}

func authorizedUsersVariableSet(varName string) error {
	return nil
}

func roleShouldBeGranted(role string) error {
	return nil
}

func membersListCheck() error {
	return nil
}

func bindingAttachedToPool() error {
	return nil
}
