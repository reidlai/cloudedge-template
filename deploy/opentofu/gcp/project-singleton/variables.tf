variable "cloudedge_github_repository" {
  description = "The GitHub repository name for the Cloud Edge project excluding owner name"
  type        = string
}

variable "project_suffix" {
  description = "Project suffix (nonprod or prod). Combined with cloudedge_github_repository to form project_id."
  type        = string
  validation {
    condition     = contains(["nonprod", "prod"], var.project_suffix)
    error_message = "project_suffix must be 'nonprod' or 'prod'."
  }
}

variable "region" {
  description = "The primary GCP region for regional resources."
  type        = string
  default     = "northamerica-northeast2"
}

variable "project_id" {
  description = "The GCP Project ID where resources will be deployed."
  type        = string
}

variable "billing_account_name" {
  description = "The GCP Billing Account Name."
  type        = string
}

variable "budget_amount" {
  description = "The budget amount in the specified currency for the billing budget."
  type        = number
  default     = 1000
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

variable "enable_logging" {
  description = "If set to true, create a Cloud Logging bucket for the demo backend (NFR-001 compliance). Set to false for fast testing iterations to avoid 1-7 day bucket deletion delays."
  type        = bool
  default     = true
}

variable "enable_self_signed_cert" {
  description = "If true, a self-signed TLS certificate will be created instead of using ACME."
  type        = bool
  default     = false
}

variable "demo_web_app_subdomain_name" {
  description = "The subdomain name for the application"
  type        = string
  default     = "demo-web-app"
}

variable "root_domain" {
  description = "The root domain name"
  type        = string
  default     = "vibetics.com"
}

# Cloudflare DNS Integration Variables
variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions"
  type        = string
  sensitive   = true
}
