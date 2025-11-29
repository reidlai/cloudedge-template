resource "google_compute_security_policy" "waf_policy" {
  count       = var.enable_waf ? 1 : 0
  project     = var.project_id
  name        = "${var.project_suffix}-waf-policy"
  description = "WAF policy for Cloud Run backend protection"

  # OWASP ModSecurity Core Rule Set (CRS) - SQL Injection protection
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - XSS protection
  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block cross-site scripting (XSS) attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - Local File Inclusion protection
  rule {
    action   = "deny(403)"
    priority = 1002
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Block local file inclusion attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - Remote File Inclusion protection
  rule {
    action   = "deny(403)"
    priority = 1003
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
    description = "Block remote file inclusion attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - Remote Code Execution protection
  rule {
    action   = "deny(403)"
    priority = 1004
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Block remote code execution attacks"
  }

  # Allow legitimate traffic (default rule)
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule - allow all other traffic"
  }

  labels = var.resource_tags
}
