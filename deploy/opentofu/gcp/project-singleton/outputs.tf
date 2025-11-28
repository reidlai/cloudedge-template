output "ingress_vpc_id" {
  description = "The ID of the ingress VPC."
  value       = google_compute_network.ingress_vpc[0].id
}

output "egress_vpc_id" {
  description = "The ID of the egress VPC."
  value       = google_compute_network.egress_vpc[0].id
}

output "ingress_subnet_id" {
  description = "The ID of the ingress subnet."
  value       = google_compute_subnetwork.ingress_subnet[0].id
}

output "egress_subnet_id" {
  description = "The ID of the egress subnet."
  value       = google_compute_subnetwork.egress_subnet[0].id
}

output "ca_pool_id" {
  description = "The ID of the Certificate Authority pool."
  value       = google_privateca_ca_pool.privateca_ca_pool[0].id
}

output "certificate_map_id" {
  description = "The ID of the Certificate Map."
  value       = google_certificate_manager_certificate_map.default[0].id
}

output "ca_domain_name" {
  description = "The domain name used by the Private CA for certificates."
  value       = var.managed_ssl_domain
}
