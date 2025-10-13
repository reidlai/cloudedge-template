terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "ingress_vpc" {
  source        = "./modules/gcp/ingress_vpc"
  project_id    = var.project_id
  environment   = var.environment
  resource_tags = var.resource_tags
}

module "egress_vpc" {
  source        = "./modules/gcp/egress_vpc"
  project_id    = var.project_id
  environment   = var.environment
  resource_tags = var.resource_tags
}

module "firewall" {
  source        = "./modules/gcp/firewall"
  project_id    = var.project_id
  environment   = var.environment
  network_name  = module.ingress_vpc.ingress_vpc_name
  resource_tags = var.resource_tags
}

module "waf" {
  source        = "./modules/gcp/waf"
  project_id    = var.project_id
  environment   = var.environment
  resource_tags = var.resource_tags
}

module "dr_loadbalancer" {
  source                   = "./modules/gcp/dr_loadbalancer"
  project_id               = var.project_id
  environment              = var.environment
  resource_tags            = var.resource_tags
  default_backend_group_id = "placeholder" # This will need to be a real instance group in a real deployment
}

module "inter_vpc_peering" {
  source        = "./modules/gcp/inter_vpc_peering"
  project_id    = var.project_id
  environment   = var.environment
  network1_name = module.ingress_vpc.ingress_vpc_name
  network2_name = module.egress_vpc.egress_vpc_name
  # Peering resources don't support labels
}