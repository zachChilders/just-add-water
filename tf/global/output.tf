output "TF_storage_key" {
    value = "${azurerm_storage_account.global-tfstore.primary_access_key}"
}

output "kv_name" {
    value = "${azurerm_key_valut.global-kv.name}"
}