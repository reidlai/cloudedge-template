resource "google_cloud_run_service_iam_member" "invoker" {
  count    = var.enable_demo_web_app ? 1 : 0
  project  = var.project_id
  service  = google_cloud_run_v2_service.demo_web_app[0].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
