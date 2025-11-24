variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "project_suffix" {
  description = "Project suffix (nonprod or prod)."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}
