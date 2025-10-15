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
  }
}

# Configures the Google Cloud provider with the project and region.
provider "google" {
  project = var.project_id
  region  = var.region
}

# --- API Enablement ---

# Enables the necessary Google Cloud APIs for the project.
resource "google_project_service" "project_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "vpcaccess.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  project                    = var.project_id
  service                    = each.key
  disable_dependent_services = true
}

# --- Core Network Infrastructure ---

# Creates the Ingress VPC for all incoming public traffic.
module "ingress_vpc" {
  count         = var.enable_ingress_vpc ? 1 : 0
  source        = "./modules/gcp/ingress_vpc"
  project_id    = var.project_id
  environment   = var.environment
  region        = var.region
  resource_tags = var.resource_tags
  depends_on = [
    google_project_service.project_apis["compute.googleapis.com"]
  ]
}

# Creates the Egress VPC for all outbound traffic from internal services.
module "egress_vpc" {
  count         = var.enable_egress_vpc ? 1 : 0
  source        = "./modules/gcp/egress_vpc"
  project_id    = var.project_id
  environment   = var.environment
  region        = var.region
  resource_tags = var.resource_tags
  depends_on = [
    google_project_service.project_apis["compute.googleapis.com"]
  ]
}

# Applies baseline firewall rules to the Ingress VPC.
module "firewall" {
  count         = var.enable_firewall ? 1 : 0
  source        = "./modules/gcp/firewall"
  project_id    = var.project_id
  environment   = var.environment
  network_name  = module.ingress_vpc[0].ingress_vpc_name
  resource_tags = var.resource_tags
  depends_on = [
    google_project_service.project_apis["compute.googleapis.com"]
  ]
}

# --- Edge Security & Load Balancing ---

# Deploys the Google Cloud Armor WAF policy.
module "waf" {
  count         = var.enable_waf ? 1 : 0
  source        = "./modules/gcp/waf"
  project_id    = var.project_id
  environment   = var.environment
  resource_tags = var.resource_tags
  depends_on = [
    google_project_service.project_apis["compute.googleapis.com"]
  ]
}

# --- Demo Backend Environment ---

# Deploys the secure, internal-only demo API and integrates it with the network.
module "demo_backend" {
  count                 = var.enable_demo_backend ? 1 : 0
  source                = "./modules/gcp/demo_backend"
  project_id            = var.project_id
  environment           = var.environment
  region                = var.region
  resource_tags         = var.resource_tags
  ingress_vpc_self_link = module.ingress_vpc[0].ingress_vpc_self_link
  depends_on = [
    google_project_service.project_apis
  ]
}

# --- Global Load Balancer & Routing ---

# Deploys the Global External HTTPS Load Balancer and configures its URL map and backends.
module "dr_loadbalancer" {
  count              = var.enable_dr_loadbalancer ? 1 : 0
  source             = "./modules/gcp/dr_loadbalancer"
  project_id         = var.project_id
  environment        = var.environment
  resource_tags      = var.resource_tags
  default_service_id = module.demo_backend[0].backend_service_id
  managed_ssl_domain = var.managed_ssl_domain
  host_rules = [
    {
      hosts        = [var.managed_ssl_domain]
      path_matcher = "demo-api-matcher"
    }
  ]
  path_matchers = {
    "demo-api-matcher" = {
      default_service = module.demo_backend[0].backend_service_id
      path_rules      = []
    }
  }
  depends_on = [
    google_project_service.project_apis
  ]
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