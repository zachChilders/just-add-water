output "tf_storage_key" {
    value = "${azurerm_storage_account.global-tfstore.primary_access_key}"
}
