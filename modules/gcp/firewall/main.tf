resource "google_compute_firewall" "allow_https" {
  project = var.project_id
  name    = "${var.project_id}-${var.environment}-allow-https-ingress"
  network = var.network_name
  labels  = var.resource_tags

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
}
