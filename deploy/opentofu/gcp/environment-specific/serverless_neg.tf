resource "google_compute_region_network_endpoint_group" "demo_web_app" {
  count                 = var.enable_demo_web_app ? 1 : 0
  project               = var.project_id
  name                  = local.demo_web_app_neg_name
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.demo_web_app[0].name
  }
}
