resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 6
}

resource "azurerm_resource_group" "global-rg" {
  name     = "sbd-global"
  location = "South Central US"
}

resource "azurerm_key_vault" "global-kv" {
  name                        = "sbdvault"
  location                    = azurerm_resource_group.global-rg.location
  resource_group_name         = azurerm_resource_group.global-rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = "e86183dc-d7cc-4132-8b39-a8de37272433"

  sku_name = "premium"

  # We should apply these ACLs anywhere we possibly can.
  # network_acls {
  #   default_action = "Deny"
  #   bypass         = "AzureServices"
  # }
}

resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id = azurerm_key_vault.global-kv.id

  tenant_id = "e86183dc-d7cc-4132-8b39-a8de37272433"
  object_id = "fb27f79f-4a67-452c-ba1e-55ed2a1b29a6"

  secret_permissions = [
    "get",
    "list",
    "set",
  ]
}

resource "azurerm_container_registry" "global-acr" {
  name                = "sbdacrglobal"
  resource_group_name = azurerm_resource_group.global-rg.name
  location            = azurerm_resource_group.global-rg.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_dns_zone" "global-dns" {
  name                = "sbd-pegasus.com"
  resource_group_name = azurerm_resource_group.global-rg.name
}

resource "azurerm_storage_account" "global-tfstore" {
  name                     = "sbdtfstorage"
  resource_group_name      = azurerm_resource_group.global-rg.name
  location                 = azurerm_resource_group.global-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_account" "global-logstore" {
  name                     = "sbdlogstorage"
  resource_group_name      = azurerm_resource_group.global-rg.name
  location                 = azurerm_resource_group.global-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_traffic_manager_profile" "global-atm" {
  name                = "sbd-atm"
  resource_group_name = "${azurerm_resource_group.global-rg.name}"

  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${random_id.server.hex}"
    ttl           = 100
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}

resource "azurerm_azuread_application" "sbd-aad" {
  name                       = "sbd"
  homepage                   = "https://sbd"
  identifier_uris            = ["https://sbd"]
  reply_urls                 = ["https://replysbd"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}


resource "azurerm_azuread_service_principal" "sbd-sp" {
  application_id = "${azurerm_azuread_application.sbd-aad.application_id}"
}
