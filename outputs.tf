output "ingress_vpc_name" {
  description = "The name of the ingress VPC network."
  value       = module.ingress_vpc.ingress_vpc_name
}

output "egress_vpc_name" {
  description = "The name of the egress VPC network."
  value       = module.egress_vpc.egress_vpc_name
}

output "firewall_rule_name" {

  description = "The name of the firewall rule."

  value       = module.firewall.firewall_rule_name

}



output "waf_policy_name" {

  description = "The name of the WAF security policy."

  value       = module.waf.waf_policy_name

}



output "lb_frontend_ip" {

  description = "The public IP address of the Global Load Balancer."

  value       = module.dr_loadbalancer.lb_frontend_ip

}



output "peering1_name" {

  description = "The name of the first peering connection."

  value       = module.inter_vpc_peering.peering1_name

}



output "peering2_name" {

  description = "The name of the second peering connection."

  value       = module.inter_vpc_peering.peering2_name

}
