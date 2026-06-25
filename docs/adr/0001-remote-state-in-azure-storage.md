# ADR-0001 — Remote State in Azure Storage

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 01 — Foundation

## Context

Terraform state must be stored somewhere shared and safe so that infrastructure is reproducible and multiple engineers (or a future CI pipeline) can work from one source of truth without corrupting it. The options considered were the Azure Storage backend, a managed SaaS (Terraform Cloud / HCP), and third-party orchestration (Spacelift, env0).

## Decision

Store state in an **Azure Storage account** using the Terraform `azurerm` backend, with blob versioning, soft delete, and Entra-based authentication.

## Rationale

- **Stays in-tenant.** State can contain sensitive values (e.g. database credentials in later labs), so keeping it in our own RBAC-controlled, encrypted storage is the most defensible posture.
- **Low cost.** State is a tiny file; storage cost is cents per month with no per-seat or per-run SaaS fees.
- **Default expectation on Azure teams.** This is the pattern most Azure shops already use, making the skill directly transferable.
- **Native state locking.** The azurerm backend locks via a blob lease automatically — no extra infrastructure required.

## Consequences

- **Positive:** No new vendor, no recurring cost, full control over state security, standard industry approach.
- **Trade-off:** We forgo SaaS conveniences like a run-history UI and built-in policy-as-code (Sentinel/OPA). These are valuable at larger scale but unnecessary for a single team. Auditability is instead provided by Git history and the Azure Activity Log; automated policy checks are added later via CI (Lab 04).

## References

- https://developer.hashicorp.com/terraform/language/backend/azurerm
- https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage
