
###################
# Local Variables #
###################
locals {
  project_suffix              = var.project_suffix
  cloudedge_github_repository = var.cloudedge_github_repository
  region                      = var.region
  cloudflare_api_token        = var.cloudflare_api_token

  project_id      = var.project_id != "" ? var.project_id : "${local.cloudedge_github_repository}-${local.project_suffix}"
  host_project_id = "${local.project_id}-shared"
  standard_tags = merge(
    var.resource_tags,
    {
      "project"    = local.project_id
      "managed-by" = "opentofu"
    }
  )

  enable_logging = data.terraform_remote_state.singleton.outputs.enable_logging

  root_domain                  = var.root_domain
  demo_web_app_subdomain_name  = var.demo_web_app_subdomain_name
  ingress_vpc_cidr_range       = var.ingress_vpc_cidr_range
  demo_web_app_backend_name    = "demo-web-app-backend"
  enable_demo_web_app          = var.enable_demo_web_app
  allowed_https_source_ranges  = var.allowed_https_source_ranges
  proxy_only_subnet_cidr_range = var.proxy_only_subnet_cidr_range
  enable_self_signed_cert      = var.enable_self_signed_cert
  enable_waf                   = var.enable_waf
  enable_cloudflare_proxy      = var.enable_cloudflare_proxy
  cloudflare_origin_ca_key     = var.cloudflare_origin_ca_key

  # Cloudflare IP ranges for firewall when proxy is enabled
  # Source: https://www.cloudflare.com/ips/
  cloudflare_ipv4_ranges = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22"
  ]

}

######################
# Opentofu Providers #
######################

provider "google" {
  project = local.project_id
  region  = local.region
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
}

# Cloudflare Provider Configuration
provider "cloudflare" {
  api_token = local.cloudflare_api_token
}

# Cloudflare Provider for Origin CA operations (uses Origin CA Key)
provider "cloudflare" {
  alias                = "origin_ca"
  api_token            = local.cloudflare_api_token
  api_user_service_key = local.cloudflare_origin_ca_key != "" ? local.cloudflare_origin_ca_key : null
}

################
# Data Sources #
################

data "terraform_remote_state" "singleton" {
  backend = "gcs"
  config = {
    bucket = "${local.project_id}-tfstate"
    prefix = "${local.project_id}-singleton"
  }
}

data "terraform_remote_state" "demo_vpc" {
  count   = local.enable_demo_web_app ? 1 : 0
  backend = "gcs"
  config = {
    bucket = "${local.project_id}-tfstate"
    prefix = "${local.project_id}-demo-vpc"
  }
}

# Get Project Number for Service Agent
data "google_project" "current" {
  project_id = local.project_id
}

data "cloudflare_zone" "vibetics" {
  name = local.root_domain
}

###############
# Google APIs #
###############

resource "google_project_service" "run" {
  project            = local.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

###############
# Regional IP #
###############

resource "google_compute_address" "external_lb_ip" {
  project      = local.project_id
  region       = local.region
  name         = "${local.project_suffix}-external-lb-ip"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

#############################################################
# Cloudflare DNS Management                                 #
# This file manages DNS records for the vibetics.com domain #
#############################################################

# Main subdomain A record pointing to load balancer
resource "cloudflare_record" "demo_web_app_subdomain_a" {
  zone_id = data.cloudflare_zone.vibetics.id
  name    = local.demo_web_app_subdomain_name
  content = google_compute_address.external_lb_ip.address
  type    = "A"
  ttl     = local.enable_cloudflare_proxy ? 1 : 120 # TTL=1 means 'automatic' when proxied
  # Setting proxied = true is the recommended choice for A, AAAA, and CNAME records that serve web traffic (HTTP/HTTPS).
  #
  # | Behavior       | Description                                                                                                                                                                  |
  # | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
  # | DNS Resolution | When a user looks up the DNS record, Cloudflare returns one of its Anycast IP addresses instead of your server's actual IP address.                                          |
  # | Security       | Cloudflare acts as a reverse proxy, shielding your origin server's true IP address from attackers and providing protection against DDoS attacks and other malicious traffic. |
  # | Performance    | Traffic is routed through Cloudflare's global network, benefiting from: CDN caching, Brotli compression, and other performance optimizations.                                |
  # | Features       | Enables Cloudflare services like WAF (Web Application Firewall), SSL/TLS encryption, Page Rules, and detailed analytics.                                                     |
  # | TTL            | The Time To Live (TTL) is fixed to Auto (300 seconds) and cannot be customized when proxied=true.                                                                            |
  #
  proxied = local.enable_cloudflare_proxy # Enable Cloudflare proxy (orange cloud) based on variable
}

#################################
# Cloudflare Origin Certificate #
#################################

# Generate private key for Cloudflare origin certificate
resource "tls_private_key" "cloudflare_origin_key" {
  count     = local.enable_cloudflare_proxy ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate CSR for Cloudflare origin certificate
resource "tls_cert_request" "cloudflare_origin_csr" {
  count           = local.enable_cloudflare_proxy ? 1 : 0
  private_key_pem = tls_private_key.cloudflare_origin_key[0].private_key_pem

  subject {
    common_name  = "${local.demo_web_app_subdomain_name}.${local.root_domain}"
    organization = "Vibetics"
  }

  dns_names = [
    "${local.demo_web_app_subdomain_name}.${local.root_domain}"
  ]
}

# Cloudflare origin certificate for Cloudflare-to-GCP connection
# This is used when Cloudflare proxy is enabled and we need a certificate
# for the encrypted connection between Cloudflare and the GCP load balancer
resource "cloudflare_origin_ca_certificate" "origin_cert" {
  provider           = cloudflare.origin_ca
  count              = local.enable_cloudflare_proxy ? 1 : 0
  csr                = tls_cert_request.cloudflare_origin_csr[0].cert_request_pem
  hostnames          = ["${local.demo_web_app_subdomain_name}.${local.root_domain}"]
  request_type       = "origin-rsa"
  requested_validity = 5475 # 15 years (max allowed)
}

# Upload Cloudflare origin certificate to GCP as a regional SSL certificate
resource "google_compute_region_ssl_certificate" "cloudflare_origin_cert" {
  count       = local.enable_cloudflare_proxy ? 1 : 0
  provider    = google-beta
  project     = local.project_id
  region      = local.region
  name        = "cloudflare-origin-cert-${local.demo_web_app_subdomain_name}"
  private_key = tls_private_key.cloudflare_origin_key[0].private_key_pem
  certificate = cloudflare_origin_ca_certificate.origin_cert[0].certificate

  lifecycle {
    create_before_destroy = true
  }
}

###########################
# Cloud Edge WAF Policies #
###########################

resource "google_compute_region_security_policy" "edge_waf_policy" {
  count       = local.enable_waf ? 1 : 0
  project     = local.project_id
  region      = local.region
  name        = "edge-waf-policy"
  description = "Edge WAF policy for regional load balancer - inspects encrypted traffic"

  # OWASP ModSecurity Core Rule Set (CRS) - SQL Injection protection
  rules {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - XSS protection
  rules {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block cross-site scripting (XSS) attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - Local File Inclusion protection
  rules {
    action   = "deny(403)"
    priority = 1002
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Block local file inclusion attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - Remote File Inclusion protection
  rules {
    action   = "deny(403)"
    priority = 1003
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
    description = "Block remote file inclusion attacks"
  }

  # OWASP ModSecurity Core Rule Set (CRS) - Remote Code Execution protection
  rules {
    action   = "deny(403)"
    priority = 1004
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Block remote code execution attacks"
  }

  # rules {
  #   action      = "deny(403)"
  #   priority    = 1005
  #   match {
  #     expr {
  #       expression = "evaluatePreconfiguredWaf('csrf-v33-stable')"
  #     }
  #   }
  # }

  rules {
    action      = "deny(403)"
    description = "Block method injection attacks"
    preview     = false
    priority    = 1006

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('methodenforcement-v33-stable')"
      }
    }
  }

  # Block scanner detection attacks
  rules {
    action      = "deny(403)"
    description = "Block scanner detection attacks"
    preview     = false
    priority    = 1007
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('scannerdetection-v33-stable')"
      }
    }
  }

  # Block protocol attacks
  rules {
    action      = "deny(403)"
    description = "Block protocol attacks"
    preview     = false
    priority    = 1008
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('protocolattack-v33-stable')"
      }
    }
  }

  # Block session fixation attacks
  rules {
    action      = "deny(403)"
    description = "Block session fixation attacks"
    preview     = false
    priority    = 1009
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sessionfixation-v33-stable')"
      }
    }
  }

  # Block NodeJS attempts
  rules {
    action      = "deny(403)"
    description = "Block NodeJS exploit attempts"
    preview     = false
    priority    = 1010
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('nodejs-v33-stable')"
      }
    }
  }

  # Allow legitimate traffic (default rule)
  rules {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule - allow all other traffic"
  }
}

################
# Ingress VPC #
################

resource "google_compute_network" "ingress_vpc" {
  project                 = local.project_id
  name                    = "ingress-vpc"
  auto_create_subnetworks = false
}

##################
# Ingress Subnet #
##################

# Ingress VPC Subnet
resource "google_compute_subnetwork" "ingress_subnet" {
  project                  = local.project_id
  name                     = "ingress-subnet"
  ip_cidr_range            = local.ingress_vpc_cidr_range
  network                  = google_compute_network.ingress_vpc.name
  region                   = local.region
  private_ip_google_access = true # CIS GCP Foundation Benchmark 3.9 - Enable Private Google Access
}

###############################################################
# Proxy-Only Subnet (Required for Regional External ALB)      #
###############################################################

resource "google_compute_subnetwork" "proxy_only_subnet" {
  project       = local.project_id
  name          = "external-https-lb-proxy-only-subnet"
  ip_cidr_range = local.proxy_only_subnet_cidr_range
  region        = local.region
  network       = google_compute_network.ingress_vpc.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

##########################
# Ingress Firewall Rules #
##########################

resource "google_compute_firewall" "allow_ingress_vpc_https_ingress" {
  project = local.project_id
  name    = "${local.project_suffix}-allow-https"
  network = google_compute_network.ingress_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # SECURITY: When Cloudflare proxy is enabled, restrict to Cloudflare IP ranges only
  # When Cloudflare proxy is disabled, use configured allowed_https_source_ranges
  # This provides defense-in-depth beyond WAF and Cloud Run ingress policy
  source_ranges = local.enable_cloudflare_proxy ? local.cloudflare_ipv4_ranges : local.allowed_https_source_ranges
  direction     = "INGRESS"
  priority      = 1000
}

###########
# PSC NEG #
###########

resource "google_compute_region_network_endpoint_group" "demo_web_app_psc_neg" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  name                  = "demo-web-app-psc-neg"
  region                = local.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = data.terraform_remote_state.demo_vpc[0].outputs.demo_web_app_psc_service_attachment_self_link

  network    = google_compute_network.ingress_vpc.id
  subnetwork = google_compute_subnetwork.ingress_subnet.id
}

######################################################
# Regional Backend Service for Regional External ALB #
######################################################

resource "google_compute_region_backend_service" "demo_web_app_external_backend" {
  count                 = local.enable_demo_web_app ? 1 : 0
  project               = local.project_id
  region                = local.region
  name                  = "demo-web-app-external-backend"
  protocol              = "HTTPS"
  port_name             = "https"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  security_policy = local.enable_waf ? google_compute_region_security_policy.edge_waf_policy[0].id : null

  backend {
    group           = google_compute_region_network_endpoint_group.demo_web_app_psc_neg[0].id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

################################
# External HTTPS Load Balancer #
################################

# URL Map
resource "google_compute_region_url_map" "external_https_lb" {
  project         = local.project_id
  name            = "external-https-lb"
  default_service = google_compute_region_backend_service.demo_web_app_external_backend[0].id
}

# HTTPS Proxy
resource "google_compute_region_target_https_proxy" "external_https_lb" {
  project = local.project_id
  region  = local.region
  name    = "external-https-lb-proxy"
  url_map = google_compute_region_url_map.external_https_lb.id
  # Use Cloudflare origin cert when proxy is enabled, otherwise use self-signed or managed cert from singleton
  ssl_certificates = [
    local.enable_cloudflare_proxy ? google_compute_region_ssl_certificate.cloudflare_origin_cert[0].id : data.terraform_remote_state.singleton.outputs.external_https_lb_cert_id
  ]
}

# HTTPS Forwarding Rule (port 443)
resource "google_compute_forwarding_rule" "external_https_lb" {
  project               = local.project_id
  region                = local.region
  name                  = "external-https-lb"
  target                = google_compute_region_target_https_proxy.external_https_lb.id
  ip_address            = google_compute_address.external_lb_ip.address
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "STANDARD"
  network               = google_compute_network.ingress_vpc.id

  depends_on = [
    google_compute_subnetwork.proxy_only_subnet
  ]
}
