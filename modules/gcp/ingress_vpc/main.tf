resource "google_compute_network" "ingress_vpc" {
  project                 = var.project_id
  name                    = "${var.project_id}-${var.environment}-ingress-vpc"
  auto_create_subnetworks = true
  labels                  = var.resource_tags
}
