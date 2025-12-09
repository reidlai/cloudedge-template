####################
# Output Variables #
####################

output "demo_web_app_psc_service_attachment_self_link" {
  description = "The ID of the PSC Service Attachment for use by consumers"
  value       = local.enable_demo_web_app ? google_compute_service_attachment.demo_web_app_psc_attachment[0].id : null
}

output "psc_enabled" {
  description = "Indicates whether Private Service Connect (PSC) is enabled for this module."
  value       = local.enable_psc
}
