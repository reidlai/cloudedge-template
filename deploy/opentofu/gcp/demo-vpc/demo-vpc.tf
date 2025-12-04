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

  enable_demo_web_app       = var.enable_demo_web_app
  web_vpc_cidr_range        = var.web_vpc_cidr_range
  demo_web_app_service_name = "demo-web-app"
  demo_web_app_image        = var.demo_web_app_image

  demo_web_app_neg_name = "${local.demo_web_app_service_name}-neg"
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

###############
# Google APIs #
###############

resource "google_project_service" "run" {
  project            = local.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

############################
# Web VPC for demo web app #
############################

resource "google_compute_network" "web_vpc" {
  count                   = local.enable_demo_web_app ? 1 : 0
  project                 = local.project_id
  name                    = "demo-web-vpc"
  auto_create_subnetworks = false
}

##############
# Web Subnet #
##############

# Required for Regional Internal Application Load Balancer
resource "google_compute_subnetwork" "proxy_only_subnet" {
  count         = local.enable_demo_web_app ? 1 : 0
  project       = local.project_id
  name          = "${var.project_suffix}-alb-proxy-subnet"
  ip_cidr_range = "10.0.99.0/24" # Choose a non-overlapping range
  network       = google_compute_network.web_vpc[0].name
  region        = local.region
  # This purpose is mandatory for the ALB's proxy-only subnet
  purpose = "REGIONAL_MANAGED_PROXY"
  role    = "ACTIVE"
}

resource "google_compute_subnetwork" "web_subnet" {
  count                    = local.enable_demo_web_app ? 1 : 0
  project                  = local.project_id
  name                     = "${var.project_suffix}-web-subnet"
  ip_cidr_range            = local.web_vpc_cidr_range
  network                  = google_compute_network.web_vpc[0].name
  region                   = local.region
  private_ip_google_access = true # CIS GCP Foundation Benchmark 3.9 - Enable Private Google Access
}

#############
# Cloud Run #
#############

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

#################
# Cloud Run IAM #
#################

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = local.enable_demo_web_app ? 1 : 0
  # FIX: Use the actual Cloud Run service name/reference
  name     = google_cloud_run_v2_service.demo_web_app[0].name
  project  = local.project_id
  location = local.region
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [
    google_cloud_run_v2_service.demo_web_app
  ]
}
######################################
# Internal Application Load Balancer #
######################################

# 1. Backend Service (attaches the Serverless NEG)
resource "google_compute_region_backend_service" "web_vpc_internal_alb" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  name                  = "web-vpc-internal-alb"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"

  # Reference the existing Serverless NEG
  backend {
    group = google_compute_region_network_endpoint_group.demo_web_app[0].id
  }
}

# 2. URL Map (routes to the backend service)
resource "google_compute_region_url_map" "web_vpc_internal_alb" {
  count           = local.enable_demo_web_app ? 1 : 0
  project         = local.project_id
  name            = "web-vpc-internal-alb"
  region          = local.region # REQUIRED for Regional ALB
  default_service = google_compute_region_backend_service.web_vpc_internal_alb[0].id
}

# 3. Target HTTP Proxy (sends traffic to the URL Map)
resource "google_compute_region_target_http_proxy" "web_vpc_internal_alb" {
  count   = local.enable_demo_web_app ? 1 : 0
  project = local.project_id
  # FIX: Change underscore to hyphen
  name   = "web-vpc-internal-alb"
  region = local.region # REQUIRED for Regional ALB
  # Update reference to the new regional URL Map
  url_map = google_compute_region_url_map.web_vpc_internal_alb[0].id
}

# 4. Forwarding Rule (the internal IP endpoint)
resource "google_compute_forwarding_rule" "web_vpc_internal_alb" {
  count   = local.enable_demo_web_app ? 1 : 0
  project = local.project_id
  name    = "web-vpc-internal-alb"
  region  = local.region

  # CORRECTED: Use the client-facing subnet (web_subnet) for the IP
  subnetwork = google_compute_subnetwork.web_subnet[0].id

  network_tier          = "PREMIUM"
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_http_proxy.web_vpc_internal_alb[0].id

  # CORRECTED: Use a static IP address within the web_subnet CIDR range (e.g., 10.0.3.0/24)
  ip_address = "10.0.3.10"
  port_range = "80-80"
}

##################
# Firewall Rules #
##################

# Allow traffic from the Internal ALB's Proxy-Only Subnet to your backend service (Cloud Run)
# This is crucial because the proxy IPs in this subnet are the source for traffic hitting Cloud Run.
resource "google_compute_firewall" "allow_alb_proxy_ingress" {
  count   = local.enable_demo_web_app ? 1 : 0
  project = local.project_id
  name    = "${local.project_suffix}-allow-alb-proxy-ingress"
  network = google_compute_network.web_vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["80"] # Assuming your Cloud Run service listens on port 80
  }

  source_ranges = [google_compute_subnetwork.proxy_only_subnet[0].ip_cidr_range]
  direction     = "INGRESS"
  priority      = 900
}

# Allow internal traffic from client subnets (e.g., client VMs in the shared VPC)
# to the Internal ALB's frontend IP (10.0.3.10)
resource "google_compute_firewall" "allow_client_ingress_to_alb" {
  count   = local.enable_demo_web_app ? 1 : 0
  project = local.project_id
  name    = "${local.project_suffix}-allow-client-alb"
  network = google_compute_network.web_vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["80"] # ALB listens on port 80
  }

  # CORRECTED: Use the CIDR block of the client-facing subnet
  source_ranges = [google_compute_subnetwork.web_subnet[0].ip_cidr_range]

  direction = "INGRESS"
  priority  = 950
}
