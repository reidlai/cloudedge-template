# Module Documentation

This document details the codebase structure, module dependency graphs, and wiring summaries.

## Module Dependency Graph

The following diagram illustrates the dependencies between OpenTofu modules and how module outputs are wired to module inputs:

```
┌─────────────────┐
│  Ingress VPC    │────┐
│                 │    │ (outputs: ingress_vpc_name, ingress_vpc_id,
│  Outputs:       │    │  ingress_subnet_name, ingress_subnet_cidr)
│  - vpc_name     │    │
│  - vpc_id       │    ▼
│  - subnet_name  │  ┌──────────────┐
│  - subnet_cidr  │  │  Firewall    │
└─────────────────┘  │              │
                     │  Inputs:     │
                     │  - network_name ← ingress_vpc.ingress_vpc_name
                     └──────────────┘

┌─────────────────┐    ┌──────────────────────┐
│  Self-Signed    │───▶│  DR Load Balancer    │◀─────┐
│  Certificate    │    │                      │       │
│                 │    │  Inputs:             │       │
│  Outputs:       │    │  - ssl_certificates ← self_signed_cert.self_link
│  - self_link    │    │  - default_service_id ← demo_backend.backend_service_id
└─────────────────┘    └──────────────────────┘       │
                                                      │
┌─────────────────┐                                   │
│  Demo Backend   │───────────────────────────────────┘
│                 │
│  Outputs:       │
│  - backend_service_id (wired to DR Load Balancer)
│  - backend_service_name
│  - cloud_run_service_name
│  - cloud_run_service_uri
│  - serverless_neg_id
└─────────────────┘

┌─────────────────┐
│  GCS Bucket     │────┐
│  (cdn_content)  │    │ (outputs: bucket.name)
└─────────────────┘    │
                       ▼
                  ┌──────────────┐
                  │     CDN      │
                  │              │
                  │  Inputs:     │
                  │  - bucket_name ← google_storage_bucket.cdn_content.name
                  │              │
                  │  Outputs:    │
                  │  - cdn_backend_id
                  │  - cdn_backend_name
                  │  - cdn_backend_self_link
                  └──────────────┘

┌─────────────────┐
│  Egress VPC     │  (for future external service connectivity)
│                 │
│  Outputs:       │
│  - egress_vpc_name
│  - egress_vpc_id
│  - egress_subnet_name
│  - egress_subnet_cidr
└─────────────────┘

┌─────────────────┐
│  WAF Policy     │  (available for backend service attachment)
│                 │
│  Outputs:       │
│  - waf_policy_name
│  - waf_policy_id
│  - waf_policy_self_link
└─────────────────┘

┌─────────────────┐
│  Billing Budget │  (monitoring & alerts)
│                 │
│  Outputs:       │
│  - budget_id
│  - budget_name
│  - budget_amount
│  - budget_currency
└─────────────────┘
```
