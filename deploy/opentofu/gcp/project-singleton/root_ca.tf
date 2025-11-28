resource "google_privateca_certificate_authority" "default" {
  count                    = var.enable_private_ca ? 1 : 0
  pool                     = google_privateca_ca_pool.privateca_ca_pool[0].name
  certificate_authority_id = "${var.project_suffix}-root-ca"
  location                 = var.region
  type                     = "SELF_SIGNED"

  # Ensure clean teardown for non-prod/test environments
  deletion_protection                    = false
  skip_grace_period                      = true
  ignore_active_certificates_on_deletion = true

  config {
    subject_config {
      subject {
        organization = "Vibetics"
        common_name  = "internal-root-ca-${var.project_suffix}"
      }
    }
    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth = true
        }
      }
    }
  }

  key_spec {
    algorithm = "RSA_PKCS1_2048_SHA256"
  }
}
