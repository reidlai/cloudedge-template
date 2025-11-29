resource "google_compute_firewall" "allow_https" {
  count   = var.enable_firewall ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-allow-https"
  network = google_compute_network.ingress_vpc[0].name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # SECURITY FIX (S1): Restrict to Google Cloud Load Balancer IP ranges by default
  # This provides defense-in-depth beyond WAF and Cloud Run ingress policy
  # Override with ["0.0.0.0/0"] via var.allowed_https_source_ranges if needed for testing
  source_ranges = var.allowed_https_source_ranges
}

# Allow VPC Access Connector to communicate within web VPC
resource "google_compute_firewall" "allow_vpc_connector_egress" {
  count   = var.enable_web_vpc ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-allow-vpc-connector-egress"
  network = google_compute_network.web_vpc[0].name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  # Allow traffic from VPC Connector subnet
  source_ranges = [var.vpc_connector_cidr_range]
  direction     = "INGRESS"
  priority      = 1000
}

# Allow health checks from Google Cloud to VPC Connector
resource "google_compute_firewall" "allow_health_checks" {
  count   = var.enable_web_vpc ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-allow-health-checks"
  network = google_compute_network.web_vpc[0].name

  allow {
    protocol = "tcp"
  }

  # Google Cloud health check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  direction     = "INGRESS"
  priority      = 1000
}

# Deny all other ingress to web VPC (defense in depth)
resource "google_compute_firewall" "deny_all_ingress_web_vpc" {
  count   = var.enable_web_vpc ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-deny-all-ingress-web-vpc"
  network = google_compute_network.web_vpc[0].name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}
