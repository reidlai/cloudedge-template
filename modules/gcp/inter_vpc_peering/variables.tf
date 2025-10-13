variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'nonprod', 'prod')."
  type        = string
}

variable "network1_name" {
  description = "The name of the first network to peer."
  type        = string
}

variable "network2_name" {
  description = "The name of the second network to peer."
  type        = string
}
