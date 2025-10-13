output "firewall_rule_name" {
  description = "The name of the firewall rule."
  value       = google_compute_firewall.allow_http.name
}