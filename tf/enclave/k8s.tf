resource "azurerm_resource_group" "rg" {
  name     = "${var.name_prefix}"
  location = "${var.location}"
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.name_prefix}workspace"
  location            = "${var.log_analytics_workspace_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  sku                 = "${var.log_analytics_workspace_sku}"
}

resource "azurerm_log_analytics_solution" "las" {
  solution_name         = "ContainerInsights"
  location              = "${azurerm_log_analytics_workspace.law.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  workspace_resource_id = "${azurerm_log_analytics_workspace.law.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.law.name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${var.name_prefix}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  dns_prefix          = "${var.name_prefix}"
  api_server_authorized_ip_ranges = []
  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = "${var.ssh_public_key}"
    }
  }

  agent_pool_profile {
    name            = "agentpool"
    count           = "${var.agent_count}"
    vm_size         = "Standard_DS1_v2"
    os_type         = "Linux"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = "${var.client_id}"
    client_secret = "${var.client_secret}"
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.law.id}"
    }
  }

  role_based_access_control {
    enabled = true
  }
}

resource "azurerm_mysql_server" "mysql" {
  name                = "${var.name_prefix}-pegasus"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  sku {
    name     = "B_Gen5_2"
    capacity = 2
    tier     = "Basic"
    family   = "Gen5"
  }

  storage_profile {
    storage_mb            = 5120
    backup_retention_days = 7
    geo_redundant_backup  = "Disabled"
  }

  administrator_login          = "${var.sql_user}"
  administrator_login_password = "${var.sql_password}"
  version                      = "5.7"
  ssl_enforcement              = "Enabled"
}