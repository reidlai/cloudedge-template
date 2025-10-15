resource "google_compute_network" "ingress_vpc" {
  project                 = var.project_id
  name                    = "${var.environment}-ingress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ingress_subnet" {
  project       = var.project_id
  name          = "${var.environment}-ingress-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.ingress_vpc.name
  region        = var.region
}

output "ingress_vpc_name" {
  value = google_compute_network.ingress_vpc.name
}

output "ingress_vpc_self_link" {
  value = google_compute_network.ingress_vpc.self_link
}
