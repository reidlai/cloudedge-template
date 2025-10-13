resource "google_compute_network_peering" "peering1" {
  name         = "${var.environment}-ingress-to-egress"
  network      = var.network1_name
  peer_network = var.network2_name
}

resource "google_compute_network_peering" "peering2" {
  name         = "${var.environment}-egress-to-ingress"
  network      = var.network2_name
  peer_network = var.network1_name
}