# ============================================================================
# Firewall Module Outputs
# ============================================================================
# Exports firewall rule information for auditing and compliance
# Referenced by: Root module for security validation and monitoring

output "firewall_rule_name" {
  description = "The name of the HTTPS firewall rule"
  value       = google_compute_firewall.allow_https.name
}

output "firewall_rule_id" {
  description = "The ID of the HTTPS firewall rule"
  value       = google_compute_firewall.allow_https.id
}

output "firewall_rule_self_link" {
  description = "The self-link of the HTTPS firewall rule"
  value       = google_compute_firewall.allow_https.self_link
}
