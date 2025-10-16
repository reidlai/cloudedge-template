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

  # Allow traffic from Google Cloud Load Balancers and internal VPC
  # INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER allows both internal VPC access
  # and access from Google Cloud Load Balancers (required for this architecture)
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
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
    enable      = true
    sample_rate = 1.0 # Log 100% of requests for full observability (NFR-001)
  }
}

# Configure Cloud Logging retention for backend service logs
# NFR-001 requires 30-day minimum retention for distributed tracing
resource "google_logging_project_sink" "backend_service_logs" {
  project     = var.project_id
  name        = "${var.environment}-demo-backend-logs-sink"
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.backend_logs_bucket.id}"
  filter      = "resource.type=\"http_load_balancer\" AND resource.labels.backend_service_name=\"${google_compute_backend_service.demo_backend.name}\""
}

resource "google_logging_project_bucket_config" "backend_logs_bucket" {
  project        = var.project_id
  location       = "global"
  retention_days = 30 # NFR-001: 30-day trace data retention
  bucket_id      = "${var.environment}-demo-backend-logs"
  description    = "30-day retention bucket for demo backend service logs (NFR-001 compliance)"
}

# Grant Cloud Run Invoker role to allow unauthenticated access from load balancer
# This is required for internal-only Cloud Run services accessed via load balancer
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  service  = google_cloud_run_v2_service.demo_api.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---Outputs---
output "backend_service_id" {
  description = "The ID of the backend service for the demo API."
  value       = google_compute_backend_service.demo_backend.id
}