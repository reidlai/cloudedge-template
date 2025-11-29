# Create CA Pool (DevOps Tier)
resource "google_privateca_ca_pool" "privateca_ca_pool" {
  count    = var.enable_private_ca ? 1 : 0
  name     = var.privateca_ca_pool_name
  location = var.privateca_location != "" ? var.privateca_location : var.region
  tier     = "DEVOPS" # FR-016
  project  = var.project_id

  publishing_options {
    publish_ca_cert = true
    publish_crl     = false # DEVOPS tier does not support CRL publishing
  }

  depends_on = [google_project_service.privateca]
}
