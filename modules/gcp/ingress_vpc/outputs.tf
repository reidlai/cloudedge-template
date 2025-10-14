output "ingress_vpc_name" {
  description = "The name of the ingress VPC."
  value       = google_compute_network.ingress_vpc.name
}

output "ingress_vpc_self_link" {
  description = "The self_link of the ingress VPC."
  value       = google_compute_network.ingress_vpc.self_link
}