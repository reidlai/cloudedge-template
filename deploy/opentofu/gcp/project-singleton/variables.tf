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

variable "cloudedge_github_owner" {
  description = "The GitHub owner name for the Cloud Edge project"
  type        = string
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

variable "domain_name" {
  description = "The domain name for the certificate. If not provided, defaults to var.managed_ssl_domain."
  type        = string
  default     = ""
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

# variable "enable_demo_web_app" {
#   description = "If set to true, the demo_web_app module will be enabled."
#   type        = bool
#   default     = false
# }

variable "enable_dr_loadbalancer" {
  description = "If set to true, the dr_loadbalancer module will be enabled."
  type        = bool
  default     = false
}

# Fix I1: VPC Peering variable removed - not required for PSC architecture
# Cloud Run uses Serverless NEG for direct PSC connectivity to load balancer
# VPC Peering only needed for GKE/VM backends (future feature)

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

variable "enable_cdn" {
  description = "If set to true, the cdn module will be enabled."
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "If set to true, create a Cloud Logging bucket for the demo backend (NFR-001 compliance). Set to false for fast testing iterations to avoid 1-7 day bucket deletion delays."
  type        = bool
  default     = true
}

variable "url_map_host_rules" {
  description = "A list of host rules for the URL map."
  type        = any
  default     = []
}

variable "url_map_path_matchers" {

  description = "A map of path matchers for the URL map."

  type = any

  default = {}

}

variable "ssl_certificates" {
  description = "A list of SSL certificate self_links to attach to the HTTPS proxy."
  type        = list(string)
  default     = []
}

variable "certificate_map" {
  description = "The ID of the Certificate Map to attach to the HTTPS proxy (Certificate Manager)."
  type        = string
  default     = null
}

variable "allowed_https_source_ranges" {
  description = <<-EOT
    List of CIDR ranges allowed to access the HTTPS endpoint on the ingress VPC.
    Defaults to Google Cloud Load Balancer IP ranges for defense-in-depth security.

    Google Cloud Load Balancer IP ranges (as of 2024):
    - 35.191.0.0/16 (health checks and proxy IPs)
    - 130.211.0.0/22 (legacy health checks)

    WARNING: Using ["0.0.0.0/0"] allows traffic from ANY IP address and relies solely
    on WAF (Cloud Armor) for edge protection. This is acceptable for demo/testing but
    NOT recommended for production without explicit risk acceptance.
  EOT
  type        = list(string)
  default     = ["35.191.0.0/16", "130.211.0.0/22"]
}

variable "authorized_members" {
  description = "List of IAM members (users, service accounts, groups) authorized to request certificates from this CA Pool (FR-017)."
  type        = list(string)
  default     = []
}
