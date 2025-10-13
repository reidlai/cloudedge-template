output "peering1_name" {
  description = "The name of the first peering connection."
  value       = google_compute_network_peering.peering1.name
}

output "peering2_name" {
  description = "The name of the second peering connection."
  value       = google_compute_network_peering.peering2.name
}