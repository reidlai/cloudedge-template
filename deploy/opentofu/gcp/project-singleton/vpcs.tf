resource "google_compute_network" "ingress_vpc" {
  count                   = var.enable_ingress_vpc ? 1 : 0
  project                 = var.project_id
  name                    = "${var.project_suffix}-ingress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_network" "egress_vpc" {
  count                   = var.enable_egress_vpc ? 1 : 0
  project                 = var.project_id
  name                    = "${var.project_suffix}-egress-vpc"
  auto_create_subnetworks = false
}
