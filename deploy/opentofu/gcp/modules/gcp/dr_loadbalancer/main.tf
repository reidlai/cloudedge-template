resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "${var.project_suffix}-lb-ip"
}

resource "google_compute_url_map" "url_map" {
  project         = var.project_id
  name            = "${var.project_suffix}-url-map"
  default_service = var.default_service_id

  dynamic "host_rule" {
    for_each = var.host_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.value.path_matcher
    }
  }

  dynamic "path_matcher" {
    for_each = var.path_matchers
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

resource "google_compute_target_https_proxy" "https_proxy" {
  project          = var.project_id
  name             = "${var.project_suffix}-https-proxy-v2"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = var.certificate_map != null ? null : var.ssl_certificates
  certificate_map  = var.certificate_map

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  project    = var.project_id
  name       = "${var.project_suffix}-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy.id
  ip_address = google_compute_global_address.lb_ip.address
  port_range = "443"
}
