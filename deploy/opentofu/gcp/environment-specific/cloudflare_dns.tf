# Cloudflare DNS Management
# This file manages DNS records for the vibetics.com domain

data "cloudflare_zone" "vibetics" {
  name = var.root_domain
}

# Main subdomain A record pointing to load balancer
resource "cloudflare_record" "subdomain_a" {
  zone_id = data.cloudflare_zone.vibetics.id
  name    = var.subdomain_name
  # value   = google_compute_global_address.lb_ip[0].address
  content = var.enable_dr_loadbalancer ? google_compute_global_address.lb_ip[0].address : null
  type    = "A"
  ttl     = 120
  # Setting proxied = true is the recommended choice for A, AAAA, and CNAME records that serve web traffic (HTTP/HTTPS).
  #
  # | Behavior       | Description                                                                                                                                                                  |
  # | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  # | DNS Resolution | When a user looks up the DNS record, Cloudflare returns one of its Anycast IP addresses instead of your server's actual IP address.                                          |
  # | Security       | Cloudflare acts as a reverse proxy, shielding your origin server's true IP address from attackers and providing protection against DDoS attacks and other malicious traffic. |
  # | Performance    | Traffic is routed through Cloudflare's global network, benefiting from: CDN caching, Brotli compression, and other performance optimizations.                                |
  # | Features       | Enables Cloudflare services like WAF (Web Application Firewall), SSL/TLS encryption, Page Rules, and detailed analytics.                                                     |
  # | TTL            | The Time To Live (TTL) is fixed to Auto (300 seconds) and cannot be customized.                                                                                              |
  #
  proxied = false # Direct routing to load balancer (no Cloudflare proxy)
}
