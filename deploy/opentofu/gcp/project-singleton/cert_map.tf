# Certificate Map
resource "google_certificate_manager_certificate_map" "default" {
  count       = var.enable_private_ca ? 1 : 0
  name        = "${var.project_suffix}-cert-map"
  description = "Certificate Map for ${var.managed_ssl_domain}"
  project     = var.project_id
}

# Managed Certificate using the issuance config
resource "google_certificate_manager_certificate" "default" {
  count       = var.enable_private_ca && var.managed_ssl_domain != "" ? 1 : 0
  name        = "${var.project_suffix}-managed-cert"
  description = "Managed certificate for ${var.managed_ssl_domain}"
  project     = var.project_id

  managed {
    domains         = [var.managed_ssl_domain]
    issuance_config = google_certificate_manager_certificate_issuance_config.default[0].id
  }
}

# Certificate Map Entry - only created when a domain is specified
resource "google_certificate_manager_certificate_map_entry" "default" {
  count       = var.enable_private_ca && var.managed_ssl_domain != "" ? 1 : 0
  name        = "${var.project_suffix}-cert-map-entry"
  description = "Entry for ${var.managed_ssl_domain} in Certificate Map"
  project     = var.project_id
  map         = google_certificate_manager_certificate_map.default[0].name

  certificates = [google_certificate_manager_certificate.default[0].id]
  hostname     = var.managed_ssl_domain
}
