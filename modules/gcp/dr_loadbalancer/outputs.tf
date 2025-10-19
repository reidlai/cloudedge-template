# ============================================================================
# DR Load Balancer Module Outputs
# ============================================================================
# Exports load balancer frontend IP and configuration details
# Referenced by: Root module for DNS configuration and external access

output "lb_frontend_ip" {
  description = "The frontend IP address of the global load balancer"
  value       = google_compute_global_address.lb_ip.address
}

output "lb_frontend_ip_name" {
  description = "The name of the global IP address resource"
  value       = google_compute_global_address.lb_ip.name
}

output "url_map_id" {
  description = "The ID of the URL map"
  value       = google_compute_url_map.url_map.id
}

output "https_proxy_id" {
  description = "The ID of the HTTPS proxy"
  value       = google_compute_target_https_proxy.https_proxy.id
}

output "forwarding_rule_id" {
  description = "The ID of the global forwarding rule"
  value       = google_compute_global_forwarding_rule.forwarding_rule.id
}
