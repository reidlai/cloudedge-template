config {
  call_module_type = "all"
  force = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

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
