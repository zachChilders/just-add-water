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
  kubernetes_version  = "1.14.8"
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