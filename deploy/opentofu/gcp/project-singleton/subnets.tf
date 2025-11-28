resource "google_compute_subnetwork" "ingress_subnet" {
  count                    = var.enable_ingress_vpc ? 1 : 0
  project                  = var.project_id
  name                     = "${var.project_suffix}-ingress-subnet"
  ip_cidr_range            = var.ingress_vpc_cidr_range
  network                  = google_compute_network.ingress_vpc[0].name
  region                   = var.region
  private_ip_google_access = true # CIS GCP Foundation Benchmark 3.9 - Enable Private Google Access
}

resource "google_compute_subnetwork" "egress_subnet" {
  count                    = var.enable_egress_vpc ? 1 : 0
  project                  = var.project_id
  name                     = "${var.project_suffix}-egress-subnet"
  ip_cidr_range            = var.egress_vpc_cidr_range
  network                  = google_compute_network.egress_vpc[0].name
  region                   = var.region
  private_ip_google_access = true # CIS GCP Foundation Benchmark 3.9 - Enable Private Google Access
}
