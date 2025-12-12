#####################
# Project Variables #
#####################

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
}

variable "cloudedge_github_repository" {
  description = "The GitHub repository name for the Cloud Edge project excluding owner name"
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

variable "cloudedge_project_id" {
  description = "The GCP Project ID for the Cloud Edge project. If empty, it will be derived from cloudedge_github_repository and project_suffix."
  type        = string
  default     = ""
}

##########################
# Demo Web App Variables #
##########################

variable "enable_demo_web_app" {
  description = "If set to true, demo-web-app docker will be deployed in Cloud Run"
  type        = bool
}

variable "demo_web_app_project_id" {
  description = "The GCP Project ID where the demo web app Cloud Run service will be deployed. If empty, defaults to the core project_id."
  type        = string
  default     = ""
}

variable "demo_web_app_service_name" {
  description = "The name of the Cloud Run service for the demo web app."
  type        = string
  default     = "demo-web-app"
}

variable "demo_web_app_image" {
  description = "Docker image for Demo Web App Cloud Run deployment"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

# variable "demo_web_app_subdomain_name" {
#   description = "The subdomain name for the application"
#   type        = string
#   default     = "demo-web-app"
# }

variable "enable_demo_web_app_self_signed_cert" {
  description = "If true, a self-signed TLS certificate will be created instead of using ACME."
  type        = bool
  default     = false
}

variable "enable_demo_web_app_internal_alb" {
  description = "If true, enables the creation of an Internal Application Load Balancer for the demo web app."
  type        = bool
  default     = true
}

variable "enable_demo_web_app_psc_neg" {
  description = "If true, creates a Private Service Connect Network Endpoint Group (PSC NEG) for the demo web app Cloud Run service."
  type        = bool
  default     = false
}

variable "demo_web_app_web_vpc_name" {
  description = "The name of the VPC hosting the demo web app resources."
  type        = string
  default     = "demo-web-app-web-vpc"
}

variable "demo_web_app_web_subnet_cidr_range" {
  description = "The CIDR range for the VPC Access Connector subnet."
  type        = string
  default     = "10.0.3.0/24"
}

variable "demo_web_app_proxy_only_subnet_cidr_range" {
  description = "The CIDR range for the proxy-only subnet required by the Internal ALB."
  type        = string
  default     = "10.0.99.0/24"
}

variable "demo_web_app_psc_nat_subnet_cidr_range" {
  description = "The CIDR range for the PSC NAT subnet."
  type        = string
  default     = "10.0.100.0/24"
}

variable "demo_web_app_port" {
  description = "Port on which the Demo Web App listens"
  type        = number
  default     = 3000
}

variable "demo_web_app_min_concurrent_deployments" {
  description = "The minimum number of concurrent requests the demo web app Cloud Run service can handle."
  type        = number
  default     = 0
}

variable "demo_web_app_max_concurrent_deployments" {
  description = "The maximum number of concurrent requests the demo web app Cloud Run service can handle."
  type        = number
  default     = 1
}
