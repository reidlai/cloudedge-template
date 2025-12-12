####################
# Output Variables #
####################

output "web_app_psc_service_attachment_self_link" {
  description = "The ID of the PSC Service Attachment for use by consumers"
  value       = local.enable_web_app && local.enable_psc_neg ? google_compute_service_attachment.web_app_psc_attachment[0].id : null
}

output "web_app_cloud_run_service_name" {
  description = "The name of the demo web app Cloud Run service."
  value       = local.enable_web_app ? google_cloud_run_v2_service.web_app[0].name : null
}

output "web_app_backend_service_id" {
  description = "The ID of the demo web app backend service."
  value       = local.enable_web_app ? google_compute_region_backend_service.web_app_backend[0].id : null
}

output "psc_enabled" {
  description = "Indicates whether Private Service Connect (PSC) is enabled for this module."
  value       = local.enable_psc_neg
}
