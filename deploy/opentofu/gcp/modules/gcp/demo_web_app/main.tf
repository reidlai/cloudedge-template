# ---Cloud Run service for the demo Web App---
# Note: Uses Serverless NEG for Load Balancer connectivity (no VPC Connector needed)
resource "google_cloud_run_v2_service" "demo_web_app" {
  project  = var.project_id
  name     = "${var.project_suffix}-demo-web-app"
  location = var.region

  template {
    containers {
      image = var.demo_web_app_image
    }
    scaling {
      min_instance_count = 0 # Scale to zero for cost-effectiveness
    }
    labels = var.resource_tags
  }

  # Allow traffic from Google Cloud Load Balancers only
  # INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER restricts access to:
  # - Google Cloud Load Balancers (via Serverless NEG)
  # - Internal VPC traffic (if VPC Connector were configured)
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false
  labels              = var.resource_tags
}

# ---Serverless NEG for Load Balancer Integration---
# Serverless NEG provides Google-managed connectivity for Cloud Run
# No VPC Connector needed - the load balancer connects directly to Cloud Run
# via Google's internal networking infrastructure
resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  project               = var.project_id
  name                  = "${var.project_suffix}-demo-web-app-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.demo_web_app.name
  }
}

resource "google_compute_backend_service" "demo_web_app" {
  project   = var.project_id
  name      = "${var.project_suffix}-demo-web-app-backend"
  protocol  = "HTTP"
  port_name = "http"
  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
  cdn_policy {
    # Enable Cloud CDN for this backend
    cache_key_policy {
      include_host         = true
      include_protocol     = true
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
# NOTE: Set enable_logging_bucket=false for fast testing iterations to avoid 1-7 day bucket deletion delays
resource "google_logging_project_sink" "backend_service_logs" {
  count       = var.enable_logging_bucket ? 1 : 0
  project     = var.project_id
  name        = "${var.project_suffix}-demo-web-app-logs-sink"
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.backend_logs_bucket[0].id}"
  filter      = "resource.type=\"http_load_balancer\" AND resource.labels.backend_service_name=\"${google_compute_backend_service.demo_web_app.name}\""
}

resource "google_logging_project_bucket_config" "backend_logs_bucket" {
  count          = var.enable_logging_bucket ? 1 : 0
  project        = var.project_id
  location       = "global"
  retention_days = 30 # NFR-001: 30-day trace data retention
  bucket_id      = "${var.project_suffix}-demo-web-app-logs"
  description    = "30-day retention bucket for demo backend service logs (NFR-001 compliance)"

  # Note: lifecycle_state is managed by the provider and cannot be configured
  # The bucket transitions through states: CREATING -> ACTIVE -> DELETE_REQUESTED -> DELETED
  # No lifecycle block needed as lifecycle_state is read-only
}

# Grant Cloud Run Invoker role to allow unauthenticated access from load balancer
#
# SECURITY NOTE: This uses allUsers for INFRASTRUCTURE VALIDATION ONLY
#
# Why allUsers is used:
# - Cloud Run with INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER requires IAM authentication
# - Load balancers cannot authenticate with service accounts when forwarding traffic
# - allUsers allows the load balancer to invoke the service without auth credentials
#
# Security Boundary:
# - Network-level security: WAF (DDoS), Firewall rules, VPC isolation, PSC
# - Application-level security: OUT OF SCOPE (see plan.md "API Management" section)
#
# Production Recommendation:
# - Applications should implement authentication WITHIN their service code
# - OR deploy API Gateway (Cloud Endpoints/Apigee) for API-level auth
# - This infrastructure provides NETWORK security, not APPLICATION security
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  service  = google_cloud_run_v2_service.demo_web_app.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
