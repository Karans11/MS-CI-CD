output "resource_group_name" {
  value = azurerm_resource_group.fakebank.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.fakebank.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "storage_account_url" {
  value = azurerm_storage_account.pii.primary_blob_endpoint
}

output "pii_blob_url" {
  value = azurerm_storage_blob.pii_dataset.url
}
