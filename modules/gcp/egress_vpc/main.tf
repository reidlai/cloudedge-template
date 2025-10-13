resource "google_compute_network" "egress_vpc" {
  project                 = var.project_id
  name                    = "${var.project_id}-${var.environment}-egress-vpc"
  auto_create_subnetworks = true
  labels                  = var.resource_tags
}
