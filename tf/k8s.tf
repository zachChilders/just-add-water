resource "azurerm_resource_group" "rg" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"
}

resource "azurerm_log_analytics_workspace" "law" {
    name                = "${var.log_analytics_workspace_name}"
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
    name                = "${var.cluster_name}"
    location            = "${azurerm_resource_group.rg.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    dns_prefix          = "${var.dns_prefix}"

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