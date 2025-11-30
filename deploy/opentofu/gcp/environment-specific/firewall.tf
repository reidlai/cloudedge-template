resource "google_compute_firewall" "allow_ingress_vpc_https_ingress" {
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
  direction     = "INGRESS"
  priority      = 1000
}

# Allow health checks from Google Cloud to VPC Connector
resource "google_compute_firewall" "allow_web_vpc_health_checks_ingress" {
  count   = var.enable_web_vpc ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-allow-health-checks"
  network = google_compute_network.web_vpc[0].name

  allow {
    protocol = "tcp"
  }

  # Google Cloud health check IP ranges
  # The IP addresses 35.191.0.0/16 and 130.211.0.0/22 are hardcoded in the source_ranges because they are the official, documented, and reserved IP ranges used by the Google Cloud Load Balancing infrastructure for sending
  # health check probes to your backend services.
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  direction     = "INGRESS"
  priority      = 1000
}

# Deny all other ingress to web VPC (defense in depth)
resource "google_compute_firewall" "deny_web_vpc_all_ingress" {
  count   = var.enable_web_vpc ? 1 : 0
  project = var.project_id
  name    = "${var.project_suffix}-deny-all-ingress-web-vpc"
  network = google_compute_network.web_vpc[0].name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  # GCP firewall rules are evaluated in order of their priority value, from the lowest number (highest priority) to the highest number (lowest priority).
  priority = 65534
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

  # allow {
  #   protocol = "udp"
  # }

  # allow {
  #   protocol = "icmp"
  # }

  # Allow traffic from VPC Connector subnet
  source_ranges = [var.vpc_connector_cidr_range]
  direction     = "INGRESS"
  priority      = 1000
}
