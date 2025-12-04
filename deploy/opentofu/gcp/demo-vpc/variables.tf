variable "project_suffix" {
  description = "Project suffix (nonprod or prod). Combined with cloudedge_github_repository to form project_id."
  type        = string
  validation {
    condition     = contains(["nonprod", "prod"], var.project_suffix)
    error_message = "project_suffix must be 'nonprod' or 'prod'."
  }
}

variable "cloudedge_github_repository" {
  description = "The GitHub repository name for the Cloud Edge project excluding owner name"
  type        = string
}

variable "region" {
  description = "The primary GCP region for regional resources."
  type        = string
}

variable "project_id" {
  description = "The GCP Project ID where resources will be deployed."
  type        = string
}


variable "resource_tags" {
  description = "A map of tags to apply to all resources. 'project-suffix' and 'managed-by' are mandatory."
  type        = map(string)

  validation {
    condition = (
      contains(keys(var.resource_tags), "project-suffix") &&
      contains(keys(var.resource_tags), "managed-by")
    )
    error_message = "resource_tags must contain 'project-suffix' and 'managed-by' keys for compliance with FR-007."
  }

  default = {
    "managed-by"     = "opentofu"
    "project-suffix" = "nonprod"
  }
}

variable "enable_demo_web_app" {
  description = "If set to true, demo-web-app docker will be deployed in Cloud Run"
  type        = bool
}

variable "web_vpc_cidr_range" {
  description = "The CIDR range for the VPC Access Connector subnet."
  type        = string
  default     = "10.0.3.0/24"
}

variable "demo_web_app_image" {
  description = "Docker image for Demo Web App Cloud Run deployment"
  type        = string
}
