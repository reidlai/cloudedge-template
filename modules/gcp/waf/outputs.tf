output "waf_policy_name" {
  description = "The name of the WAF security policy."
  value       = google_compute_security_policy.waf_policy.name
}
