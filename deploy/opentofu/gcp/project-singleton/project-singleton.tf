###################
# Local variables #
###################

locals {
  project_suffix              = var.project_suffix
  cloudedge_github_repository = var.cloudedge_github_repository
  project_id                  = var.project_id != "" ? var.project_id : "${local.cloudedge_github_repository}-${local.project_suffix}"
  region                      = var.region
  billing_account_name        = var.billing_account_name
  budget_amount               = var.budget_amount
  standard_tags = merge(
    var.resource_tags,
    {
      "project-suffix" = var.project_suffix
      "project"        = local.project_id
      "managed-by"     = "opentofu"
    }
  )
  enable_logging = var.enable_logging

  host_project_id             = "vibetics-shared-${local.project_suffix}"
  enable_self_signed_cert     = var.enable_self_signed_cert
  demo_web_app_subdomain_name = var.demo_web_app_subdomain_name
  root_domain                 = var.root_domain
  cloudflare_api_token        = var.cloudflare_api_token
}

provider "google" {
  project = local.project_id
  region  = local.region

  # Required for billing budget API which needs a quota project
  user_project_override = true
  billing_project       = local.project_id
}

provider "google-beta" {
  project = local.project_id
  region  = local.region

  user_project_override = true
  billing_project       = local.project_id
}

provider "acme" {
  # "https://acme-staging-v02.api.letsencrypt.org/directory" for testing (avoids rate limits)
  # "https://acme-v02.api.letsencrypt.org/directory" for production
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

data "google_billing_account" "billing_account" {
  display_name = local.billing_account_name
  depends_on   = [google_project_service.cloudbilling]
}

# Get Project Number for Service Agent
data "google_project" "current" {
  project_id = local.project_id
}

###############
# Googel APIs #
###############

resource "google_project_service" "billingbudgets" {
  project            = local.project_id
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbilling" {
  project            = local.project_id
  service            = "cloudbilling.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  project            = local.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  project            = local.project_id
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

#############################
# Google Billing and Budget #
#############################

resource "google_billing_budget" "budget" {
  billing_account = data.google_billing_account.billing_account.id
  display_name    = "Vibetics Cloud Edge Budget"

  budget_filter {
    projects = ["projects/${local.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "HKD"
      units         = local.budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.8
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  depends_on = [google_project_service.billingbudgets]
}

##########################
# Project Logging bucket #
##########################

resource "google_logging_project_bucket_config" "logs_bucket" {
  count          = local.enable_logging ? 1 : 0
  project        = local.project_id
  location       = local.region
  retention_days = 30 # NFR-001: 30-day trace data retention
  bucket_id      = "${local.project_id}-logs"
  description    = "30-day retention bucket for demo backend service logs (NFR-001 compliance)"

  depends_on = [
    google_project_service.logging
  ]
}

############
# SSL Cert #
############

resource "tls_private_key" "self_signed_key" {
  count     = local.enable_self_signed_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed_cert" {
  count             = local.enable_self_signed_cert ? 1 : 0
  private_key_pem   = tls_private_key.self_signed_key[0].private_key_pem
  is_ca_certificate = true

  subject {
    common_name  = "${local.demo_web_app_subdomain_name}.${local.root_domain}"
    organization = "Demo"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["${local.demo_web_app_subdomain_name}.${local.root_domain}"]
}

resource "google_compute_region_ssl_certificate" "external_https_lb_cert" {
  count       = local.enable_self_signed_cert ? 1 : 0
  provider    = google-beta
  project     = local.project_id
  region      = local.region
  name        = "external-https-lb-cert-${local.demo_web_app_subdomain_name}"
  private_key = local.enable_self_signed_cert ? tls_private_key.self_signed_key[0].private_key_pem : null
  certificate = local.enable_self_signed_cert ? tls_self_signed_cert.self_signed_cert[0].cert_pem : null

}

resource "google_compute_managed_ssl_certificate" "external_https_lb_cert" {
  count    = local.enable_self_signed_cert ? 0 : 1
  provider = google-beta
  project  = local.project_id
  name     = "external-https-lb-cert-${local.demo_web_app_subdomain_name}"
  managed {
    domains = ["${local.demo_web_app_subdomain_name}.${local.root_domain}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
