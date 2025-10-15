variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}

variable "default_service_id" {
  description = "The ID of the default backend service for the load balancer."
  type        = string
}

variable "host_rules" {
  description = "A list of host rules for the URL map."
  type        = any
  default     = []
}

variable "path_matchers" {
  description = "A map of path matchers for the URL map."
  type        = any
  default     = {}
}

variable "managed_ssl_domain" {
  description = "The domain name to use for the Google-managed SSL certificate."
  type        = string
  default     = ""
}