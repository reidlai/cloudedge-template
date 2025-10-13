resource "google_compute_security_policy" "waf_policy" {
  project     = var.project_id
  name        = "${var.project_id}-${var.environment}-waf-policy"
  description = "Basic WAF policy"
  labels      = var.resource_tags

  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config = {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, deny all"
  }
}
