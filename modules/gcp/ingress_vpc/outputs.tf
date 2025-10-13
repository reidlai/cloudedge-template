output "ingress_vpc_name" {
  description = "The name of the ingress VPC."
  value       = google_compute_network.ingress_vpc.name
}