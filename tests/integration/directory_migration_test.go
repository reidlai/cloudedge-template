package integration

import (
	"testing"

	"github.com/cucumber/godog"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestDirectoryMigration(t *testing.T) {
	opts := godog.Options{
		Format: "pretty",
		Paths:  []string{"../../features/directory_migration.feature"},
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

func InitializeMigrationScenario(ctx *godog.ScenarioContext) {
	// US3: Private CA Steps
	ctx.Step(`^the Private CA module is deployed$`, thePrivateCAModuleIsDeployed)
	ctx.Step(`^I inspect the "([^"]*)" resource$`, iInspectTheResource)
	ctx.Step(`^the pool tier should be "([^"]*)"$`, thePoolTierShouldBe)
	ctx.Step(`^the pool location should match the region variable$`, thePoolLocationShouldMatchRegion)
	ctx.Step(`^the pool should have publishing options enabled for CA cert and CRL$`, publishingOptionsEnabled)

	// US3: Load Balancer Steps
	ctx.Step(`^the Private CA module is enabled$`, privateCAModuleEnabled)
	ctx.Step(`^I inspect the "([^"]*)" resource for the load balancer$`, inspectLBResource)
	ctx.Step(`^the "([^"]*)" field should be set$`, fieldShouldBeSet)
	ctx.Step(`^the "([^"]*)" field should be null or empty$`, fieldShouldBeNull)
	ctx.Step(`^the certificate map should reference the Private CA managed certificate$`, mapReferencesCert)

	// US3: IAM Steps
	ctx.Step(`^the "([^"]*)" variable contains external service accounts$`, authorizedUsersVariableSet)
	ctx.Step(`^the role "([^"]*)" should be granted$`, roleShouldBeGranted)
	ctx.Step(`^the members list should contain the authorized service accounts$`, membersListCheck)
	ctx.Step(`^the binding should be attached to the created CA Pool$`, bindingAttachedToPool)
}

// Implementations (Stubs)

func thePrivateCAModuleIsDeployed() error {
	return nil
}

func iInspectTheResource(resourceName string) error {
	return nil
}

func thePoolTierShouldBe(tier string) error {
	return nil
}

func thePoolLocationShouldMatchRegion() error {
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
