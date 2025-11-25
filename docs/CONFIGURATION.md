# Configuration Reference

This document covers operational configuration, feature flags, and environment variables.

## Module Feature Flags

All infrastructure modules are controlled by feature flags (variables prefixed with `enable_`). This allows selective deployment of components based on your requirements.

| Variable | Default | Module | Description |
|----------|---------|--------|-------------|
| `enable_ingress_vpc` | `false` | `ingress_vpc` | Creates the Ingress VPC for incoming public traffic |
| `enable_egress_vpc` | `false` | `egress_vpc` | Creates the Egress VPC for outbound traffic from internal services |
| `enable_firewall` | `false` | `firewall` | Applies baseline firewall rules to the Ingress VPC (requires `enable_ingress_vpc=true`) |
| `enable_waf` | `false` | `waf` | Deploys Google Cloud Armor WAF policy for DDoS protection |
| `enable_cdn` | `false` | `cdn` | Creates CDN backend bucket for static content caching (optional - only needed for static assets) |
| `enable_demo_backend` | `false` | `demo_backend` | Deploys demo Cloud Run service with Serverless NEG for infrastructure validation |
| `enable_dr_loadbalancer` | `false` | `dr_loadbalancer` | Creates Global HTTPS Load Balancer with domain-based routing (requires `enable_demo_backend=true`) |
| `enable_self_signed_cert` | `false` | `self_signed_certificate` | Uses self-signed SSL certificate (for testing). If `false`, creates Google-managed certificate using `managed_ssl_domain` |
| `enable_billing` | `false` | `billing` | Creates billing budget with alert thresholds at 50%, 80%, 100% of HKD 1,000/month |
| `enable_logging_bucket` | `true` | `demo_backend` | Creates Cloud Logging bucket with 30-day retention for NFR-001 compliance. Set to `false` for fast testing iterations to avoid 1-7 day bucket deletion delays |

**Example: Minimal Deployment (Demo Backend Only)**

```bash
# In terraform.tfvars or via TF_VAR_* environment variables
enable_demo_backend    = true
enable_dr_loadbalancer = true
enable_waf             = true
enable_self_signed_cert = true
```

**Example: Full Production Deployment**

```bash
enable_ingress_vpc      = true
enable_egress_vpc       = true
enable_firewall         = true
enable_waf              = true
enable_demo_backend     = true
enable_dr_loadbalancer  = true
enable_billing          = true
enable_logging_bucket   = true
# enable_cdn            = true  # Only if serving static content
# enable_self_signed_cert = false  # Use managed certificate for production
# managed_ssl_domain    = "your-domain.com"
```
