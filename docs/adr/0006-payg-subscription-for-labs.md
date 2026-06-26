# ADR-0006 — Dedicated Pay-As-You-Go Subscription for the Lab Environment

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 02 — Web Platform

## Context

Lab 02 deployments failed repeatedly with two errors: App Service `401 Unauthorized — Total VMs: 0` (quota) and SQL `ProvisioningDisabled` (regional restriction). Investigation via the Usage + quotas blade showed the **Visual Studio Enterprise subscription** restricts App Service to Premium-tier quota only (Basic/Standard tiers showed `0 of 0`) and disables SQL provisioning across regions. These are deliberate restrictions on dev/test benefit subscriptions, not configuration defects.

## Decision

Provision a dedicated **Pay-As-You-Go (PAYG) subscription** for the lab environment and repoint Terraform at it, keeping the Visual Studio subscription for its intended dev/test use.

## Rationale

- **Removes the blocker permanently.** PAYG has normal quotas and no tier-based service restrictions, so App Service and SQL provision normally. Upcoming labs (private networking, Front Door, etc.) would hit even more VS-subscription restrictions.
- **Cost is controlled by discipline, not tier limits.** With teardown (`terraform destroy`) between sessions, the lab footprint is a few dollars per day of uptime.
- **Alternatives were weaker:** forcing expensive Premium App Service SKUs (to fit VS quota) still wouldn't solve the SQL restriction; quota-increase requests on a VS subscription are not reliably granted.

## Consequences

- **Positive:** Labs proceed without fighting subscription restrictions. The migration validated that the IaC is fully portable — only `ARM_SUBSCRIPTION_ID` and one backend storage-account value changed; no resource definitions were touched.
- **Trade-off:** Real (small) cost on PAYG, mitigated by nightly teardown. A new subscription also required first-use setup: waiting out propagation lag, registering resource providers (`Microsoft.Storage`, `Web`, `Sql`, `KeyVault`, `Network`), and selecting a region with default vCPU quota (Central US had quota; East US did not).

## References

- https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription
- https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types
- https://learn.microsoft.com/en-us/azure/quotas/view-quotas
