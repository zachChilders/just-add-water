variable "client_id" {}
variable "client_secret" {}
variable "ssh_public_key" {}
variable "name_prefix" {}
variable "agent_count" {
  default = 3
}

variable location {
  default = "South Central US"
}

# refer https://azure.microsoft.com/global-infrastructure/services/?products=monitor for log analytics available regions
variable log_analytics_workspace_location {
  default = "westus"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing 
variable log_analytics_workspace_sku {
  default = "PerGB2018"
}
