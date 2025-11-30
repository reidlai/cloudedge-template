resource "google_logging_project_bucket_config" "logs_bucket" {
  count          = var.enable_logging ? 1 : 0
  project        = var.project_id
  location       = "global"
  retention_days = 30 # NFR-001: 30-day trace data retention
  bucket_id      = "${var.project_id}-logs"
  description    = "30-day retention bucket for demo backend service logs (NFR-001 compliance)"

}
