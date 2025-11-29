# Create Service Identity for Certificate Manager
resource "google_project_service_identity" "cert_manager_identity" {
  count    = var.enable_private_ca ? 1 : 0
  provider = google-beta
  service  = "certificatemanager.googleapis.com"
  project  = var.project_id

  depends_on = [google_project_service.certificatemanager]
}

# Grant Certificate Manager Service Account access to CA Pool
resource "google_privateca_ca_pool_iam_member" "cert_manager_binding" {
  count   = var.enable_private_ca ? 1 : 0
  ca_pool = google_privateca_ca_pool.privateca_ca_pool[0].id
  role    = "roles/privateca.certificateRequester"
  member  = "serviceAccount:${google_project_service_identity.cert_manager_identity[0].email}"

  depends_on = [google_privateca_certificate_authority.default]
}

# Grant Cross-Project Access (FR-017)
resource "google_privateca_ca_pool_iam_binding" "cross_project_binding" {
  count   = length(var.authorized_ca_users) > 0 ? 1 : 0
  ca_pool = google_privateca_ca_pool.privateca_ca_pool[0].id
  role    = "roles/privateca.certificateRequester"
  members = var.authorized_ca_users
}
