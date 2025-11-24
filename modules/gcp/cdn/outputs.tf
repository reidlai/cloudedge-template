# ============================================================================
# CDN Module Outputs
# ============================================================================
# Exports CDN backend bucket information for load balancer integration
# Referenced by: DR Load Balancer module

output "cdn_backend_id" {
  description = "The ID of the CDN backend bucket"
  value       = google_compute_backend_bucket.cdn_backend.id
}

output "cdn_backend_name" {
  description = "The name of the CDN backend bucket"
  value       = google_compute_backend_bucket.cdn_backend.name
}

output "cdn_backend_self_link" {
  description = "The self-link of the CDN backend bucket"
  value       = google_compute_backend_bucket.cdn_backend.self_link
}
