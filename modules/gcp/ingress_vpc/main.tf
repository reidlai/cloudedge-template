resource "google_compute_network" "ingress_vpc" {
  project                 = var.project_id
  name                    = "${var.project_suffix}-ingress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ingress_subnet" {
  project                  = var.project_id
  name                     = "${var.project_suffix}-ingress-subnet"
  ip_cidr_range            = var.cidr_range
  network                  = google_compute_network.ingress_vpc.name
  region                   = var.region
  private_ip_google_access = true # CIS GCP Foundation Benchmark 3.9 - Enable Private Google Access
}
