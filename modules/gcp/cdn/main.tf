resource "google_compute_backend_service" "cdn_backend" {
  project   = var.project_id
  name      = "${var.environment}-cdn-backend"
  enable_cdn = true
  # This is a placeholder, a real backend would point to an instance group or similar
  backend {
    group = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${var.region}-a/instanceGroups/placeholder-instance-group"
  }
}
