resource "google_logging_project_bucket_config" "logs_bucket" {
  count          = var.enable_logging ? 1 : 0
  project        = var.project_id
  location       = "global"
  retention_days = 30 # NFR-001: 30-day trace data retention
  bucket_id      = "${var.project_id}-logs"
  description    = "30-day retention bucket for demo backend service logs (NFR-001 compliance)"

  # Note: lifecycle_state is managed by the provider and cannot be configured
  # The bucket transitions through states: CREATING -> ACTIVE -> DELETE_REQUESTED -> DELETED
  # No lifecycle block needed as lifecycle_state is read-only
}
