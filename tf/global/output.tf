output "TF_storage_key" {
  value = "${azurerm_storage_account.global-tfstore.primary_access_key}"
}
output "kv_name" {
  value = "${azurerm_key_vault.global-kv.name}"
}
output "acr_admin" {
  value = "${azurerm_container_registry.global-acr.admin_username}"
}
output "acr_password" {
  value = "${azurerm_container_registry.global-acr.admin_password}"
}
output "acr_login_server" {
  value = "${azurerm_container_registry.global-acr.login_server}"
}
