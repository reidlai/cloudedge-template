# Certificate Map
resource "google_certificate_manager_certificate_map" "default" {
  count       = var.enable_private_ca ? 1 : 0
  name        = "${var.project_suffix}-cert-map"
  description = "Certificate Map for ${var.managed_ssl_domain}"
  project     = var.project_id
}

# Certificate Map Entry
resource "google_certificate_manager_certificate_map_entry" "default" {
  count       = var.enable_private_ca ? 1 : 0
  name        = "${var.project_suffix}-cert-map-entry"
  description = "Entry for ${var.managed_ssl_domain} in Certificate Map"
  project     = var.project_id
  map         = google_certificate_manager_certificate_map.default[0].name

  certificates = [google_certificate_manager_certificate_map.default[0].name]
  hostname     = var.managed_ssl_domain
}
