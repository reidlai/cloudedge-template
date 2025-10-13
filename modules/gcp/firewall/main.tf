resource "google_compute_firewall" "allow_http" {
  project = var.project_id
  name    = "${var.environment}-allow-http"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}