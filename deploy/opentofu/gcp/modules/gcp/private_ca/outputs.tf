output "certificate_id" {
  description = "The ID of the managed certificate."
  value       = google_certificate_manager_certificate.default.id
}

output "ca_pool_id" {
  description = "The ID of the CA Pool."
  value       = google_privateca_ca_pool.default.id
}

output "certificate_map_id" {
  description = "The ID of the Certificate Map."
  value       = google_certificate_manager_certificate_map.default.id
}
