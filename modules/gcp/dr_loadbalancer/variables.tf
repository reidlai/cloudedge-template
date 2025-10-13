variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'nonprod', 'prod')."
  type        = string
}

variable "routing_rules" {
  description = "A map of routing rules, where the key is a unique name for the rule and the value is an object with 'hosts' and 'backend_group_id'."
  type = map(object({
    hosts            = list(string)
    backend_group_id = string
  }))
  default = {}
}

variable "default_backend_group_id" {
  description = "The instance group ID for the default backend service."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
}