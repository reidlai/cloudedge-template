#
# Root Module: vibetics-cloudedge
#
# This file is the entrypoint for the OpenTofu configuration. It defines the
# providers, composes the various infrastructure modules, and connects them
# to create the complete Cloud Edge environment.
#



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
      "project-suffix" = var.project_suffix
      "project"        = var.project_id
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
  project_id     = var.project_id
  project_suffix = var.project_suffix
  region         = var.region
  resource_tags  = local.standard_tags
  cidr_range     = var.ingress_vpc_cidr_range
}

# Creates the Egress VPC for all outbound traffic from internal services.
module "egress_vpc" {
  count          = var.enable_egress_vpc ? 1 : 0
  source         = "./modules/gcp/egress_vpc"
  project_id     = var.project_id
  project_suffix = var.project_suffix
  region         = var.region
  resource_tags  = local.standard_tags
  cidr_range     = var.egress_vpc_cidr_range
}

# Applies baseline firewall rules to the Ingress VPC.
module "firewall" {
  count          = var.enable_firewall ? 1 : 0
  source         = "./modules/gcp/firewall"
  project_id     = var.project_id
  project_suffix = var.project_suffix
  network_name   = module.ingress_vpc[0].ingress_vpc_name
  resource_tags  = local.standard_tags
}

# --- Edge Security & Load Balancing ---

# Deploys the Google Cloud Armor WAF policy.
module "waf" {
  count          = var.enable_waf ? 1 : 0
  source         = "./modules/gcp/waf"
  project_id     = var.project_id
  project_suffix = var.project_suffix
  resource_tags  = local.standard_tags
}

# --- CDN Configuration ---

# Creates a GCS bucket for static content delivery via CDN
resource "google_storage_bucket" "cdn_content" {
  count    = var.enable_cdn ? 1 : 0
  project  = var.project_id
  name     = "${var.project_id}-cdn-content"
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
  project_id     = var.project_id
  project_suffix = var.project_suffix
  bucket_name    = google_storage_bucket.cdn_content[0].name
  resource_tags  = local.standard_tags
}

# --- SSL Certificate Configuration ---

module "private_ca" {
  count              = var.enable_private_ca ? 1 : 0
  source             = "./modules/gcp/private_ca"
  project_id         = var.project_id
  project_suffix     = var.project_suffix
  region             = var.region
  domain             = var.managed_ssl_domain != "" ? var.managed_ssl_domain : "${var.project_id}.internal"
  authorized_members = var.authorized_ca_users
  pool_name          = "${var.project_suffix}-${var.private_ca_pool_name}"
  location           = var.private_ca_location
}

resource "google_compute_managed_ssl_certificate" "managed_cert" {
  count   = var.enable_private_ca ? 0 : 1
  project = var.project_id
  name    = "${var.project_suffix}-managed-cert"
  managed {
    domains = [var.managed_ssl_domain]
  }
}

locals {
  # Determine which certificate to use based on the feature flag
  ssl_certificate_links = var.enable_private_ca ? [] : [google_compute_managed_ssl_certificate.managed_cert[0].self_link]
  certificate_map_id    = var.enable_private_ca ? module.private_ca[0].certificate_map_id : null
  # Use the configured domain or a placeholder
  load_balancer_host = var.managed_ssl_domain != "" ? var.managed_ssl_domain : "${var.project_id}.internal"
}

# --- Demo Web App Environment ---

# Deploys the secure, internal-only demo web app using PSC (Private Service Connect)
# PSC connectivity via Serverless NEG - no VPC peering required
module "demo_web_app" {
  count                 = var.enable_demo_web_app ? 1 : 0
  source                = "./modules/gcp/demo_web_app"
  project_id            = var.project_id
  project_suffix        = var.project_suffix
  region                = var.region
  resource_tags         = local.standard_tags
  demo_web_app_image    = var.demo_web_app_image
  enable_logging_bucket = var.enable_logging_bucket
}

# --- Global Load Balancer & Routing ---

# Deploys the Global External HTTPS Load Balancer and configures its URL map and backends.
module "dr_loadbalancer" {
  count              = var.enable_dr_loadbalancer ? 1 : 0
  source             = "./modules/gcp/dr_loadbalancer"
  project_id         = var.project_id
  project_suffix     = var.project_suffix
  resource_tags      = local.standard_tags
  default_service_id = module.demo_web_app[0].backend_service_id
  ssl_certificates   = local.ssl_certificate_links
  certificate_map    = local.certificate_map_id
  host_rules = [
    {
      hosts        = [local.load_balancer_host]
      path_matcher = "demo-web-app-matcher"
    }
  ]
  path_matchers = {
    "demo-web-app-matcher" = {
      default_service = module.demo_web_app[0].backend_service_id
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
  project_id      = var.project_id
  billing_account = var.billing_account
}
