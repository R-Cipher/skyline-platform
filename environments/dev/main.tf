# Built-in policy: "Require a tag on resources"
data "azurerm_policy_definition" "require_tag" {
  display_name = "Require a tag on resources"
}

resource "azurerm_resource_group_policy_assignment" "require_owner_tag" {
  name                 = "require-owner-tag"
  resource_group_id    = azurerm_resource_group.platform.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id

  parameters = jsonencode({
    tagName = { value = "owner" }
  })
}

module "naming" {
  source      = "../../modules/naming"
  workload    = "skyline"
  environment = var.environment
  location    = var.location
  owner       = var.owner
  cost_center = var.cost_center
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${module.naming.base}" # rg-skyline-dev-eus2
  location = var.location
  tags     = module.naming.tags
}