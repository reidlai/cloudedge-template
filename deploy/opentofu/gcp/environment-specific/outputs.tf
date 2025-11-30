
output "demo_web_app_backend_service_id" {
  description = "The ID of the global backend service for the demo Web App."
  value       = one(google_compute_backend_service.demo_web_app[*].id)
}

output "demo_web_app_backend_service_name" {
  description = "The name of the global backend service for the demo Web App."
  value       = one(google_compute_backend_service.demo_web_app[*].name)
}

output "demo_web_app_cloud_run_service_name" {
  description = "The name of the Cloud Run service."
  value       = one(google_cloud_run_v2_service.demo_web_app[*].name)
}

output "demo_web_app_cloud_run_service_uri" {
  description = "The URI of the Cloud Run service."
  value       = one(google_cloud_run_v2_service.demo_web_app[*].uri)
}

output "demo_web_app_serverless_neg_id" {
  description = "The ID of the Serverless Network Endpoint Group."
  value       = one(google_compute_region_network_endpoint_group.demo_web_app[*].id)
}

output "ingress_vpc_id" {
  description = "The ID of the ingress VPC."
  value       = google_compute_network.ingress_vpc[0].id
}

output "egress_vpc_id" {
  description = "The ID of the egress VPC."
  value       = google_compute_network.egress_vpc[0].id
}

output "ingress_subnet_id" {
  description = "The ID of the ingress subnet."
  value       = google_compute_subnetwork.ingress_subnet[0].id
}

output "egress_subnet_id" {
  description = "The ID of the egress subnet."
  value       = google_compute_subnetwork.egress_subnet[0].id
}

output "load_balancer_ip" {
  description = "The public IP address of the regional load balancer."
  value       = var.enable_dr_loadbalancer ? google_compute_global_address.lb_ip[0].address : null
}

output "web_vpc_id" {
  description = "The ID of the web VPC for Cloud Run."
  value       = one(google_compute_network.web_vpc[*].id)
}

output "web_subnet_id" {
  description = "The ID of the web subnet."
  value       = one(google_compute_subnetwork.web_subnet[*].id)
}

output "vpc_connector_id" {
  description = "The ID of the VPC Access Connector for Cloud Run."
  value       = one(data.google_vpc_access_connector.web_connector[*].id)
}

output "waf_policy_id" {
  description = "The ID of the WAF (Cloud Armor) security policy."
  value       = var.enable_waf ? google_compute_security_policy.edge_waf_policy[0].id : null
}
