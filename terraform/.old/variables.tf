variable "client_id" {}
variable "client_secret" {}
variable "ssh_public_key" {}
variable "sql_user" {}
variable "sql_password" {}

variable "agent_count" {
    default = 3
}

variable "dns_prefix" {
    default = "sbd"
}

variable cluster_name {
    default = "sbd"
}

variable resource_group_name {
    default = "sbd"
}

variable location {
    default = "Central US"
}

variable log_analytics_workspace_name {
    default = "sbdworkspace"
}

# refer https://azure.microsoft.com/global-infrastructure/services/?products=monitor for log analytics available regions
variable log_analytics_workspace_location {
    default = "westus"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing 
variable log_analytics_workspace_sku {
    default = "PerGB2018"
}