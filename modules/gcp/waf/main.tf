resource "google_compute_security_policy" "waf_policy" {
  project     = var.project_id
  name        = "${var.project_suffix}-waf-policy"
  description = "WAF policy"

  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, deny all"
  }

  labels = var.resource_tags
}
