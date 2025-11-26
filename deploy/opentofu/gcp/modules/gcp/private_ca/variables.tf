variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "project_suffix" {
  description = "The project suffix."
  type        = string
}

variable "region" {
  description = "The GCP region."
  type        = string
}

variable "domain" {
  description = "The domain name for the certificate."
  type        = string
}

variable "authorized_members" {
  description = "List of IAM members (users, service accounts, groups) authorized to request certificates from this CA Pool (FR-017)."
  type        = list(string)
  default     = []
}

variable "pool_name" {
  description = "The name of the CA pool."
  type        = string
  default     = "ca-pool"
}

variable "location" {
  description = "The location of the CA pool. If empty, uses var.region."
  type        = string
  default     = ""
}
