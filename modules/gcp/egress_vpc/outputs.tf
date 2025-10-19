# ============================================================================
# Egress VPC Module Outputs
# ============================================================================
# Exports VPC and subnet information for inter-VPC connectivity
# Referenced by: Firewall module, VPC peering, and external service connectivity

output "egress_vpc_name" {
  description = "The name of the egress VPC network"
  value       = google_compute_network.egress_vpc.name
}

output "egress_vpc_self_link" {
  description = "The self-link of the egress VPC network for resource references"
  value       = google_compute_network.egress_vpc.self_link
}

output "egress_vpc_id" {
  description = "The ID of the egress VPC network"
  value       = google_compute_network.egress_vpc.id
}

output "egress_subnet_name" {
  description = "The name of the egress VPC subnetwork"
  value       = google_compute_subnetwork.egress_subnet.name
}

output "egress_subnet_self_link" {
  description = "The self-link of the egress VPC subnetwork"
  value       = google_compute_subnetwork.egress_subnet.self_link
}

output "egress_subnet_cidr" {
  description = "The CIDR range of the egress VPC subnetwork"
  value       = google_compute_subnetwork.egress_subnet.ip_cidr_range
}
