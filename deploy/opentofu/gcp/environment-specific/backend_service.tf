resource "google_compute_backend_service" "demo_web_app" {
  count     = var.enable_demo_web_app ? 1 : 0
  project   = local.project_id
  name      = local.demo_web_app_backend_name
  protocol  = "HTTP"
  port_name = "http"

  backend {
    group = google_compute_region_network_endpoint_group.demo_web_app[0].id
  }

  # Attach WAF (Cloud Armor) security policy
  security_policy = var.enable_waf ? google_compute_security_policy.edge_waf_policy[0].id : null

  cdn_policy {
    # Enable Cloud CDN for this backend
    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0 # Log 100% of requests for full observability (NFR-001)
  }
}
