locals {
  project_id                = var.project_id
  demo_web_app_service_name = "${var.project_suffix}-demo-web-app"
  demo_web_app_neg_name     = "${var.project_suffix}-demo-web-app-neg"
  demo_web_app_backend_name = "${var.project_suffix}-demo-web-app-backend"
  standard_tags = merge(
    var.resource_tags,
    {
      "project-suffix" = var.project_suffix
      "project"        = local.project_id
      "managed-by"     = "opentofu"
    }
  )
}
