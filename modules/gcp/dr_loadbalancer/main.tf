resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "${var.environment}-lb-ip"
}

resource "google_compute_backend_service" "default_backend" {
  project   = var.project_id
  name      = "${var.environment}-default-backend"
  port_name = "http"
  protocol  = "HTTP"
  timeout_sec = 10

  backend {
    group = var.default_backend_group_id
  }
}

resource "google_compute_url_map" "url_map" {
  project         = var.project_id
  name            = "${var.environment}-url-map"
  default_service = google_compute_backend_service.default_backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  project = var.project_id
  name    = "${var.environment}-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  project      = var.project_id
  name         = "${var.environment}-forwarding-rule"
  target       = google_compute_target_http_proxy.http_proxy.id
  ip_address   = google_compute_global_address.lb_ip.address
  port_range   = "80"
}