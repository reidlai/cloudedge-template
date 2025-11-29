output "ca_pool_id" {
  description = "The ID of the Certificate Authority pool."
  value       = var.enable_private_ca ? google_privateca_ca_pool.privateca_ca_pool[0].id : null
}

output "certificate_map_id" {
  description = "The ID of the Certificate Map."
  value       = var.enable_private_ca ? google_certificate_manager_certificate_map.default[0].id : null
}

output "ca_domain_name" {
  description = "The domain name used by the Private CA for certificates."
  value       = var.managed_ssl_domain
}
