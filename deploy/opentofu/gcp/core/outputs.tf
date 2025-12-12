##########
# Output #
##########

output "ingress_vpc_id" {
  description = "The ID of the ingress VPC."
  value       = google_compute_network.ingress_vpc.id
}

output "ingress_subnet_id" {
  description = "The ID of the ingress subnet."
  value       = google_compute_subnetwork.ingress_subnet.id
}

output "load_balancer_ip" {
  description = "The public IP address of the regional load balancer."
  value       = google_compute_address.external_lb_ip.address
}

output "waf_policy_id" {
  description = "The ID of the WAF (Cloud Armor) security policy. Returns null if Cloud Armor is disabled."
  value       = local.enable_waf ? google_compute_region_security_policy.edge_waf_policy[0].id : null
}

output "cloudflare_proxy_enabled" {
  description = "Indicates whether Cloudflare proxy is enabled for WAF and DDoS protection."
  value       = local.enable_cloudflare_proxy
}

output "cloud_armor_enabled" {
  description = "Indicates whether GCP Cloud Armor WAF is enabled."
  value       = local.enable_waf
}

output "cloudflare_origin_cert_id" {
  description = "The ID of the Cloudflare origin certificate used for Cloudflare-to-GCP encryption. Returns null if Cloudflare proxy is disabled."
  value       = local.enable_cloudflare_proxy ? google_compute_region_ssl_certificate.cloudflare_origin_cert[0].id : null
}

output "psc_enabled" {
  description = "Indicates whether Private Service Connect (PSC) is enabled for this module."
  value       = local.enable_psc
}
