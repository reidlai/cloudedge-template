resource "google_cloud_run_v2_service" "demo_web_app" {
  count    = var.enable_demo_web_app ? 1 : 0
  project  = var.project_id
  name     = local.demo_web_app_service_name
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
  labels              = local.standard_tags
}
