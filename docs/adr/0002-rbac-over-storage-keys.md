# ADR-0002 — Entra ID / RBAC Auth Over Shared Storage Keys

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 01 — Foundation

## Context

The Terraform state storage account can be accessed in two ways: via **shared access keys** (long-lived 512-bit keys granting full account access) or via **Entra ID identities with RBAC role assignments**. A choice was needed for how Terraform and engineers authenticate to the state backend.

## Decision

Use **Entra ID authentication** (`use_azuread_auth = true` in the backend), **disable public blob access**, enforce **TLS 1.2 minimum**, and grant access through scoped RBAC roles (`Storage Blob Data Contributor`). Shared key usage is avoided.

## Rationale

- **No static secret to leak.** Shared keys don't expire and grant unrestricted access; if leaked in code, a log, or a commit, they remain valid until manually rotated — a top cloud breach vector.
- **Auditable and revocable.** Entra identities can be centrally audited, protected by Conditional Access / MFA, and revoked instantly.
- **Scoped permissions.** RBAC grants only the access needed at a specific scope, rather than all-or-nothing account keys.

## Consequences

- **Positive:** Significantly stronger security posture with no credential to manage or rotate.
- **Trade-off / gotcha:** RBAC requires an explicit **data-plane** role assignment. During Lab 01 this surfaced as a `403 AuthorizationPermissionMismatch` on `terraform init` — Owner/Contributor on the resource group (control plane) does not grant blob read/write (data plane). Resolved by assigning `Storage Blob Data Contributor`. This is the security model working correctly, and it reinforced the control-plane vs data-plane distinction.

## References

- https://learn.microsoft.com/en-us/azure/storage/blobs/authorize-access-azure-active-directory
- https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent
- https://learn.microsoft.com/en-us/azure/storage/blobs/assign-azure-role-data-access
