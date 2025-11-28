resource "google_compute_firewall" "allow_https" {
  count   = var.enable_firewall ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-allow-https"
  network = google_compute_network.ingress_vpc[0].name

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
