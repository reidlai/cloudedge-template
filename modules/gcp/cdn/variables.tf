variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "environment" {
  description = "The deployment environment"
  type        = string
}

variable "bucket_name" {
  description = "The name of the GCS bucket to serve via CDN"
  type        = string
}

variable "resource_tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
