variable "cloud_provider" {
  description = "The cloud provider to use for deployment (e.g., 'gcp', 'aws', 'azure')."
  type        = string
  default     = "gcp"
}

variable "project_suffix" {
  description = "Project suffix (nonprod or prod). Combined with cloudedge_github_repository to form project_id."
  type        = string
  validation {
    condition     = contains(["nonprod", "prod"], var.project_suffix)
    error_message = "project_suffix must be 'nonprod' or 'prod'."
  }
}

variable "cloudedge_github_repository" {
  description = "The GitHub repository name for the Cloud Edge project (e.g., 'vibetics-cloudedge')."
  type        = string
}

variable "billing_account" {
  description = "The GCP Billing Account ID."
  type        = string
}

variable "ingress_vpc_cidr_range" {
  description = "The CIDR range for the ingress VPC subnetwork."
  type        = string
  default     = "10.0.1.0/24"
}

variable "egress_vpc_cidr_range" {
  description = "The CIDR range for the egress VPC subnetwork."
  type        = string
  default     = "10.0.2.0/24"
}

variable "region" {
  description = "The primary GCP region for regional resources."
  type        = string
}

variable "max_concurrent_deployments" {
  description = "The maximum number of concurrent infrastructure deployments."
  type        = number
  default     = 1
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

variable "demo_api_image" {
  description = "The container image to use for the demo API."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}



variable "enable_ingress_vpc" {
  description = "If set to true, the ingress_vpc module will be enabled."
  type        = bool
  default     = false
}

variable "enable_egress_vpc" {
  description = "If set to true, the egress_vpc module will be enabled."
  type        = bool
  default     = false
}

variable "enable_firewall" {
  description = "If set to true, the firewall module will be enabled."
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "If set to true, the waf module will be enabled."
  type        = bool
  default     = false
}

variable "enable_demo_backend" {
  description = "If set to true, the demo_backend module will be enabled."
  type        = bool
  default     = false
}

variable "enable_dr_loadbalancer" {
  description = "If set to true, the dr_loadbalancer module will be enabled."
  type        = bool
  default     = false
}

# Fix I1: VPC Peering variable removed - not required for PSC architecture
# Cloud Run uses Serverless NEG for direct PSC connectivity to load balancer
# VPC Peering only needed for GKE/VM backends (future feature)

variable "enable_self_signed_cert" {
  description = "If true, use the self-signed certificate module for the load balancer. Otherwise, create a Google-managed SSL certificate."
  type        = bool
  default     = false
}

variable "enable_billing" {
  description = "If true, deploy the billing budget and alert module."
  type        = bool
  default     = false
}

variable "enable_cdn" {
  description = "If set to true, the cdn module will be enabled."
  type        = bool
  default     = false
}

variable "enable_logging_bucket" {
  description = "If set to true, create a Cloud Logging bucket for the demo backend (NFR-001 compliance). Set to false for fast testing iterations to avoid 1-7 day bucket deletion delays."
  type        = bool
  default     = true
}
