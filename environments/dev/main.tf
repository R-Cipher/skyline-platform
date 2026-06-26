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

resource "azurerm_service_plan" "main" {
  name                = "asp-${module.naming.base}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  os_type             = "Linux"
  sku_name            = "S1" # Basic: cheap, supports slots? -> see note
  tags                = module.naming.tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${module.naming.base}" # must be globally unique
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = module.naming.tags

  identity {
    type = "SystemAssigned" # Azure manages the credential lifecycle for us
  }

  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      node_version = "20-lts" # swap to your stack (dotnet, python, etc.)
    }
  }

  app_settings = {
    WEBSITE_RUN_FROM_PACKAGE = "1"
    # Key Vault reference: App Service resolves this at runtime using the MI.
    SQL_CONNECTION_STRING = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.sql_conn.versionless_id})"
  }
}

resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  https_only     = true
  tags           = module.naming.tags
  identity { type = "SystemAssigned" }

  site_config {
    minimum_tls_version = "1.2"
    application_stack { node_version = "20-lts" }
  }
}

resource "random_password" "sql_admin" {
  length  = 24
  special = true
}

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${module.naming.base}" # globally unique
  resource_group_name          = azurerm_resource_group.platform.name
  location                     = azurerm_resource_group.platform.location
  version                      = "12.0"
  administrator_login          = "skylineadmin"
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
  tags                         = module.naming.tags
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-skyline"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "Basic" # 5 DTU, ~cheap. Use S0/GP_S for real workloads.
  tags      = module.naming.tags
}

# TEMPORARY: allow Azure services to reach SQL. We REMOVE this in Lab 3.
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0" # the 0.0.0.0/0.0.0.0 rule = "Allow Azure services"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-skyline-dev-eus2" # <=24 chars, globally unique
  resource_group_name        = azurerm_resource_group.platform.name
  location                   = azurerm_resource_group.platform.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true  # RBAC instead of legacy access policies
  purge_protection_enabled   = false # true in prod; false in lab so you can fully destroy
  tags                       = module.naming.tags
}

# Let YOU (the deployer) write secrets
resource "azurerm_role_assignment" "me_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store the SQL connection string as a secret
resource "azurerm_key_vault_secret" "sql_conn" {
  name         = "SqlConnectionString"
  key_vault_id = azurerm_key_vault.main.id
  value        = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};User ID=skylineadmin;Password=${random_password.sql_admin.result};Encrypt=true;"
  depends_on   = [azurerm_role_assignment.me_kv_admin]
}

# The app's managed identity may READ secrets
resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

