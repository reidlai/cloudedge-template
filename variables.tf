variable "cloud_provider" {
  description = "The cloud provider to use for deployment (e.g., 'gcp', 'aws', 'azure')."
  type        = string
  default     = "gcp"
}

variable "environment" {
  description = "The deployment environment (e.g., 'nonprod', 'prod')."
  type        = string
  default     = "nonprod"
}

variable "project_id" {
  description = "The GCP Project ID where resources will be deployed."
  type        = string
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
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default = {
    "managed-by" = "opentofu"
  }
}

variable "managed_ssl_domain" {
  description = "The domain name for the Google-managed SSL certificate."
  type        = string
  default     = "demo.example.com"
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

variable "enable_inter_vpc_peering" {
  description = "If set to true, the inter_vpc_peering module will be enabled."
  type        = bool
  default     = false
}



