# TFLint Configuration
# OpenTofu/Terraform linting configuration
# Referenced by: pre-commit-config.yaml (ci-format-lint gate)
#
# Documentation: https://github.com/terraform-linters/tflint/tree/master/docs

config {
  # Module inspection setting
  call_module_type = "all"  # Inspect all modules (local and remote)

  # Force flag (override errors)
  force = false

  # Disable plugin discovery
  plugin_dir = "~/.tflint.d/plugins"

  # Disable colors in output (for CI/CD)
  # color = false
}

# ============================================================================
# Core Terraform Plugin
# ============================================================================
plugin "terraform" {
  enabled = true
  preset  = "recommended"
  version = "0.5.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# ============================================================================
# GCP Plugin (for GCP-specific rules)
# ============================================================================
plugin "google" {
  enabled = true
  version = "0.27.1"
  source  = "github.com/terraform-linters/tflint-ruleset-google"

  # Deep check (queries GCP API to validate resources)
  # Set to false for faster local checks, enable in CI
  deep_check = false
}

# ============================================================================
# Terraform Core Rules
# ============================================================================

# Suppress warnings about terraform required_version in modules
# Provider inheritance from root module is sufficient
rule "terraform_required_version" {
  enabled = false
}

# Suppress warnings about missing required_providers in modules
# Providers are defined in root main.tf and inherited by modules
rule "terraform_required_providers" {
  enabled = false
}

# Suppress warnings about unused variable declarations
# Variables may be reserved for future multi-cloud implementation
rule "terraform_unused_declarations" {
  enabled = false
}

# Ensure variable descriptions are present
rule "terraform_documented_variables" {
  enabled = true
}

# Ensure output descriptions are present
rule "terraform_documented_outputs" {
  enabled = true
}

# Check for module version pinning
rule "terraform_module_pinned_source" {
  enabled = true
  style   = "semver"  # Use semantic versioning
}

# Naming conventions
rule "terraform_naming_convention" {
  enabled = true

  # Resource naming: snake_case
  resource {
    format = "snake_case"
  }

  # Variable naming: snake_case
  variable {
    format = "snake_case"
  }

  # Output naming: snake_case
  output {
    format = "snake_case"
  }

  # Module naming: snake_case
  module {
    format = "snake_case"
  }

  # Data source naming: snake_case
  data {
    format = "snake_case"
  }

  # Local value naming: snake_case
  locals {
    format = "snake_case"
  }
}

# Standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}

# Type constraints for variables
rule "terraform_typed_variables" {
  enabled = true
}

# Workspace remote check
rule "terraform_workspace_remote" {
  enabled = false  # We use local workspaces
}

# ============================================================================
# GCP-Specific Rules
# ============================================================================

# Check for valid GCP regions
rule "google_compute_instance_invalid_machine_type" {
  enabled = true
}

# ============================================================================
# Custom Rule Overrides
# ============================================================================

# Allow terraform_deprecated_index (for compatibility)
rule "terraform_deprecated_index" {
  enabled = false
}

# Allow terraform_deprecated_interpolation (for compatibility)
rule "terraform_deprecated_interpolation" {
  enabled = false
}

# Warn on sensitive variable default values (rule removed in newer versions)
# rule "terraform_sensitive_variable_no_default" {
#   enabled = true
# }

# ============================================================================
# Ignored Files/Directories
# ============================================================================
# Configured via .tflintignore file or --ignore-module flag
