# ============================================================================
# Ingress VPC Module Outputs
# ============================================================================
# Exports VPC and subnet information for load balancer and firewall integration
# Referenced by: DR Load Balancer module, Firewall module, VPC peering

output "ingress_vpc_name" {
  description = "The name of the ingress VPC network"
  value       = google_compute_network.ingress_vpc.name
}

output "ingress_vpc_self_link" {
  description = "The self-link of the ingress VPC network for resource references"
  value       = google_compute_network.ingress_vpc.self_link
}

output "ingress_vpc_id" {
  description = "The ID of the ingress VPC network"
  value       = google_compute_network.ingress_vpc.id
}

output "ingress_subnet_name" {
  description = "The name of the ingress VPC subnetwork"
  value       = google_compute_subnetwork.ingress_subnet.name
}

output "ingress_subnet_self_link" {
  description = "The self-link of the ingress VPC subnetwork"
  value       = google_compute_subnetwork.ingress_subnet.self_link
}

output "ingress_subnet_cidr" {
  description = "The CIDR range of the ingress VPC subnetwork"
  value       = google_compute_subnetwork.ingress_subnet.ip_cidr_range
}
