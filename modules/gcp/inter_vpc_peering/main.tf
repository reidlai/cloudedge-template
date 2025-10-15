resource "google_compute_network_peering" "peering1" {
  name         = "${var.environment}-peering-ingress-to-egress"
  network      = var.network1_self_link
  peer_network = var.network2_self_link
}

resource "google_compute_network_peering" "peering2" {
  name         = "${var.environment}-peering-egress-to-ingress"
  network      = var.network2_self_link
  peer_network = var.network1_self_link
}

output "peering1_name" {
  value = google_compute_network_peering.peering1.name
}

output "peering2_name" {
  value = google_compute_network_peering.peering2.name
}
