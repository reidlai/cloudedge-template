# resource "google_logging_project_sink" "demo_web_app_logs_sink" {
#   count       = var.enable_logging ? 1 : 0
#   project     = var.project_id
#   name        = "${var.project_suffix}-demo-web-app-logs-sink"
#   destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.logs_bucket[0].id}"
#   filter      = "resource.type=\"http_load_balancer\" AND resource.labels.backend_service_name=\"${google_compute_backend_service.demo_web_app[0].name}\""
# }
