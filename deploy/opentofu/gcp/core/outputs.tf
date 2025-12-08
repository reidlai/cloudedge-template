##########
# Output #
##########

output "ingress_vpc_id" {
  description = "The ID of the ingress VPC."
  value       = google_compute_network.ingress_vpc.id
}

output "ingress_subnet_id" {
  description = "The ID of the ingress subnet."
  value       = google_compute_subnetwork.ingress_subnet.id
}

output "load_balancer_ip" {
  description = "The public IP address of the regional load balancer."
  value       = google_compute_address.external_lb_ip.address
}

output "waf_policy_id" {
  description = "The ID of the WAF (Cloud Armor) security policy."
  value       = google_compute_security_policy.edge_waf_policy.id
}
