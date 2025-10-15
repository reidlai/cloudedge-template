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
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default = {
    "managed-by" = "opentofu"
  }
}

variable "managed_ssl_domain" {
  description = "The domain name to use for the Google-managed SSL certificate."
  type        = string
  default     = ""
}

variable "vpc_connector_cidr_range" {
  description = "The CIDR range for the VPC Access Connector."
  type        = string
  default     = "10.12.0.0/28"
}

variable "vpc_connector_min_throughput" {
  description = "The minimum throughput for the VPC Access Connector."
  type        = number
  default     = 200
}

variable "vpc_connector_max_throughput" {
  description = "The maximum throughput for the VPC Access Connector."
  type        = number
  default     = 300
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

variable "enable_inter_vpc_peering" {
  description = "If set to true, the inter_vpc_peering module will be enabled."
  type        = bool
  default     = false
}

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


