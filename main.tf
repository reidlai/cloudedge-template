#
# Root Module: vibetics-cloudedge
#
# This file is the entrypoint for the OpenTofu configuration. It defines the
# providers, composes the various infrastructure modules, and connects them
# to create the complete Cloud Edge environment.
#

# --- Provider Configuration ---

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

# Configures the Google Cloud provider with the project and region.
provider "google" {
  project = var.project_id
  region  = var.region
}

# --- Tagging Strategy ---

locals {
  # Merge user-provided tags with mandatory tags
  standard_tags = merge(
    var.resource_tags,
    {
      "environment" = var.environment
      "project"     = var.project_id
      "managed-by"  = "opentofu"
    }
  )
}

# --- Core Network Infrastructure ---
# Note: Required GCP APIs must be enabled manually before deployment.
# See README.md Prerequisites section for the complete list and enablement commands.

# Creates the Ingress VPC for all incoming public traffic.
module "ingress_vpc" {
  count         = var.enable_ingress_vpc ? 1 : 0
  source        = "./modules/gcp/ingress_vpc"
  project_id    = var.project_id
  environment   = var.environment
  region        = var.region
  resource_tags = local.standard_tags
  cidr_range    = var.ingress_vpc_cidr_range
}

# Creates the Egress VPC for all outbound traffic from internal services.
module "egress_vpc" {
  count         = var.enable_egress_vpc ? 1 : 0
  source        = "./modules/gcp/egress_vpc"
  project_id    = var.project_id
  environment   = var.environment
  region        = var.region
  resource_tags = local.standard_tags
  cidr_range    = var.egress_vpc_cidr_range
}

# Applies baseline firewall rules to the Ingress VPC.
module "firewall" {
  count         = var.enable_firewall ? 1 : 0
  source        = "./modules/gcp/firewall"
  project_id    = var.project_id
  environment   = var.environment
  network_name  = module.ingress_vpc[0].ingress_vpc_name
  resource_tags = local.standard_tags
}

# --- Edge Security & Load Balancing ---

# Deploys the Google Cloud Armor WAF policy.
module "waf" {
  count         = var.enable_waf ? 1 : 0
  source        = "./modules/gcp/waf"
  project_id    = var.project_id
  environment   = var.environment
  resource_tags = local.standard_tags
}

# --- CDN Configuration ---

# Creates a GCS bucket for static content delivery via CDN
resource "google_storage_bucket" "cdn_content" {
  count    = var.enable_cdn ? 1 : 0
  project  = var.project_id
  name     = "${var.project_id}-${var.environment}-cdn-content"
  location = var.region

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

# Deploys the CDN backend bucket
module "cdn" {
  count         = var.enable_cdn ? 1 : 0
  source        = "./modules/gcp/cdn"
  project_id    = var.project_id
  environment   = var.environment
  bucket_name   = google_storage_bucket.cdn_content[0].name
  resource_tags = local.standard_tags
}

# --- SSL Certificate Configuration ---

module "self_signed_cert" {
  count       = var.enable_self_signed_cert ? 1 : 0
  source      = "./modules/gcp/self_signed_certificate"
  project_id  = var.project_id
  environment = var.environment
}

resource "google_compute_managed_ssl_certificate" "managed_cert" {
  count   = var.enable_self_signed_cert ? 0 : 1
  project = var.project_id
  name    = "${var.environment}-managed-cert"
  managed {
    domains = [var.managed_ssl_domain]
  }
}

locals {
  # Determine which certificate to use based on the feature flag
  ssl_certificate_links = var.enable_self_signed_cert ? [module.self_signed_cert[0].self_link] : [google_compute_managed_ssl_certificate.managed_cert[0].self_link]
  # Use a placeholder host for self-signed certs, as there's no real domain.
  load_balancer_host = var.enable_self_signed_cert ? "example.com" : var.managed_ssl_domain
}

# --- Demo Backend Environment ---

# Deploys the secure, internal-only demo API and integrates it with the network.
module "demo_backend" {
  count                        = var.enable_demo_backend ? 1 : 0
  source                       = "./modules/gcp/demo_backend"
  project_id                   = var.project_id
  environment                  = var.environment
  region                       = var.region
  resource_tags                = local.standard_tags
  ingress_vpc_self_link        = module.ingress_vpc[0].ingress_vpc_self_link
  vpc_connector_cidr_range     = var.vpc_connector_cidr_range
  vpc_connector_min_throughput = var.vpc_connector_min_throughput
  vpc_connector_max_throughput = var.vpc_connector_max_throughput
  demo_api_image               = var.demo_api_image
}

# --- Global Load Balancer & Routing ---

# Deploys the Global External HTTPS Load Balancer and configures its URL map and backends.
module "dr_loadbalancer" {
  count              = var.enable_dr_loadbalancer ? 1 : 0
  source             = "./modules/gcp/dr_loadbalancer"
  project_id         = var.project_id
  environment        = var.environment
  resource_tags      = local.standard_tags
  default_service_id = module.demo_backend[0].backend_service_id
  ssl_certificates   = local.ssl_certificate_links
  host_rules = [
    {
      hosts        = [local.load_balancer_host]
      path_matcher = "demo-api-matcher"
    }
  ]
  path_matchers = {
    "demo-api-matcher" = {
      default_service = module.demo_backend[0].backend_service_id
      path_rules      = []
    }
  }
}

# --- Core VPC Peering ---

# Establishes the primary VPC peering connection between the Ingress and Egress VPCs.
module "inter_vpc_peering" {
  count              = var.enable_inter_vpc_peering ? 1 : 0
  source             = "./modules/gcp/inter_vpc_peering"
  project_id         = var.project_id
  environment        = var.environment
  network1_self_link = module.ingress_vpc[0].ingress_vpc_self_link
  network2_self_link = module.egress_vpc[0].egress_vpc_self_link
}

# --- Billing ---

module "billing" {
  count           = var.enable_billing ? 1 : 0
  source          = "./modules/gcp/billing"
  project_id      = var.project_id
  billing_account = var.billing_account
}