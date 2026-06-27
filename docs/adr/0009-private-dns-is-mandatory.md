# ADR-0009 — Private DNS Is Mandatory for Private Endpoints

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 03 — Secure Networking

## Context

A private endpoint gives a service a private IP inside the VNet — but the application code still connects using the service's normal public hostname (e.g. `sql-skyline-dev-cus.database.windows.net`). Without intervention, that hostname resolves to the service's **public** IP, so the app would keep connecting publicly and the private endpoint would sit unused. A DNS mechanism is required to make the hostname resolve to the private IP from inside the VNet.

## Decision

Deploy an Azure **Private DNS zone** per service (`privatelink.database.windows.net` for SQL, `privatelink.vaultcore.azure.net` for Key Vault), link each zone to the VNet, and attach a `private_dns_zone_group` to each private endpoint so the A records are created automatically.

## Rationale

- **Without private DNS, the private endpoint does nothing observable.** The hostname still resolves publicly; the app connects over the public path; the private endpoint is a "bridge to nowhere." This is the single most common private-endpoint mistake.
- The zone names are **fixed by Azure** per service (`privatelink.database.windows.net`, `privatelink.vaultcore.azure.net`) — they are not free choices. Using the wrong name breaks resolution silently.
- The **VNet link** is what makes the zone authoritative for queries originating inside the VNet — so the same hostname returns the private IP inside the VNet and the public IP everywhere else (split-horizon DNS).
- The **`private_dns_zone_group`** on the endpoint auto-creates and maintains the A record (hostname → private IP), so it stays correct without manual record management.

## Consequences

- **Positive:** The app uses its normal connection string unchanged, but traffic resolves to the private IP and stays on the private network. Verified by the A records visible in each private endpoint's DNS configuration (SQL → 10.20.2.5, Key Vault → 10.20.2.4).
- **Trade-off / gotcha:** More resources to manage (zones, links, zone groups), and the fixed zone names and Azure-defined subresource names (`sqlServer`, `vault`) must be exact — a wrong value fails silently rather than erroring loudly.

## References

- https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns
- https://learn.microsoft.com/en-us/azure/dns/private-dns-overview
