terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0.0"
    }
  }
}

# Enable required APIs
resource "google_project_service" "privateca" {
  project            = var.project_id
  service            = "privateca.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "certificatemanager" {
  project            = var.project_id
  service            = "certificatemanager.googleapis.com"
  disable_on_destroy = false
}

# Create CA Pool (DevOps Tier)
resource "google_privateca_ca_pool" "default" {
  name     = var.pool_name
  location = var.location != "" ? var.location : var.region
  tier     = "DEVOPS" # FR-016
  project  = var.project_id

  publishing_options {
    publish_ca_cert = true
    publish_crl     = false # DEVOPS tier does not support CRL publishing
  }

  depends_on = [google_project_service.privateca]
}

# Create Root CA
resource "google_privateca_certificate_authority" "default" {
  pool                     = google_privateca_ca_pool.default.name
  certificate_authority_id = "${var.project_suffix}-root-ca"
  location                 = var.location != "" ? var.location : var.region
  project                  = var.project_id
  type                     = "SELF_SIGNED"

  config {
    subject_config {
      subject {
        common_name  = "internal-root-ca-${var.project_suffix}"
        organization = "Vibetics"
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

  # Auto-enable
  deletion_protection = false
  skip_grace_period   = true
}

# Certificate Issuance Config
resource "google_certificate_manager_certificate_issuance_config" "default" {
  name    = "${var.project_suffix}-issuance-config"
  project = var.project_id

  certificate_authority_config {
    certificate_authority_service_config {
      ca_pool = google_privateca_ca_pool.default.id
    }
  }
  lifetime                   = "2592000s" # 30 days (minimum 504h = 21 days)
  rotation_window_percentage = 50
  key_algorithm              = "RSA_2048"

  depends_on = [google_project_service.certificatemanager]
}

# ... (previous content) ...

# Managed Certificate
resource "google_certificate_manager_certificate" "default" {
  name        = "${var.project_suffix}-private-cert"
  description = "Private Managed Certificate"
  project     = var.project_id

  managed {
    domains         = [var.domain]
    issuance_config = google_certificate_manager_certificate_issuance_config.default.id
  }
}

# Certificate Map
resource "google_certificate_manager_certificate_map" "default" {
  name        = "${var.project_suffix}-cert-map"
  description = "Certificate Map for ${var.domain}"
  project     = var.project_id
}

# Certificate Map Entry
resource "google_certificate_manager_certificate_map_entry" "default" {
  name        = "${var.project_suffix}-cert-map-entry"
  description = "Entry for ${var.domain}"
  project     = var.project_id
  map         = google_certificate_manager_certificate_map.default.name

  certificates = [google_certificate_manager_certificate.default.id]
  hostname     = var.domain
}

# ... (IAM resources) ...


# Get Project Number for Service Agent
data "google_project" "current" {
  project_id = var.project_id
}

# Create Service Identity for Certificate Manager
resource "google_project_service_identity" "cert_manager_identity" {
  provider = google-beta
  service  = "certificatemanager.googleapis.com"
  project  = var.project_id

  depends_on = [google_project_service.certificatemanager]
}

# Grant Certificate Manager Service Account access to CA Pool
resource "google_privateca_ca_pool_iam_member" "cert_manager_binding" {
  ca_pool = google_privateca_ca_pool.default.id
  role    = "roles/privateca.certificateRequester"
  member  = "serviceAccount:${google_project_service_identity.cert_manager_identity.email}"

  depends_on = [google_privateca_certificate_authority.default]
}

# Grant Cross-Project Access (FR-017)
resource "google_privateca_ca_pool_iam_binding" "cross_project_binding" {
  count   = length(var.authorized_members) > 0 ? 1 : 0
  ca_pool = google_privateca_ca_pool.default.id
  role    = "roles/privateca.certificateRequester"
  members = var.authorized_members
}
