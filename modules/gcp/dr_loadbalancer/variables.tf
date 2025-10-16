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



variable "ssl_certificates" {

  description = "A list of SSL certificate self_links to attach to the HTTPS proxy."

  type        = list(string)

}


