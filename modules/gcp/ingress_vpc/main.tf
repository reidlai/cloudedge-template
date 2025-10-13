resource "google_compute_network" "ingress_vpc" {
  project                 = var.project_id
  name                    = "${var.environment}-ingress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ingress_subnet" {
  project                  = var.project_id
  name                     = "${var.environment}-ingress-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  network                  = google_compute_network.ingress_vpc.name
  region                   = "us-central1" // Example region
}