resource "google_compute_network_peering" "peering1" {
  name         = "${var.project_id}-${var.environment}-peering-1-to-2"
  network      = var.network1_name
  peer_network = var.network2_name
}

resource "google_compute_network_peering" "peering2" {
  name         = "${var.project_id}-${var.environment}-peering-2-to-1"
  network      = var.network2_name
  peer_network = var.network1_name
}
