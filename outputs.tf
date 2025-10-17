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
  value       = var.enable_demo_backend ? "https://nonprod-demo-api-${var.project_id}.${var.region}.run.app" : null
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
    The Cloud Run service uses INGRESS_TRAFFIC_INTERNAL_AND_LOAD_BALANCER, which means:
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
