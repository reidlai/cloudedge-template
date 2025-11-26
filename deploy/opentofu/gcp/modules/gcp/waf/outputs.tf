# ============================================================================
# WAF Module Outputs
# ============================================================================
# Exports WAF policy information for load balancer security policy attachment
# Referenced by: DR Load Balancer module for DDoS protection and traffic filtering

output "waf_policy_name" {
  description = "The name of the WAF security policy"
  value       = google_compute_security_policy.waf_policy.name
}

output "waf_policy_id" {
  description = "The ID of the WAF security policy"
  value       = google_compute_security_policy.waf_policy.id
}

output "waf_policy_self_link" {
  description = "The self-link of the WAF security policy for backend service attachment"
  value       = google_compute_security_policy.waf_policy.self_link
}
