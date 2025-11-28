resource "google_compute_global_address" "lb_ip" {
  count   = var.enable_dr_loadbalancer ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-lb-ip"
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

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  count      = var.enable_dr_loadbalancer ? 1 : 0
  project    = var.project_id
  name       = "${var.project_suffix}-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy[0].self_link
  ip_address = google_compute_global_address.lb_ip[0].address
  port_range = "443"
}

resource "google_compute_target_https_proxy" "https_proxy" {
  count            = var.enable_dr_loadbalancer ? 1 : 0
  project          = var.project_id
  name             = "${var.project_suffix}-https-proxy-v2"
  url_map          = google_compute_url_map.url_map[0].id
  ssl_certificates = var.certificate_map != null ? null : var.ssl_certificates
  certificate_map  = var.certificate_map

  lifecycle {
    create_before_destroy = true
  }
}


resource "google_compute_url_map" "url_map" {
  count           = var.enable_dr_loadbalancer ? 1 : 0
  project         = var.project_id
  name            = "${var.project_suffix}-url-map"
  default_service = "${var.project_suffix}-demo-web-app"

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
