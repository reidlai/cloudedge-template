
output "demo_web_app_backend_service_id" {
  description = "The ID of the backend service for the demo Web App."
  value       = one(google_compute_backend_service.demo_web_app[*].id)
}

output "demo_web_app_backend_service_name" {
  description = "The name of the backend service for the demo Web App."
  value       = one(google_compute_backend_service.demo_web_app[*].name)
}

output "demo_web_app_cloud_run_service_name" {
  description = "The name of the Cloud Run service."
  value       = one(google_cloud_run_v2_service.demo_web_app[*].name)
}

output "demo_web_app_cloud_run_service_uri" {
  description = "The URI of the Cloud Run service."
  value       = one(google_cloud_run_v2_service.demo_web_app[*].uri)
}

output "demo_web_app_serverless_neg_id" {
  description = "The ID of the Serverless Network Endpoint Group."
  value       = one(google_compute_region_network_endpoint_group.demo_web_app[*].id)
}
