variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "project_suffix" {
  description = "Project suffix (nonprod or prod)."
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
