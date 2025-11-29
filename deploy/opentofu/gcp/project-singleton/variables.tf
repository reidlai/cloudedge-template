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

variable "billing_account" {
  description = "The GCP Billing Account ID."
  type        = string
}

variable "project_id" {
  description = "The GCP Project ID where resources will be deployed."
  type        = string
}

variable "region" {
  description = "The primary GCP region for regional resources."
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

variable "managed_ssl_domain" {
  description = "The domain name to use for the Google-managed SSL certificate."
  type        = string
  default     = ""
}

variable "privateca_ca_pool_name" {
  description = "The name of the Private CA pool."
  type        = string
}

variable "privateca_location" {
  description = "The location for the Private CA pool. If not provided, defaults to var.region."
  type        = string
  default     = ""
}

variable "enable_private_ca" {
  description = "If true, use the Google Managed Private CA module for the load balancer."
  type        = bool
  default     = true
}

variable "authorized_ca_users" {
  description = "List of IAM members (e.g. serviceAccount:name@project.iam.gserviceaccount.com) authorized to request certificates from the Private CA."
  type        = list(string)
  default     = []
}

variable "enable_billing" {
  description = "If true, deploy the billing budget and alert module."
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "If set to true, create a Cloud Logging bucket for the demo backend (NFR-001 compliance). Set to false for fast testing iterations to avoid 1-7 day bucket deletion delays."
  type        = bool
  default     = true
}
