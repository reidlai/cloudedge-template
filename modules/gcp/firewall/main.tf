resource "google_compute_firewall" "allow_https" {
  project = var.project_id
  name    = "${var.environment}-allow-https"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
}

output "firewall_rule_name" {
  value = google_compute_firewall.allow_https.name
}
