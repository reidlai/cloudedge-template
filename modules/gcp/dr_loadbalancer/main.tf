# Health check for the backend services
resource "google_compute_health_check" "default" {
  project = var.project_id
  name    = "${var.project_id}-${var.environment}-lb-health-check"
  http_health_check {
    port = 80
  }
}

# Default backend service for requests that don't match any host rule
resource "google_compute_backend_service" "default" {
  project             = var.project_id
  name                = "${var.project_id}-${var.environment}-default-backend-service"
  protocol            = "HTTP"
  port_name           = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks       = [google_compute_health_check.default.id]
  labels              = var.resource_tags
  enable_cdn          = true
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
  }
  log_config {
    enable = true
    sample_rate = 1.0
  }

  backend {
    group = var.default_backend_group_id
  }
}

# Backend services for each routing rule
resource "google_compute_backend_service" "routed_backends" {
  for_each            = var.routing_rules
  project             = var.project_id
  name                = "${var.project_id}-${var.environment}-backend-${each.key}"
  protocol            = "HTTP"
  port_name           = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks       = [google_compute_health_check.default.id]
  labels              = var.resource_tags
  enable_cdn          = true
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
  }
  log_config {
    enable = true
    sample_rate = 1.0
  }

  backend {
    group = each.value.backend_group_id
  }
}

# URL map to route incoming requests
resource "google_compute_url_map" "default" {
  project         = var.project_id
  name            = "${var.project_id}-${var.environment}-url-map"
  default_service = google_compute_backend_service.default.id
  labels          = var.resource_tags

  dynamic "host_rule" {
    for_each = var.routing_rules
    content {
      hosts        = host_rule.value.hosts
      path_matcher = "matcher-${host_rule.key}"
    }
  }

  dynamic "path_matcher" {
    for_each = var.routing_rules
    content {
      name            = "matcher-${path_matcher.key}"
      default_service = google_compute_backend_service.routed_backends[path_matcher.key].id
    }
  }
}

# A global IP address for the load balancer
resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "${var.project_id}-${var.environment}-lb-ip"
  labels  = var.resource_tags
}

# Placeholder SSL certificate
resource "google_compute_ssl_certificate" "default" {
  project     = var.project_id
  name        = "${var.project_id}-${var.environment}-lb-cert"
  private_key = file("${path.module}/test-fixtures/self-signed.key")
  certificate = file("${path.module}/test-fixtures/self-signed.crt")
  labels      = var.resource_tags
}

# Target HTTPS proxy
resource "google_compute_target_https_proxy" "default" {
  project          = var.project_id
  name             = "${var.project_id}-${var.environment}-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_ssl_certificate.default.id]
  labels           = var.resource_tags
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
  project      = var.project_id
  name         = "${var.project_id}-${var.environment}-forwarding-rule"
  target       = google_compute_target_https_proxy.default.id
  ip_address   = google_compute_global_address.lb_ip.id
  port_range   = "443"
  labels       = var.resource_tags
}
