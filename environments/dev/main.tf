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
  name                      = "app-${module.naming.base}" # must be globally unique
  resource_group_name       = azurerm_resource_group.platform.name
  location                  = azurerm_resource_group.platform.location
  service_plan_id           = azurerm_service_plan.main.id
  https_only                = true
  tags                      = module.naming.tags
  virtual_network_subnet_id = azurerm_subnet.app_integration.id

  identity {
    type = "SystemAssigned" # Azure manages the credential lifecycle for us
  }

  site_config {
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true # route ALL outbound through the VNet
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
  name                          = "sql-${module.naming.base}" # globally unique
  resource_group_name           = azurerm_resource_group.platform.name
  location                      = azurerm_resource_group.platform.location
  version                       = "12.0"
  administrator_login           = "skylineadmin"
  administrator_login_password  = random_password.sql_admin.result
  minimum_tls_version           = "1.2"
  tags                          = module.naming.tags
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-skyline"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "Basic" # 5 DTU, ~cheap. Use S0/GP_S for real workloads.
  tags      = module.naming.tags
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
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = ["99.148.228.38/32"]
  }
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

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${module.naming.base}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  address_space       = ["10.20.0.0/16"]
  tags                = module.naming.tags
}

# Subnet for App Service regional VNet integration — must be DELEGATED and used by nothing else
resource "azurerm_subnet" "app_integration" {
  name                 = "snet-app-integration"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]

  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet that will host the private endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/24"]
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.platform.name
  tags                = module.naming.tags
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.platform.name
  tags                = module.naming.tags
}

# Link the zones to the VNet so resources in it use them for resolution
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-dns-link"
  resource_group_name   = azurerm_resource_group.platform.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = module.naming.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = "kv-dns-link"
  resource_group_name   = azurerm_resource_group.platform.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = module.naming.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${module.naming.base}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = module.naming.tags

  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${module.naming.base}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = module.naming.tags

  private_service_connection {
    name                           = "kv-connection"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}

resource "azurerm_network_security_group" "pe" {
  name                = "nsg-pe-${module.naming.base}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  tags                = module.naming.tags
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.pe.id
}