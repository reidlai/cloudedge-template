# variable "cloud_provider" {
#   description = "The cloud provider to use for deployment (e.g., 'gcp', 'aws', 'azure')."
#   type        = string
#   default     = "gcp"
# }

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

variable "project_id" {
  description = "The GCP Project ID where resources will be deployed."
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

variable "demo_web_app_image" {
  description = "The container image to use for the demo Web App."
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

variable "enable_web_vpc" {
  description = "If set to true, the web VPC and VPC Access Connector will be created for Cloud Run network isolation."
  type        = bool
  default     = false
}

variable "web_vpc_cidr_range" {
  description = "The CIDR range for the web VPC subnetwork."
  type        = string
  default     = "10.0.3.0/24"
}

variable "vpc_connector_cidr_range" {
  description = "The CIDR range for the VPC Access Connector subnet. Must be /28 or larger."
  type        = string
  default     = "10.0.4.0/28"
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

variable "enable_demo_web_app" {
  description = "If set to true, the demo_web_app module will be enabled."
  type        = bool
  default     = false
}

variable "enable_dr_loadbalancer" {
  description = "If set to true, the dr_loadbalancer module will be enabled."
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
  default     = ["0.0.0.0/0"]
}

variable "url_map_host_rules" {
  description = "A map of host rules for the URL map in the load balancer."
  type = map(object({
    hosts        = list(string)
    path_matcher = string
  }))
  default = {}
}

variable "url_map_path_matchers" {
  description = "A map of path matchers for the URL map in the load balancer."
  type = map(object({
    default_service = string
    path_rules = optional(list(object({
      paths   = list(string)
      service = string
    })), [])
  }))
  default = {}
}

# Cloudflare DNS Integration Variables
variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for vibetics.com domain"
  type        = string
}

variable "subdomain_name" {
  description = "The subdomain name for the application"
  type        = string
  default     = "vibetics-agentportal-devtest"
}

variable "root_domain" {
  description = "The root domain name"
  type        = string
  default     = "vibetics.com"
}
