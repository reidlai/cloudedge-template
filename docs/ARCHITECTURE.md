# Infrastructure Architecture

This document provides a deep dive into the Vibetics CloudEdge infrastructure architecture, including current MVP scope, detailed diagrams, and future roadmap.

## Scope: Infrastructure-Only Deployment

**This project provides INFRASTRUCTURE-ONLY deployment.** API management capabilities (authentication, authorization, rate limiting, request validation, API versioning, analytics) are **OUT OF SCOPE** and are the responsibility of applications deployed on this infrastructure.

**What IS Included** (Network-Level Security):

- ✅ WAF for DDoS protection
- ✅ Firewall rules and VPC isolation
- ✅ Load Balancer with domain-based routing
- ✅ Serverless NEG (Google-managed private connectivity for Cloud Run backends)
- ✅ Distributed tracing for infrastructure observability

**What is NOT Included** (Application-Level Security):

- ❌ API Gateway (authentication, rate limiting, request transformation)
- ❌ API-level security policies (API keys, OAuth, JWT validation)
- ❌ API analytics and developer portal

**Security Boundary**: The baseline infrastructure provides **network-level security** (WAF, firewall, VPC isolation, Serverless NEG private connectivity). Applications are responsible for **application-level security** (authentication, authorization, input validation). Applications must implement their own API security within their service code or deploy API Gateway (Cloud Endpoints/Apigee) as a separate feature.

**Demo Backend Access**: The demo Cloud Run service uses `allUsers` IAM binding for unauthenticated access from the load balancer. This is intentional for infrastructure validation. Production applications MUST implement proper authentication mechanisms.

For detailed scope information, see [Feature Specification](specs/001-create-cloud-agnostic/spec.md#scope-clarification).

## Access Validation

**✅ Allowed Traffic Path:**

```bash
curl -k -H "Host: example.com" https://34.117.156.60
# → Cloud Armor → HTTPS LB → Backend Service → Serverless NEG → Cloud Run
# Result: HTTP 200 OK with demo API response
```

**❌ Blocked Traffic Path:**

```bash
curl https://nonprod-demo-api-vbuysgm44q-pd.a.run.app
# → Direct to Cloud Run URL
# Result: HTTP 403/404 (blocked by INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER policy)
```

## VPC Connectivity Scenarios

| Scenario | Recommended Solution | Why It's Better |
| :---- | :---- | :----|
| Ingress VPC to Cloud Run (Same Project/Organization) | Internal ALB + Serverless NEG + Cloud Run | Simpler to configure than PSC, lower complexity, and avoids the "managed service" abstraction when one is not needed. |
| Ingress VPC to VPC B (Different Projects/Organizations) | Internal ALB + Private Service Connect (PSC) + Cloud Run / GKE / Compute Engine | This is the main use case for PSC. It is designed specifically to allow private consumption of a "published service" across security or administrative boundaries without VPC peering. |

## Future Architecture: Multi-Backend Support (Features 002-003)

The baseline infrastructure is **architected to support** multiple backend types and multi-region deployments. Future features will extend (not replace) the current architecture.

### Planned Capabilities

**Multi-Backend Support** (Future Feature 002):

- Application teams will be able to deploy their own VPCs with Cloud Run, GKE clusters, or Compute Engine VMs
- Each application VPC connects to the central load balancer via Private Service Connect (PSC)
- No public IPs on backend services (all traffic flows through central WAF)
- Domain-based routing maps hostnames to specific application VPCs (e.g., `app1.example.com` → App1 VPC)

**Multi-Region Disaster Recovery** (Future Feature 003):

- Primary + secondary region configuration per application
- Automatic health-based failover (60-second RTO)
- Optional geo-affinity routing (EU users → europe-west1)
- Active-passive or active-active traffic distribution strategies

### Target Architecture Diagram

```
                                    INTERNET
                                       ↓
                          ┌────────────────────────┐
                          │  Global Anycast IP     │
                          └───────────┬────────────┘
                                      │
┌─────────────────────────────────────┼──────────────────────────────────────┐
│                          EDGE SECURITY LAYER                               │
│                          ┌──────────▼──────────┐                           │
│                          │   Cloud Armor (WAF) │                           │
│                          │  + DDoS protection  │                           │
│                          └──────────┬──────────┘                           │
│                                     │                                      │
│                          ┌──────────▼──────────┐                           │
│                          │   Cloud CDN         │ (OPTIONAL - only for      │
│                          │  (if static content)│  static content caching)  │
│                          └──────────┬──────────┘                           │
└─────────────────────────────────────┼──────────────────────────────────────┘
                                      │
┌─────────────────────────────────────┼──────────────────────────────────────┐
│           GLOBAL LOAD BALANCER (Ingress VPC)                               │
│                    ┌────────────────▼────────────────┐                     │
│                    │  HTTPS Load Balancer            │                     │
│                    │  - Multi-region DR              │                     │
│                    │  - Host-based routing           │                     │
│                    └────────────────┬────────────────┘                     │
│                    ┌────────────────▼────────────────┐                     │
│                    │      URL Map & Host Rules       │                     │
│                    │  app1.example.com → App1 VPC    │                     │
│                    │  app2.example.com → App2 VPC    │                     │
│                    │  app3.example.com → App3 VPC    │                     │
│                    └─────┬──────────┬────────┬───────┘                     │
└──────────────────────────┼──────────┼────────┼─────────────────────────────┘
                           │          │        │
        ┌──────────────────┘          │        └──────────────────┐
        │                             │                           │
        │                             │                           │
┌───────▼───────┐          ┌──────────▼────────┐         ┌────────▼────────┐
│ Backend Svc 1 │          │  Backend Svc 2    │         │  Backend Svc 3  │
│ (Cloud Run)   │          │  (GKE)            │         │  (Compute VMs)  │
│ Multi-region  │          │  Multi-region     │         │  Multi-region   │
└───────┬───────┘          └──────────┬────────┘         └─────────┬───────┘
        │                             │                            │
┌───────▼──────────────────────────────────────────────────────────▼────────┐
│               PRIVATE SERVICE CONNECT (PSC) LAYER                         │
│   ┌───────────┐         ┌───────────┐         ┌───────────┐               │
│   │ PSC NEG   │         │ PSC NEG   │         │ PSC NEG   │               │
│   │ Serverless│         │ VM IP:PORT│         │ VM IP:PORT│               │
│   └─────┬─────┘         └─────┬─────┘         └─────┬─────┘               │
└─────────┼─────────────────────┼─────────────────────┼─────────────────────┘
          │                     │                     │
┌─────────▼──────┐    ┌─────────▼──────┐    ┌─────────▼──────┐
│   App1 VPC     │    │   App2 VPC     │    │   App3 VPC     │
│ (Cloud Run)    │    │   (GKE)        │    │(Compute VMs)   │
│                │    │                │    │                │
│ ┌────────────┐ │    │ ┌────────────┐ │    │ ┌────────────┐ │
│ │ Cloud Run  │ │    │ │GKE Cluster │ │    │ │ Managed    │ │
│ │ Service    │ │    │ │+ K8s Svc   │ │    │ │ Instance   │ │
│ │ (Internal) │ │    │ │  (Internal)│ │    │ │ Group (MIG)│ │
│ │            │ │    │ │            │ │    │ │            │ │
│ │ + Firewall │ │    │ │ + Firewall │ │    │ │ + Firewall │ │
│ └────────────┘ │    │ └────────────┘ │    │ └────────────┘ │
└────────────────┘    └────────────────┘    └────────────────┘
```

**Key Differences from MVP**:

- **Multiple Application VPCs**: Each application team deploys their own isolated VPC
- **Multi-Backend Types**: Support for Cloud Run, GKE, and Compute Engine VMs
- **Multi-Region**: Primary + secondary regions for each backend with automatic failover
- **Production Workloads**: Real application services (not just demo/testing)

**Architecture Readiness**:

- ✅ URL Map already supports multiple host rules (extensible)
- ✅ Backend services + NEG pattern works for all backend types
- ✅ PSC demonstrated with demo backend (reusable for production)
- ✅ Global Load Balancer natively supports multi-region backends

**No Rework Required**: Future features will add new modules and configuration without changing the baseline infrastructure.
