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

    # Connect Cloud Run to the web VPC via VPC Access Connector
    # Since you have already chosen ALL_TRAFFIC, my main suggestion is to verify the VPC routing and firewall setup downstream of the connector:
    #
    # | Configuration Area  | Suggested Action                                                                                                                           | OpenTofu/GCP Resource to Check                                    |
    # | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------- |
    # | Outbound IP Control | Ensure a Cloud NAT gateway is configured for the subnet the connector is using.                                                            | google_compute_router_nat                                         |
    # | Firewall Rules      | Ensure your VPC Firewall rules are correctly configured to allow the necessary outbound traffic from the connector's subnet.               | google_compute_firewall                                           |
    # | Private Access      | Ensure the VPC peering/Shared VPC is set up correctly if the connector is in a different project/VPC than the resources it needs to reach. | google_service_networking_connection (for Private Service Access) |
    #
    dynamic "vpc_access" {
      for_each = var.enable_web_vpc ? [1] : []
      content {
        connector = data.google_vpc_access_connector.web_connector[0].id
        egress    = "ALL_TRAFFIC" # Route all egress through VPC for network isolation
      }
    }
  }

  # Allow traffic from Google Cloud Load Balancers only
  # INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER restricts access to:
  # - Google Cloud Load Balancers (via Serverless NEG)
  # - Internal VPC traffic (via VPC Connector)
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false
  labels              = local.standard_tags
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = var.enable_demo_web_app ? 1 : 0
  name     = local.demo_web_app_service_name
  project  = var.project_id
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
