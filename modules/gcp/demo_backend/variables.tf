variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "region" {
  description = "The GCP region for the resources."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
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

variable "enable_logging_bucket" {
  description = "If set to true, create a Cloud Logging bucket for the demo backend."
  type        = bool
  default     = true
}