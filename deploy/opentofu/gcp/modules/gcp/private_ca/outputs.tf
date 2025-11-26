output "certificate_id" {
  description = "The ID of the managed certificate."
  value       = google_certificate_manager_certificate.default.id
}

output "ca_pool_id" {
  description = "The ID of the CA Pool."
  value       = google_privateca_ca_pool.default.id
}

output "certificate_map_id" {
  description = "The ID of the Certificate Map (after entry is created)."
  # Reference the map entry to ensure proper dependency ordering
  # The HTTPS proxy needs the map to have at least one entry before it can be used
  value      = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"
  depends_on = [google_certificate_manager_certificate_map_entry.default]
}
