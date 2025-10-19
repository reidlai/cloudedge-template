# ============================================================================
# Billing Module Outputs
# ============================================================================
# Exports billing budget information for monitoring and reference
# Referenced by: Root module for budget tracking and alerts

output "budget_id" {
  description = "The ID of the billing budget resource"
  value       = google_billing_budget.budget.id
}

output "budget_name" {
  description = "The display name of the billing budget"
  value       = google_billing_budget.budget.display_name
}

output "budget_amount" {
  description = "The configured budget amount in currency units"
  value       = google_billing_budget.budget.amount[0].specified_amount[0].units
}

output "budget_currency" {
  description = "The currency code for the budget"
  value       = google_billing_budget.budget.amount[0].specified_amount[0].currency_code
}
