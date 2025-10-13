variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "network1_name" {
  description = "The name of the first network for peering."
  type        = string
}

variable "network2_name" {
  description = "The name of the second network for peering."
  type        = string
}