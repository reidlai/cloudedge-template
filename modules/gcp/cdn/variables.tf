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

variable "region" {
  description = "The GCP region for the backend service."
  type        = string
}