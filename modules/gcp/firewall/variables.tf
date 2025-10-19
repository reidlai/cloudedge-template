variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "environment" {
  description = "The deployment environment."
  type        = string
}

variable "network_name" {
  description = "The name of the network to apply the firewall rule to."
  type        = string
}

variable "resource_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}

variable "allowed_https_source_ranges" {
  description = <<-EOT
    List of CIDR ranges allowed to access the HTTPS endpoint on the ingress VPC.
    Defaults to Google Cloud Load Balancer IP ranges for defense-in-depth security.

    Google Cloud Load Balancer IP ranges (as of 2024):
    - 35.191.0.0/16 (health checks and proxy IPs)
    - 130.211.0.0/22 (legacy health checks)

    WARNING: Using ["0.0.0.0/0"] allows traffic from ANY IP address and relies solely
    on WAF (Cloud Armor) for edge protection. This is acceptable for demo/testing but
    NOT recommended for production without explicit risk acceptance.
  EOT
  type        = list(string)
  default     = ["35.191.0.0/16", "130.211.0.0/22"]
}
