resource "google_compute_firewall" "allow_https" {
  project = var.project_id
  name    = "${var.environment}-allow-https"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # SECURITY FIX (S1): Restrict to Google Cloud Load Balancer IP ranges by default
  # This provides defense-in-depth beyond WAF and Cloud Run ingress policy
  # Override with ["0.0.0.0/0"] via var.allowed_https_source_ranges if needed for testing
  source_ranges = var.allowed_https_source_ranges
  target_tags   = ["https-server"]
}
