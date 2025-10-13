resource "google_compute_network" "egress_vpc" {
  project                 = var.project_id
  name                    = "${var.environment}-egress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "egress_subnet" {
  project                  = var.project_id
  name                     = "${var.environment}-egress-subnet"
  ip_cidr_range            = "10.0.2.0/24"
  network                  = google_compute_network.egress_vpc.name
  region                   = "us-central1" // Example region
}