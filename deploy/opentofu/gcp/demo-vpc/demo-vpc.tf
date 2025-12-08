
###################
# Local Variables #
###################

locals {
  project_suffix              = var.project_suffix
  cloudedge_github_repository = var.cloudedge_github_repository
  region                      = var.region

  project_id = var.project_id != "" ? var.project_id : "${local.cloudedge_github_repository}-${local.project_suffix}"
  standard_tags = merge(
    var.resource_tags,
    {
      "project"    = local.project_id
      "managed-by" = "opentofu"
    }
  )

  enable_demo_web_app                = var.enable_demo_web_app
  demo_web_app_service_name          = "demo-web-app"
  demo_web_app_image                 = var.demo_web_app_image
  demo_web_app_port                  = var.demo_web_app_port
  demo_web_app_neg_name              = "${local.demo_web_app_service_name}-neg"
  demo_web_app_internal_backend_name = "${local.demo_web_app_service_name}-internal-backend"
  web_subnet_cidr_range              = var.web_subnet_cidr_range
  proxy_only_subnet_cidr_range       = var.proxy_only_subnet_cidr_range
}

provider "google" {
  project = local.project_id
  region  = local.region
}

provider "google-beta" {
  project = local.project_id
  region  = var.region
}

data "terraform_remote_state" "singleton" {
  backend = "gcs"
  config = {
    bucket = "${local.project_id}-tfstate"
    prefix = "${local.project_id}-environment"
  }
}

# Get Project Number for Service Agent
data "google_project" "current" {
  project_id = local.project_id
}

###########
# Web VPC #
###########

resource "google_compute_network" "web_vpc" {
  count                   = local.enable_demo_web_app ? 1 : 0
  project                 = local.project_id
  name                    = "web-vpc"
  auto_create_subnetworks = false
}

##############
# Web Subnet #
##############

resource "google_compute_subnetwork" "web_subnet" {
  count                    = local.enable_demo_web_app ? 1 : 0
  project                  = local.project_id
  name                     = "web-subnet"
  ip_cidr_range            = local.web_subnet_cidr_range
  region                   = local.region
  network                  = google_compute_network.web_vpc[0].id
  private_ip_google_access = true
}


#################################################
# Proxy-only subnet (required for Internal ALB) #
#############################################demo-web-app-####

resource "google_compute_subnetwork" "proxy_only_subnet" {
  count         = local.enable_demo_web_app ? 1 : 0
  project       = local.project_id
  name          = "demo-web-app-proxy-only-subnet"
  ip_cidr_range = local.proxy_only_subnet_cidr_range
  region        = local.region
  network       = google_compute_network.web_vpc[0].id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}


#########################################
# PSC NAT subnet for Service Attachment #
#########################################

resource "google_compute_subnetwork" "psc_nat_subnet" {
  count         = local.enable_demo_web_app ? 1 : 0
  project       = local.project_id
  name          = "psc-nat-subnet"
  ip_cidr_range = "10.0.100.0/24"
  region        = local.region
  network       = google_compute_network.web_vpc[0].id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

##########################
# Demo Web App Cloud Run #
##########################

resource "google_cloud_run_v2_service" "demo_web_app" {
  count               = local.enable_demo_web_app ? 1 : 0
  project             = local.project_id
  name                = local.demo_web_app_service_name
  location            = local.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false
  template {
    containers {
      image = local.demo_web_app_image
      ports {
        container_port = local.demo_web_app_port
      }
    }
    scaling {
      min_instance_count = 0 # Scale to zero for cost-effectiveness
    }
    labels = local.standard_tags
  }
}

#########################################################################################
# Serverless Network Endpoint Group (NEG) for the demo web app Cloud Run service        #
# NEG points directly to the Cloud Run service, serving as the load balancer's backend. #
#########################################################################################

resource "google_compute_region_network_endpoint_group" "demo_web_app" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  name                  = local.demo_web_app_neg_name
  region                = local.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.demo_web_app[0].name
  }
}

#################################################
# Demo Web App Backend Service for Internal ALB #
#################################################

resource "google_compute_region_backend_service" "demo_web_app_internal_backend" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  name                  = local.demo_web_app_internal_backend_name
  region                = local.region
  protocol              = "HTTPS"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 30

  backend {
    group           = google_compute_region_network_endpoint_group.demo_web_app[0].id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

#################
# Cloud Run IAM #
#################

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = local.enable_demo_web_app ? 1 : 0
  name     = google_cloud_run_v2_service.demo_web_app[0].name
  project  = local.project_id
  location = local.region
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [
    google_cloud_run_v2_service.demo_web_app
  ]
}

#################################################################
# Self-signed certificate for Internal ALB HTTPS Load Balancing #
#################################################################

resource "tls_private_key" "self_signed_cert_key" {
  count     = local.enable_demo_web_app ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed_cert" {
  count             = local.enable_demo_web_app ? 1 : 0
  private_key_pem   = tls_private_key.self_signed_cert_key[0].private_key_pem
  is_ca_certificate = false

  subject {
    common_name  = "internal-alb.local"
    organization = "Internal"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["internal-alb.local"]
}

############################################
# Self signed Cert Binding to Internal ALB #
############################################

resource "google_compute_region_ssl_certificate" "internal_alb_cert_binding" {
  count       = local.enable_demo_web_app ? 1 : 0
  project     = local.project_id
  region      = local.region
  name        = "internal-alb-cert-binding"
  private_key = tls_private_key.self_signed_cert_key[0].private_key_pem
  certificate = tls_self_signed_cert.self_signed_cert[0].cert_pem
}

######################################
# Internal Application Load Balancer #
######################################

resource "google_compute_region_url_map" "internal_alb_url_map" {
  count           = local.enable_demo_web_app ? 1 : 0
  project         = local.project_id
  name            = "internal-alb-url-map"
  region          = local.region
  default_service = google_compute_region_backend_service.demo_web_app_internal_backend[0].id
}

resource "google_compute_region_target_https_proxy" "internal_alb_https_proxy" {
  count            = local.enable_demo_web_app ? 1 : 0
  project          = local.project_id
  name             = "internal-alb-https-proxy"
  region           = local.region
  url_map          = google_compute_region_url_map.internal_alb_url_map[0].id
  ssl_certificates = [google_compute_region_ssl_certificate.internal_alb_cert_binding[0].id]
}

resource "google_compute_forwarding_rule" "internal_alb_forwarding_rule" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  name                  = "internal-alb-forwarding-rule"
  region                = local.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.internal_alb_https_proxy[0].id
  network               = google_compute_network.web_vpc[0].id
  subnetwork            = google_compute_subnetwork.web_subnet[0].id
  network_tier          = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy_only_subnet]
}

##########################
# PSC Service Attachment #
##########################

resource "google_compute_service_attachment" "demo_web_app_psc_attachment" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  name                  = "demo-web-app-psc-attachment"
  region                = local.region
  connection_preference = "ACCEPT_AUTOMATIC"

  nat_subnets    = [google_compute_subnetwork.psc_nat_subnet[0].id]
  target_service = google_compute_forwarding_rule.internal_alb_forwarding_rule[0].id

  enable_proxy_protocol = false
}
