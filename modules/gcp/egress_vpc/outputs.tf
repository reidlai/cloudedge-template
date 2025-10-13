output "egress_vpc_name" {
  description = "The name of the egress VPC network."
  value       = google_compute_network.egress_vpc.name
}
