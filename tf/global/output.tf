output "tf-storage-key" {
  value = "${azurerm_storage_account.global-tfstore.primary_access_key}"
}
output "kv-name" {
  value = "${azurerm_key_vault.global-kv.name}"
}
output "acr-admin" {
  value = "${azurerm_container_registry.global-acr.admin_username}"
}
output "acr-password" {
  value = "${azurerm_container_registry.global-acr.admin_password}"
}
output "acr-login-server" {
  value = "${azurerm_container_registry.global-acr.login_server}"
}
