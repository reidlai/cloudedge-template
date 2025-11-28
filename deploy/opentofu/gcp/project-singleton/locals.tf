locals {
  # Compute project_id from repository name and suffix
  project_id = "${var.cloudedge_github_repository}-${var.project_suffix}"
}


locals {
  # Merge user-provided tags with mandatory tags
  standard_tags = merge(
    var.resource_tags,
    {
      "project-suffix" = var.project_suffix
      "project"        = local.project_id
      "managed-by"     = "opentofu"
    }
  )
}
