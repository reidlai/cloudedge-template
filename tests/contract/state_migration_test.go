package contract

import (
	"testing"

	"github.com/cucumber/godog"
)

func TestStateMigrationContract(t *testing.T) {
	opts := godog.Options{
		Format: "pretty",
		Paths:  []string{"../../features/directory_migration.feature"},
		Tags:   "@contract",
	}

	status := godog.TestSuite{
		Name:                "state_migration_contract",
		ScenarioInitializer: InitializeContractScenario,
		Options:             &opts,
	}.Run()

	if status != 0 {
		t.Fatal("non-zero status returned, failed to run feature tests")
	}
}

func InitializeContractScenario(ctx *godog.ScenarioContext) {
	ctx.Step(`^the original "([^"]*)" file contains:$`, originalFileContains)
	ctx.Step(`^I execute the directory migration process$`, executeMigration)
	ctx.Step(`^the "([^"]*)" in "([^"]*)" should contain:$`, migratedFileContains)
	ctx.Step(`^the backend configuration should be syntactically valid$`, backendConfigValid)
}

// Implementations (Stubs)

func originalFileContains(filename string, content *godog.DocString) error {
	return nil
}

func executeMigration() error {
	return nil
}

func migratedFileContains(filename, path string, content *godog.DocString) error {
	return nil
}

func backendConfigValid() error {
	return nil
}
