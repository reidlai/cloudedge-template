output "egress_vpc_name" {
  description = "The name of the egress VPC."
  value       = google_compute_network.egress_vpc.name
}

output "egress_vpc_self_link" {
  description = "The self_link of the egress VPC."
  value       = google_compute_network.egress_vpc.self_link
}