variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'nonprod', 'prod')."
  type        = string
}

variable "network_name" {
  description = "The name of the network to which to apply the firewall rule."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
}