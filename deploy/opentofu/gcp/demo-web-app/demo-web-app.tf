
###################
# Local Variables #
###################

locals {
  # Project Variables
  project_suffix              = var.project_suffix
  region                      = var.region
  cloudedge_github_repository = var.cloudedge_github_repository
  standard_tags = merge(
    var.resource_tags,
    {
      "project"    = local.project_id
      "managed-by" = "opentofu"
    }
  )
  cloudedge_project_id = var.cloudedge_project_id

  # Demo Web App Variables
  enable_web_app                = var.enable_demo_web_app
  project_id                    = var.demo_web_app_project_id
  web_app_service_name          = var.demo_web_app_service_name
  web_app_image                 = var.demo_web_app_image
  enable_self_signed_cert       = var.enable_demo_web_app_self_signed_cert
  enable_internal_alb           = var.enable_demo_web_app_internal_alb
  enable_psc_neg                = var.enable_demo_web_app_psc_neg
  web_vpc_name                  = var.demo_web_app_web_vpc_name
  web_subnet_cidr_range         = var.demo_web_app_web_subnet_cidr_range
  proxy_only_subnet_cidr_range  = var.demo_web_app_proxy_only_subnet_cidr_range
  psc_nat_subnet_cidr_range     = var.demo_web_app_psc_nat_subnet_cidr_range
  web_app_port                  = var.demo_web_app_port
  min_concurrent_deployments    = var.demo_web_app_min_concurrent_deployments
  max_concurrent_deployments    = var.demo_web_app_max_concurrent_deployments
  web_app_neg_name              = "${local.web_app_service_name}-neg"
  web_app_internal_backend_name = "${local.web_app_service_name}-internal-backend"
}

#############
# Providers #
#############

provider "google" {
  project = local.project_id
  region  = local.region
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
}

################
# Data Sources #
################

data "terraform_remote_state" "singleton" {
  backend = "gcs"
  config = {
    bucket = "${local.cloudedge_project_id}-tfstate"
    prefix = "${local.cloudedge_project_id}-singleton"
  }
}

data "google_project" "current" {
  project_id = local.project_id
}

###########
# Web VPC #
###########

resource "google_compute_network" "web_vpc" {
  count                   = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project                 = local.project_id
  name                    = local.web_vpc_name
  auto_create_subnetworks = false
}

##############
# Web Subnet #
##############

resource "google_compute_subnetwork" "web_subnet" {
  count                    = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project                  = local.project_id
  name                     = "${local.web_app_service_name}-web-subnet"
  ip_cidr_range            = local.web_subnet_cidr_range
  region                   = local.region
  network                  = google_compute_network.web_vpc[0].id
  private_ip_google_access = true
}


#################################################
# Proxy-only subnet (required for Internal ALB) #
#################################################

resource "google_compute_subnetwork" "proxy_only_subnet" {
  count         = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project       = local.project_id
  name          = "${local.web_app_service_name}-proxy-only-subnet"
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
  count         = local.enable_web_app && local.enable_psc_neg ? 1 : 0
  project       = local.project_id
  name          = "${local.web_app_service_name}-psc-nat-subnet"
  ip_cidr_range = local.psc_nat_subnet_cidr_range
  region        = local.region
  network       = google_compute_network.web_vpc[0].id
  purpose       = "PRIVATE_SERVICE_CONNECT"
  depends_on    = [google_compute_network.web_vpc]
}

##########################
# Demo Web App Cloud Run #
##########################

resource "google_cloud_run_v2_service" "web_app" {
  count               = local.enable_web_app ? 1 : 0
  project             = local.project_id
  name                = local.web_app_service_name
  location            = local.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false
  template {
    containers {
      image = local.web_app_image
      ports {
        container_port = local.web_app_port
      }
    }
    scaling {
      min_instance_count = local.min_concurrent_deployments
      max_instance_count = local.max_concurrent_deployments
    }
    labels = local.standard_tags
  }
}

#########################################################################################
# Serverless Network Endpoint Group (NEG) for the demo web app Cloud Run service        #
# NEG points directly to the Cloud Run service, serving as the load balancer's backend. #
#########################################################################################

resource "google_compute_region_network_endpoint_group" "web_app_neg" {
  count   = local.enable_web_app ? 1 : 0
  project = local.project_id
  name    = local.web_app_neg_name
  region  = local.region
  # the SERVERLESS type that points to Cloud Run. The PRIVATE_SERVICE_CONNECT NEG is created by consumers in their own projects/VPCs to connect to your PSC Service
  # Attachment.
  network_endpoint_type = local.enable_psc_neg && (local.cloudedge_project_id != local.project_id) ? "PRIVATE_SERVICE_CONNECT" : "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.web_app[0].name
  }
}

################################
# Demo Web App Backend Service #
################################

resource "google_compute_region_backend_service" "web_app_backend" {
  count                 = local.enable_web_app ? 1 : 0
  project               = local.project_id
  name                  = local.web_app_internal_backend_name
  region                = local.region
  protocol              = "HTTPS"
  load_balancing_scheme = (local.enable_internal_alb || local.enable_psc_neg) ? "INTERNAL_MANAGED" : "EXTERNAL_MANAGED"
  timeout_sec           = 30

  backend {
    group           = google_compute_region_network_endpoint_group.web_app_neg[0].id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

#################
# Cloud Run IAM #
#################

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = local.enable_web_app ? 1 : 0
  name     = google_cloud_run_v2_service.web_app[0].name
  project  = local.project_id
  location = local.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"

  depends_on = [
    google_cloud_run_v2_service.web_app
  ]
}

#################################################################
# Self-signed certificate for Internal ALB HTTPS Load Balancing #
#################################################################

resource "tls_private_key" "self_signed_cert_key" {
  count     = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed_cert" {
  count             = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
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

  dns_names = ["${local.web_app_service_name}-internal-alb.local"]
}

############################################
# Self signed Cert Binding to Internal ALB #
############################################

resource "google_compute_region_ssl_certificate" "internal_alb_cert_binding" {
  count       = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project     = local.project_id
  region      = local.region
  name        = "${local.web_app_service_name}--internal-alb-cert-binding"
  private_key = tls_private_key.self_signed_cert_key[0].private_key_pem
  certificate = tls_self_signed_cert.self_signed_cert[0].cert_pem
}

######################################
# Internal Application Load Balancer #
######################################

resource "google_compute_region_url_map" "internal_alb_url_map" {
  count           = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project         = local.project_id
  name            = "${local.web_app_service_name}-internal-alb-url-map"
  region          = local.region
  default_service = google_compute_region_backend_service.web_app_backend[0].id
}

resource "google_compute_region_target_https_proxy" "internal_alb_https_proxy" {
  count            = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project          = local.project_id
  name             = "${local.web_app_service_name}-internal-alb-https-proxy"
  region           = local.region
  url_map          = google_compute_region_url_map.internal_alb_url_map[0].id
  ssl_certificates = [google_compute_region_ssl_certificate.internal_alb_cert_binding[0].id]
}

resource "google_compute_forwarding_rule" "internal_alb_forwarding_rule" {
  count                 = local.enable_web_app && (local.enable_internal_alb || local.enable_psc_neg) ? 1 : 0
  project               = local.project_id
  name                  = "${local.web_app_service_name}-internal-alb-forwarding-rule"
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

resource "google_compute_service_attachment" "web_app_psc_attachment" {
  count                 = local.enable_psc_neg ? 1 : 0
  project               = local.project_id
  name                  = "${local.web_app_service_name}-psc-attachment"
  region                = local.region
  connection_preference = "ACCEPT_AUTOMATIC"

  nat_subnets    = [google_compute_subnetwork.psc_nat_subnet[0].id]
  target_service = google_compute_forwarding_rule.internal_alb_forwarding_rule[0].id

  enable_proxy_protocol = false
}
