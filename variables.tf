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
