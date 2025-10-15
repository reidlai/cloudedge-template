variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "region" {
  description = "The GCP region."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}

variable "cidr_range" {
  description = "The CIDR range for the egress VPC subnetwork."
  type        = string
  default     = "10.0.2.0/24"
}