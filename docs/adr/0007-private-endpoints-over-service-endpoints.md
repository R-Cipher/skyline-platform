# ADR-0007 — Private Endpoints Over Service Endpoints

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 03 — Secure Networking

## Context

The data tier (Azure SQL and Key Vault) needed to be reachable from the application without traversing the public internet. Azure offers two mechanisms for this: **Service Endpoints** and **Private Endpoints**. A choice was required.

## Decision

Use **Private Endpoints** for both SQL and Key Vault.

## Rationale

The two options solve the problem differently:

| | Service Endpoint | Private Endpoint (chosen) |
|---|---|---|
| What it does | Extends the VNet identity to the service over Azure's backbone; traffic still goes to the service's **public** IP, but Azure recognizes it as coming from the VNet | Gives the service a **private IP inside your VNet**; traffic goes to that private IP |
| Public IP exposure | Service keeps its public endpoint | Service's public endpoint can be fully disabled |
| Scope | Per-region, per-service-type | Per-specific-resource |
| DNS | No DNS change needed | Requires private DNS to resolve the hostname to the private IP |
| On-prem / peered VNet access | Not supported | Supported (the private IP is routable) |

Private Endpoints were chosen because they allow the service's public endpoint to be **disabled entirely** (true network isolation), give a routable private IP that works from peered networks and on-prem, and scope access to the specific resource. Service Endpoints leave the public endpoint in place and only assert VNet identity — weaker isolation.

## Consequences

- **Positive:** SQL's public access could be fully disabled; the data tier is reachable only via private IPs inside the VNet. Strongest available isolation.
- **Trade-off:** Private Endpoints **require private DNS** to be useful (see ADR-0009) — more moving parts than service endpoints. Each private endpoint also has a small hourly cost. Both accepted for the security gain.

## References

- https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview
- https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview
