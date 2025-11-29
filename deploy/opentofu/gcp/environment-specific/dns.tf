# Cloudflare DNS Management
# This file manages DNS records for the vibetics.com domain

data "cloudflare_zone" "vibetics" {
  name = var.root_domain
}

# Main subdomain A record pointing to load balancer
resource "cloudflare_record" "subdomain_a" {
  zone_id = data.cloudflare_zone.vibetics.id
  name    = var.subdomain_name
  value   = google_compute_global_address.lb_ip[0].address
  type    = "A"
  ttl     = 120
  proxied = false # Direct routing to load balancer (no Cloudflare proxy)
}
