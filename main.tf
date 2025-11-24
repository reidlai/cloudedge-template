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

# --- Computed Values ---

locals {
  # Compute project_id from repository name and suffix
  project_id = "${var.cloudedge_github_repository}-${var.project_suffix}"
}

# Configures the Google Cloud provider with the project and region.
provider "google" {
  project = local.project_id
  region  = var.region
}

# --- Tagging Strategy ---

locals {
  # Merge user-provided tags with mandatory tags
  standard_tags = merge(
    var.resource_tags,
    {
      "project-suffix" = var.project_suffix
      "project"        = local.project_id
      "managed-by"     = "opentofu"
    }
  )
}

# --- Core Network Infrastructure ---
# Note: Required GCP APIs must be enabled manually before deployment.
# See README.md Prerequisites section for the complete list and enablement commands.

# Creates the Ingress VPC for all incoming public traffic.
module "ingress_vpc" {
  count          = var.enable_ingress_vpc ? 1 : 0
  source         = "./modules/gcp/ingress_vpc"
  project_id     = local.project_id
  project_suffix = var.project_suffix
  region         = var.region
  resource_tags  = local.standard_tags
  cidr_range     = var.ingress_vpc_cidr_range
}

# Creates the Egress VPC for all outbound traffic from internal services.
module "egress_vpc" {
  count          = var.enable_egress_vpc ? 1 : 0
  source         = "./modules/gcp/egress_vpc"
  project_id     = local.project_id
  project_suffix = var.project_suffix
  region         = var.region
  resource_tags  = local.standard_tags
  cidr_range     = var.egress_vpc_cidr_range
}

# Applies baseline firewall rules to the Ingress VPC.
module "firewall" {
  count          = var.enable_firewall ? 1 : 0
  source         = "./modules/gcp/firewall"
  project_id     = local.project_id
  project_suffix = var.project_suffix
  network_name   = module.ingress_vpc[0].ingress_vpc_name
  resource_tags  = local.standard_tags
}

# --- Edge Security & Load Balancing ---

# Deploys the Google Cloud Armor WAF policy.
module "waf" {
  count          = var.enable_waf ? 1 : 0
  source         = "./modules/gcp/waf"
  project_id     = local.project_id
  project_suffix = var.project_suffix
  resource_tags  = local.standard_tags
}

# --- CDN Configuration ---

# Creates a GCS bucket for static content delivery via CDN
resource "google_storage_bucket" "cdn_content" {
  count    = var.enable_cdn ? 1 : 0
  project  = local.project_id
  name     = "${local.project_id}-cdn-content"
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
  count          = var.enable_cdn ? 1 : 0
  source         = "./modules/gcp/cdn"
  project_id     = local.project_id
  project_suffix = var.project_suffix
  bucket_name    = google_storage_bucket.cdn_content[0].name
  resource_tags  = local.standard_tags
}

# --- SSL Certificate Configuration ---

module "self_signed_cert" {
  count          = var.enable_self_signed_cert ? 1 : 0
  source         = "./modules/gcp/self_signed_certificate"
  project_id     = local.project_id
  project_suffix = var.project_suffix
}

resource "google_compute_managed_ssl_certificate" "managed_cert" {
  count   = var.enable_self_signed_cert ? 0 : 1
  project = local.project_id
  name    = "${var.project_suffix}-managed-cert"
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

# Deploys the secure, internal-only demo backend using PSC (Private Service Connect)
# PSC connectivity via Serverless NEG - no VPC peering required
module "demo_backend" {
  count                 = var.enable_demo_backend ? 1 : 0
  source                = "./modules/gcp/demo_backend"
  project_id            = local.project_id
  project_suffix        = var.project_suffix
  region                = var.region
  resource_tags         = local.standard_tags
  demo_api_image        = var.demo_api_image
  enable_logging_bucket = var.enable_logging_bucket
}

# --- Global Load Balancer & Routing ---

# Deploys the Global External HTTPS Load Balancer and configures its URL map and backends.
module "dr_loadbalancer" {
  count              = var.enable_dr_loadbalancer ? 1 : 0
  source             = "./modules/gcp/dr_loadbalancer"
  project_id         = local.project_id
  project_suffix     = var.project_suffix
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

# --- VPC Connectivity ---
#
# Fix I1: VPC Peering REMOVED - Not Required for PSC Architecture
#
# Cloud Run uses Serverless NEG which provides DIRECT Private Service Connect (PSC)
# connectivity from the Global Load Balancer to Cloud Run services.
#
# VPC Peering is NOT needed because:
# 1. Serverless NEG creates a PSC endpoint automatically
# 2. Load balancer → Serverless NEG → Cloud Run (all via PSC)
# 3. No VPC-to-VPC connectivity required for serverless backends
#
# VPC Peering would only be needed for:
# - GKE backends (Instance Group NEGs)
# - Compute Engine VMs (VM NEGs)
# - Future multi-VPC application architectures
#
# See plan.md "Architecture Details > Domain-Based Routing" for PSC design rationale.

# --- Billing ---

module "billing" {
  count           = var.enable_billing ? 1 : 0
  source          = "./modules/gcp/billing"
  project_id      = local.project_id
  billing_account = var.billing_account
}
