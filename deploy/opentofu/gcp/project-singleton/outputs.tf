output "project_suffix" {
  description = "The project suffix (nonprod or prod)."
  value       = local.project_suffix
}
output "project_id" {
  description = "The ID of the GCP project."
  value       = data.google_project.current.project_id
}

output "billing_budget_id" {
  description = "The ID of the billing budget."
  value       = google_billing_budget.budget.id
}

output "logs_bucket_id" {
  description = "The ID of the logging bucket."
  value       = local.enable_logging ? google_logging_project_bucket_config.logs_bucket[0].id : null
}

output "enable_logging" {
  description = "Indicates if logging is enabled."
  value       = local.enable_logging
}

output "external_https_lb_cert_id" {
  description = "The ID of the SSL certificate for the external HTTPS load balancer (either self-signed or managed)."
  value       = local.enable_self_signed_cert ? (length(google_compute_region_ssl_certificate.external_https_lb_cert) > 0 ? google_compute_region_ssl_certificate.external_https_lb_cert[0].id : null) : (length(google_compute_managed_ssl_certificate.external_https_lb_cert) > 0 ? google_compute_managed_ssl_certificate.external_https_lb_cert[0].id : null)
}
