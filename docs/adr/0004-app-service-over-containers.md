# ADR-0004 — App Service (PaaS) Over Containers or VMs

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 02 — Web Platform

## Context

Skyline needs to host a single customer-facing web application and its API. The hosting options considered were Azure App Service (PaaS), Azure Container Apps, Azure Kubernetes Service (AKS), and plain Virtual Machines.

## Decision

Host the application on **Azure App Service (Linux)**.

## Rationale

The guiding principle is to choose the highest-level abstraction that meets the requirement.

| Option | When it fits | Why not here |
|--------|--------------|--------------|
| **App Service (chosen)** | Standard web apps/APIs; want PaaS with built-in slots, scaling, TLS | — |
| Container Apps | Containerized microservices, scale-to-zero | Adds a container build/registry pipeline not needed for one app |
| AKS | Many services, fine-grained orchestration, team has k8s skills | Massive operational overhead for a single web app |
| Virtual Machines | Legacy/custom-OS lift-and-shift | Reintroduces the patching/scaling burden PaaS removes |

App Service is the sweet spot for "one web app, move fast": no VM management, built-in deployment slots, managed-identity integration, and easy scaling.

## Consequences

- **Positive:** Minimal operational overhead, native managed identity + Key Vault integration, deployment slots for zero-downtime releases.
- **Trade-off:** Less control than containers/k8s and some tier-based feature gating (e.g. slots require Standard+, which drove the S1 choice). Acceptable for this workload; revisit if the app grows into many services.

## References

- https://learn.microsoft.com/en-us/azure/app-service/overview
- https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/compute-decision-tree
