# Certificate Issuance Config
resource "google_certificate_manager_certificate_issuance_config" "default" {
  count   = var.enable_private_ca ? 1 : 0
  name    = "${var.project_suffix}-issuance-config"
  project = var.project_id

  certificate_authority_config {
    certificate_authority_service_config {
      ca_pool = google_privateca_ca_pool.privateca_ca_pool[0].id
    }
  }
  lifetime                   = "2592000s" # 30 days (minimum 504h = 21 days)
  rotation_window_percentage = 50
  key_algorithm              = "RSA_2048"

  depends_on = [
    google_project_service.certificatemanager,
    google_privateca_certificate_authority.default,
    google_privateca_ca_pool_iam_member.cert_manager_binding
  ]
}
