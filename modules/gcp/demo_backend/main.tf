# ---VPC for the Cloud Run service---
resource "google_compute_network" "demo_vpc" {
  project                 = var.project_id
  name                    = "${var.environment}-demo-backend-vpc"
  auto_create_subnetworks = false
}

# ---VPC Connector for Cloud Run to access the VPC---
# Note: This requires the vpcaccess.googleapis.com API to be enabled.
resource "google_vpc_access_connector" "connector" {
  project        = var.project_id
  name           = "${var.environment}-vpc-connector"
  region         = var.region
  network        = google_compute_network.demo_vpc.name
  ip_cidr_range  = var.vpc_connector_cidr_range
  min_throughput = var.vpc_connector_min_throughput
  max_throughput = var.vpc_connector_max_throughput
  depends_on     = [google_compute_network.demo_vpc]
}

# ---Cloud Run service for the demo API---
resource "google_cloud_run_v2_service" "demo_api" {
  project  = var.project_id
  name     = "${var.environment}-demo-api"
  location = var.region

  template {
    containers {
      image = var.demo_api_image
    }
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "ALL_TRAFFIC"
    }
    scaling {
      min_instance_count = 0 # Scale to zero for cost-effectiveness
    }
    labels = var.resource_tags
  }

  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false
  labels              = var.resource_tags
}

# ---Default-deny egress firewall rule for the demo VPC---
resource "google_compute_firewall" "deny_all_egress" {
  project   = var.project_id
  name      = "${var.environment}-demo-deny-all-egress"
  network   = google_compute_network.demo_vpc.name
  direction = "EGRESS"
  priority  = 65535 # Lowest priority

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

# ---Network Integration---
resource "google_compute_network_peering" "ingress_to_demo" {
  name         = "${var.environment}-peering-ingress-to-demo"
  network      = var.ingress_vpc_self_link
  peer_network = google_compute_network.demo_vpc.self_link
  depends_on = [
    google_cloud_run_v2_service.demo_api,
  ]
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  project               = var.project_id
  name                  = "${var.environment}-serverless-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.demo_api.name
  }
  depends_on = [google_compute_network_peering.ingress_to_demo]
}

resource "google_compute_backend_service" "demo_backend" {
  project   = var.project_id
  name      = "${var.environment}-demo-api-backend"
  protocol  = "HTTP"
  port_name = "http"
  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
  cdn_policy {
    # Enable Cloud CDN for this backend
    cache_key_policy {
      include_host = true
      include_protocol = true
      include_query_string = true
    }
  }
  log_config {
    enable = true
  }
}

# ---Outputs---
output "backend_service_id" {
  description = "The ID of the backend service for the demo API."
  value       = google_compute_backend_service.demo_backend.id
}