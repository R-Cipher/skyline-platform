locals {
  # Short codes keep names within Azure length limits
  loc_short = {
    eastus2  = "eus2"
    eastus   = "eus"
    westus2  = "wus2"
  }[var.location]

  # Base pattern: <type>-<workload>-<env>-<region>  (CAF-aligned)
  base = "${var.workload}-${var.environment}-${local.loc_short}"

  tags = {
    workload    = var.workload
    environment = var.environment
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
  }
}