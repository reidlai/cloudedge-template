output "resource_tags" {
  description = "The resource tags applied to all resources."
  value       = var.resource_tags
}

# Load Balancer Outputs
output "load_balancer_ip" {
  description = "The public IP address of the Global HTTPS Load Balancer"
  value       = var.enable_dr_loadbalancer ? module.dr_loadbalancer[0].lb_frontend_ip : null
}

output "load_balancer_url" {
  description = "The HTTPS URL to access the load balancer"
  value       = var.enable_dr_loadbalancer ? "https://${module.dr_loadbalancer[0].lb_frontend_ip}" : null
}

# Cloud Run Outputs
output "cloud_run_service_url" {
  description = "The direct Cloud Run service URL (internal-only access, use load balancer instead)"
  value       = var.enable_demo_web_app ? module.demo_web_app[0].cloud_run_service_uri : null
}

# Access Instructions
output "access_instructions" {
  description = "Instructions for accessing the deployed infrastructure"
  value = var.enable_dr_loadbalancer ? (
    <<-EOT

    ========================================
    Infrastructure Access Information
    ========================================

    Load Balancer IP: ${module.dr_loadbalancer[0].lb_frontend_ip}
    Load Balancer URL: https://${module.dr_loadbalancer[0].lb_frontend_ip}

    IMPORTANT: Access via Load Balancer Only
    -----------------------------------------
    The Cloud Run service uses INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER, which means:
    - Direct public access to Cloud Run URLs is BLOCKED (returns 403/404)
    - Traffic is only allowed from Google Cloud Load Balancers and internal VPC
    - All external traffic MUST go through the load balancer

    Access Example (with Host header):
    -----------------------------------------
    curl -k -H "Host: ${local.load_balancer_host}" https://${module.dr_loadbalancer[0].lb_frontend_ip}

    Note: -k flag skips SSL verification (use only for self-signed certs in nonprod)

    For production with valid SSL certificates, omit the -k flag:
    curl -H "Host: ${local.load_balancer_host}" https://${module.dr_loadbalancer[0].lb_frontend_ip}

    EOT
  ) : "Load balancer not enabled"
}

# Firewall Outputs (for testing and validation)
output "firewall_rule_name" {
  description = "The name of the ingress VPC HTTPS firewall rule (for integration testing)"
  value       = var.enable_firewall ? module.firewall[0].firewall_rule_name : null
}

# VPC Network Outputs
output "ingress_vpc_name" {
  description = "The name of the ingress VPC network"
  value       = var.enable_ingress_vpc ? module.ingress_vpc[0].ingress_vpc_name : null
}

output "ingress_vpc_id" {
  description = "The ID of the ingress VPC network"
  value       = var.enable_ingress_vpc ? module.ingress_vpc[0].ingress_vpc_id : null
}

output "egress_vpc_name" {
  description = "The name of the egress VPC network"
  value       = var.enable_egress_vpc ? module.egress_vpc[0].egress_vpc_name : null
}

output "egress_vpc_id" {
  description = "The ID of the egress VPC network"
  value       = var.enable_egress_vpc ? module.egress_vpc[0].egress_vpc_id : null
}

# WAF Outputs
output "waf_policy_name" {
  description = "The name of the Cloud Armor WAF policy"
  value       = var.enable_waf ? module.waf[0].waf_policy_name : null
}

output "waf_policy_id" {
  description = "The ID of the Cloud Armor WAF policy"
  value       = var.enable_waf ? module.waf[0].waf_policy_id : null
}

# Backend Service Outputs
output "demo_web_app_service_name" {
  description = "The name of the demo web app backend service"
  value       = var.enable_demo_web_app ? module.demo_web_app[0].backend_service_name : null
}

output "cloud_run_service_name" {
  description = "The name of the Cloud Run service"
  value       = var.enable_demo_web_app ? module.demo_web_app[0].cloud_run_service_name : null
}

# CDN Outputs
output "cdn_backend_name" {
  description = "The name of the CDN backend bucket"
  value       = var.enable_cdn ? module.cdn[0].cdn_backend_name : null
}

# Billing Outputs
output "billing_budget_id" {
  description = "The ID of the billing budget"
  value       = var.enable_billing ? module.billing[0].budget_id : null
}
