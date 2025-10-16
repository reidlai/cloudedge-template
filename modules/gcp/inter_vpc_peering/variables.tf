variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "network1_self_link" {
  description = "The self_link of the first network."
  type        = string
}

variable "network2_self_link" {
  description = "The self_link of the second network."
  type        = string
}
