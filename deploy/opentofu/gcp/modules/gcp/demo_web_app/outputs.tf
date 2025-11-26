# ============================================================================
# Demo Web App Module Outputs
# ============================================================================
# Exports backend service information for load balancer integration
# Referenced by: DR Load Balancer module

output "backend_service_id" {
  description = "The ID of the backend service for the demo Web App."
  value       = google_compute_backend_service.demo_web_app.id
}

output "backend_service_name" {
  description = "The name of the backend service for the demo Web App."
  value       = google_compute_backend_service.demo_web_app.name
}

output "cloud_run_service_name" {
  description = "The name of the Cloud Run service."
  value       = google_cloud_run_v2_service.demo_web_app.name
}

output "cloud_run_service_uri" {
  description = "The URI of the Cloud Run service."
  value       = google_cloud_run_v2_service.demo_web_app.uri
}

output "serverless_neg_id" {
  description = "The ID of the Serverless Network Endpoint Group."
  value       = google_compute_region_network_endpoint_group.serverless_neg.id
}
