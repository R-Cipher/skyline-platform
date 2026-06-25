# ADR-0003 — Imperative Bootstrap for the State Backend

**Status:** Accepted
**Date:** 2026-06
**Context:** Lab 01 — Foundation

## Context

Terraform stores its state in an Azure Storage account. But creating that storage account *with* Terraform requires somewhere to store the storage account's own state — which does not exist yet. This is a circular (chicken-and-egg) dependency that must be broken before any Terraform can run with a remote backend.

Two approaches were considered:
- **A. Imperative bootstrap** — create the backend storage with a one-time CLI/PowerShell script, then point Terraform at it.
- **B. Local-state bootstrap then migrate** — write Terraform with a local backend to create the storage account, apply, then add the remote backend block and run `terraform init -migrate-state`.

## Decision

Use an **imperative bootstrap script** (`bootstrap/bootstrap.ps1`). The state storage account is created once via Azure CLI and is intentionally **not** managed by Terraform.

## Rationale

- **Breaks the recursion cleanly.** No need to manage "state for the state storage."
- **Simple and one-time.** The backend storage account is created once and essentially never changes.
- **Industry-standard pattern.** This is the approach Microsoft's own Terraform-on-Azure guidance uses.

## Consequences

- **Positive:** Simple setup, no fragile migration step, no recursive state problem.
- **Trade-off:** The backend storage account is not represented in Terraform code (it sits "outside" IaC). Given how rarely it changes, the small loss of IaC coverage is an acceptable trade for the reduced complexity. The script is idempotent in intent but **not** safe to run blindly twice — each run generates a new random suffix and would create a duplicate account (encountered and corrected during the lab).

## References

- https://developer.hashicorp.com/terraform/language/backend#initialization
- https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage
