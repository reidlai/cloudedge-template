resource "google_compute_global_address" "lb_ip" {
  count   = var.enable_dr_loadbalancer ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-lb-ip-v2"
}

# Obsolete regional load balancer components - commented out due to configuration issues, using global load balancer instead
# # Regional IP address for regional load balancer
# resource "google_compute_address" "regional_lb_ip" {
#   count   = var.enable_dr_loadbalancer ? 1 : 0
#   project = var.project_id
#   name    = "${var.project_suffix}-regional-lb-ip"
#   region  = var.region
# }

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
# resource "google_compute_security_policy" "edge_waf_policy" {
#   count       = var.enable_dr_loadbalancer && var.enable_waf ? 1 : 0
#   project     = var.project_id
#   name        = "${var.project_suffix}-edge-waf-policy"
#   description = "Edge WAF policy for load balancer - inspects encrypted traffic"

#   # Default rule - allow all other traffic
#   # rule {
#   #   action      = "allow"
#   #   description = "Default rule - allow all other traffic"
#   #   preview     = false
#   #   priority    = 2147483647

#   #   match {
#   #     versioned_expr = "SRC_IPS_V1"
#   #     config {
#   #       src_ip_ranges = ["*"]
#   #     }
#   #   }
#   # }

#   # Block SQL injection attacks
#   # rule {
#   #   action      = "deny(403)"
#   #   description = "Block SQL injection attacks"
#   #   preview     = false
#   #   priority    = 1000

#   #   match {
#   #     expr {
#   #       expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
#   #     }
#   #   }
#   # }

#   # Block cross-site scripting (XSS) attacks
#   # rule {
#   #   action      = "deny(403)"
#   #   description = "Block cross-site scripting (XSS) attacks"
#   #   preview     = false
#   #   priority    = 1001

#   #   match {
#   #     expr {
#   #       expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
#   #     }
#   #   }
#   # }

#   # Block cross-site request forgery (CSRF) attacks
#   # rule {
#   #   action      = "deny(403)"
#   #   description = "Block cross-site request forgery (CSRF) attacks"
#   #   preview     = false
#   #   priority    = 1002
#   #   match {
#   #     expr {
#   #       expression = "evaluatePreconfiguredWaf('csrf-v33-stable')"
#   #     }
#   #   }
#   # }

#   # Block local file inclusion attacks
#   # rule {
#   #   action      = "deny(403)"
#   #   description = "Block local file inclusion attacks"
#   #   preview     = false
#   #   priority    = 1003

#   #   match {
#   #     expr {
#   #       expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
#   #     }
#   #   }
#   # }

#   # Block remote code execution attacks
#   # rule {
#   #   action      = "deny(403)"
#   #   description = "Block remote code execution attacks"
#   #   preview     = false
#   #   priority    = 1004

#   #   match {
#   #     expr {
#   #       expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
#   #     }
#   #   }
#   # }

#   # Block remote file inclusion attacks
#   # rule {
#   #   action      = "deny(403)"
#   #   description = "Block remote file inclusion attacks"
#   #   preview     = false
#   #   priority    = 1005

#   #   match {
#   #     expr {
#   #       expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
#   #     }
#   #   }
#   # }

#   # Block method injection attacks
#   rule {
#     action      = "deny(403)"
#     description = "Block method injection attacks"
#     preview     = false
#     priority    = 1006

#     match {
#       expr {
#         expression = "evaluatePreconfiguredWaf('methodenforcement-v33-stable')"
#       }
#     }
#   }

#   # Block scanner detection attacks
#   rule {
#     action      = "deny(403)"
#     description = "Block scanner detection attacks"
#     preview     = false
#     priority    = 1007
#     match {
#       expr {
#         expression = "evaluatePreconfiguredWaf('scannerdetection-v33-stable')"
#       }
#     }
#   }

#   # Block protocol attacks
#   rule {
#     action      = "deny(403)"
#     description = "Block protocol attacks"
#     preview     = false
#     priority    = 1008
#     match {
#       expr {
#         expression = "evaluatePreconfiguredWaf('protocolattack-v33-stable')"
#       }
#     }
#   }

#   # Block session fixation attacks
#   rule {
#     action      = "deny(403)"
#     description = "Block session fixation attacks"
#     preview     = false
#     priority    = 1009
#     match {
#       expr {
#         expression = "evaluatePreconfiguredWaf('sessionfixation-v33-stable')"
#       }
#     }
#   }

#   # Block NodeJS attempts
#   rule {
#     action      = "deny(403)"
#     description = "Block NodeJS exploit attempts"
#     preview     = false
#     priority    = 1010
#     match {
#       expr {
#         expression = "evaluatePreconfiguredWaf('nodejs-v33-stable')"
#       }
#     }
#   }
# }



# GLOBAL LOAD BALANCER COMPONENTS (keeping for compatibility)
# ========================================================

resource "google_compute_ssl_certificate" "dr_loadbalancer_cert" {
  count       = var.enable_dr_loadbalancer ? 1 : 0
  name_prefix = "test-cert-"
  private_key = var.enable_self_signed_cert ? tls_private_key.self_signed_key[0].private_key_pem : null
  certificate = var.enable_self_signed_cert ? tls_self_signed_cert.self_signed_cert[0].cert_pem : null
}

resource "google_compute_target_https_proxy" "https_proxy" {
  count            = var.enable_dr_loadbalancer ? 1 : 0
  project          = var.project_id
  name             = "${var.project_suffix}-https-proxy-v3"
  url_map          = google_compute_url_map.url_map[0].id
  ssl_certificates = [google_compute_ssl_certificate.dr_loadbalancer_cert[0].self_link]

  lifecycle {
    create_before_destroy = true
  }
}

# Not accepted to use http protocol
# # resource "google_compute_target_http_proxy" "http_proxy" {
# #   count   = var.enable_dr_loadbalancer ? 1 : 0
# #   project = var.project_id
# #   name    = "${var.project_suffix}-http-proxy"
# #   url_map = google_compute_url_map.url_map[0].id
# # }

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
