#############
# Variables #
#############

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

variable "root_domain" {
  description = "The root domain name"
  type        = string
  default     = "vibetics.com"
}

variable "demo_web_app_subdomain_name" {
  description = "The subdomain name for the application"
  type        = string
  default     = "demo-web-app"
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

variable "cloudflare_origin_ca_key" {
  description = "Cloudflare Origin CA Key for creating origin certificates. Optional - only needed when enable_cloudflare_proxy is true."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for vibetics.com domain"
  type        = string
}

variable "ingress_vpc_cidr_range" {
  description = "The CIDR range of the ingress VPC network."
  type        = string
  default     = "10.0.1.0/24"
}

variable "enable_demo_web_app" {
  description = "If set to true, demo-web-app docker will be deployed in Cloud Run"
  type        = bool
}

variable "proxy_only_subnet_cidr_range" {
  description = "The CIDR range for the proxy-only subnet required by Regional External ALB."
  type        = string
  default     = "10.0.98.0/24"
}

variable "enable_self_signed_cert" {
  description = "If true, a self-signed TLS certificate will be created instead of using ACME."
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "If true, GCP Cloud Armor WAF policies will be created and attached to backend services. If false, relies on Cloudflare WAF for protection."
  type        = bool
  default     = false
}

variable "enable_cloudflare_proxy" {
  description = "If true, Cloudflare proxy will be enabled (orange cloud) for DNS records, providing Cloudflare WAF, DDoS protection, and SSL. If false, DNS resolves directly to GCP load balancer."
  type        = bool
  default     = true
}

variable "enable_psc" {
  description = "If true, enables the creation of Private Service Connect (PSC) resources by default. Set to false to disable PSC provisioning."
  type        = bool
  default     = true
}

variable "enable_shared_vpc" {
  description = "If true, deploys the ingress VPC as a Shared VPC host project. Set to false to create a standalone VPC."
  type        = bool
  default     = false
}

variable "enable_internal_alb" {
  description = "If true, enables the creation of an Internal Application Load Balancer for the demo web app."
  type        = bool
  default     = true
}
