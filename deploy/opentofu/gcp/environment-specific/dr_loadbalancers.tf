resource "google_compute_global_address" "lb_ip" {
  count   = var.enable_dr_loadbalancer ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-lb-ip-v2"
}

# Regional IP address for regional load balancer
resource "google_compute_address" "regional_lb_ip" {
  count   = var.enable_dr_loadbalancer ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-regional-lb-ip"
  region  = var.region
}

resource "google_compute_health_check" "https_health_check" {
  count = var.enable_dr_loadbalancer ? 1 : 0
  name  = "https-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  https_health_check {
    port = "443"
  }
}

# Regional components removed - using global load balancer with regional IP for regional load balancing

# Regional HTTPS proxy - commented out due to configuration issues
# resource "google_compute_target_https_proxy" "regional_https_proxy" {
#   count           = var.enable_dr_loadbalancer ? 1 : 0
#   project         = var.project_id
#   name            = "${var.project_suffix}-regional-https-proxy"
#   url_map         = google_compute_region_url_map.regional_url_map[0].self_link
#   certificate_map = format("//certificatemanager.googleapis.com/%s", data.terraform_remote_state.singleton.outputs.certificate_map_id)
# }

# Regional URL map - commented out due to configuration issues
# resource "google_compute_region_url_map" "regional_url_map" {
#   count           = var.enable_dr_loadbalancer ? 1 : 0
#   project         = var.project_id
#   name            = "${var.project_suffix}-regional-url-map"
#   region          = var.region
#   default_service = google_compute_backend_service.demo_web_app[0].self_link
# }

# Using global backend service for Cloud Run (serverless backends require global backend services)
# Edge Security Policy for WAF at the load balancer level
resource "google_compute_security_policy" "edge_waf_policy" {
  count       = var.enable_dr_loadbalancer && var.enable_waf ? 1 : 0
  project     = var.project_id
  name        = "${var.project_suffix}-edge-waf-policy"
  description = "Edge WAF policy for load balancer - inspects encrypted traffic"

  # Default rule - allow all other traffic
  rule {
    action      = "allow"
    description = "Default rule - allow all other traffic"
    preview     = false
    priority    = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  # Block SQL injection attacks
  rule {
    action      = "deny(403)"
    description = "Block SQL injection attacks"
    preview     = false
    priority    = 1000

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
  }

  # Block cross-site scripting (XSS) attacks
  rule {
    action      = "deny(403)"
    description = "Block cross-site scripting (XSS) attacks"
    preview     = false
    priority    = 1001

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
  }

  # Block local file inclusion attacks
  rule {
    action      = "deny(403)"
    description = "Block local file inclusion attacks"
    preview     = false
    priority    = 1002

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
  }

  # Block remote code execution attacks
  rule {
    action      = "deny(403)"
    description = "Block remote code execution attacks"
    preview     = false
    priority    = 1004

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
  }

  # Block remote file inclusion attacks
  rule {
    action      = "deny(403)"
    description = "Block remote file inclusion attacks"
    preview     = false
    priority    = 1003

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
  }
}

# Backend Security Policy for additional WAF layer (defense in depth)
resource "google_compute_security_policy" "backend_waf_policy" {
  count       = var.enable_dr_loadbalancer && var.enable_waf ? 1 : 0
  project     = var.project_id
  name        = "${var.project_suffix}-backend-waf-policy"
  description = "Backend WAF policy for regional load balancer - additional security layer"

  # Default rule - allow all other traffic
  rule {
    action      = "allow"
    description = "Default rule - allow all other traffic"
    preview     = false
    priority    = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }

  # Block SQL injection attacks
  rule {
    action      = "deny(403)"
    description = "Block SQL injection attacks"
    preview     = false
    priority    = 1000

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
  }

  # Block cross-site scripting (XSS) attacks
  rule {
    action      = "deny(403)"
    description = "Block cross-site scripting (XSS) attacks"
    preview     = false
    priority    = 1001

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
  }
}

# GLOBAL LOAD BALANCER COMPONENTS (keeping for compatibility)
# ========================================================

# Self-signed certificate for testing
resource "tls_private_key" "test_cert_key" {
  count     = var.enable_dr_loadbalancer ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "test_cert" {
  count             = var.enable_dr_loadbalancer ? 1 : 0
  private_key_pem   = tls_private_key.test_cert_key[0].private_key_pem
  is_ca_certificate = true

  subject {
    common_name  = "vibetics-agentportal-devtest.vibetics.com"
    organization = "Test"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["vibetics-agentportal-devtest.vibetics.com"]
}

resource "google_compute_ssl_certificate" "test_cert" {
  count       = var.enable_dr_loadbalancer ? 1 : 0
  name_prefix = "test-cert-"
  private_key = tls_private_key.test_cert_key[0].private_key_pem
  certificate = tls_self_signed_cert.test_cert[0].cert_pem
}

resource "google_compute_target_https_proxy" "https_proxy" {
  count            = var.enable_dr_loadbalancer ? 1 : 0
  project          = var.project_id
  name             = "${var.project_suffix}-https-proxy-v3"
  url_map          = google_compute_url_map.url_map[0].id
  ssl_certificates = [google_compute_ssl_certificate.test_cert[0].self_link]
  # certificate_map = format("//certificatemanager.googleapis.com/%s", data.terraform_remote_state.singleton.outputs.certificate_map_id)

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
  count   = var.enable_dr_loadbalancer ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-http-proxy"
  url_map = google_compute_url_map.url_map[0].id
}

# Global HTTPS forwarding rule using regional IP for regional load balancing
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  count      = var.enable_dr_loadbalancer ? 1 : 0
  project    = var.project_id
  name       = "${var.project_suffix}-forwarding-rule-v2"
  target     = google_compute_target_https_proxy.https_proxy[0].self_link
  ip_address = google_compute_global_address.lb_ip[0].address # Use global IP
  port_range = "443"
}

# HTTP forwarding rule disabled for security - all traffic must use HTTPS

resource "google_compute_url_map" "url_map" {
  count           = var.enable_dr_loadbalancer ? 1 : 0
  project         = var.project_id
  name            = "${var.project_suffix}-url-map"
  default_service = google_compute_backend_service.demo_web_app[0].self_link

  dynamic "host_rule" {
    for_each = var.url_map_host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }

  dynamic "path_matcher" {
    for_each = var.url_map_path_matchers
    content {
      name            = path_matcher.key
      default_service = path_matcher.value.default_service
      dynamic "path_rule" {
        for_each = path_matcher.value.path_rules
        content {
          paths   = path_rule.value.paths
          service = path_rule.value.service
        }
      }
    }
  }
}
