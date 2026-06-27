# ADR-0008 — Regional VNet Integration Over an App Service Environment (ASE)

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 03 — Secure Networking

## Context

The App Service needed to send outbound traffic into the VNet so it could reach the private endpoints for SQL and Key Vault. Azure offers two ways to put App Service on a VNet: **regional VNet integration** (a feature of the multi-tenant App Service) and an **App Service Environment (ASE)** (a fully isolated, single-tenant deployment of App Service into your VNet).

## Decision

Use **regional VNet integration** with a delegated subnet (`snet-app-integration`, delegated to `Microsoft.Web/serverFarms`) and `vnet_route_all_enabled = true`.

## Rationale

- **Fit for the requirement.** The need is outbound private connectivity from the app to the data tier. Regional VNet integration delivers exactly that — outbound traffic routes through the VNet — at no extra platform cost on a Standard (S1) plan.
- **ASE is dramatically heavier.** An ASE is a dedicated, single-tenant App Service deployment with a high fixed monthly cost (hundreds of dollars), intended for high-isolation/high-scale/regulatory scenarios. It would be massive over-engineering for this workload.
- `vnet_route_all_enabled = true` ensures *all* outbound traffic (not just RFC1918 ranges) routes through the VNet, so the app consistently uses the private path.

## Consequences

- **Positive:** Private outbound connectivity to SQL and Key Vault with no added platform cost; simple to configure.
- **Trade-off:** Regional VNet integration covers **outbound** from the app; it does not by itself make the app's **inbound** endpoint private (the app still has a public hostname). That's acceptable here — the app is meant to be public-facing; it's the *data tier* that must be private. Locking down the app's inbound side (e.g., via Front Door + access restrictions) is a later concern.
- The integration subnet must be **delegated** to `Microsoft.Web/serverFarms` and used by nothing else, which is why a dedicated subnet was created.

## References

- https://learn.microsoft.com/en-us/azure/app-service/overview-vnet-integration
- https://learn.microsoft.com/en-us/azure/app-service/environment/overview
