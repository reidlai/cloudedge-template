resource "google_compute_network" "egress_vpc" {
  project                 = var.project_id
  name                    = "${var.environment}-egress-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "egress_subnet" {
  project                  = var.project_id
  name                     = "${var.environment}-egress-subnet"
  ip_cidr_range            = var.cidr_range
  network                  = google_compute_network.egress_vpc.name
  region                   = var.region
  private_ip_google_access = true # CIS GCP Foundation Benchmark 3.9 - Enable Private Google Access
}
