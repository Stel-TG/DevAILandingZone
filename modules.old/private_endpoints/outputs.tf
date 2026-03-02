output "endpoint_ids" { value = { for k, v in azurerm_private_endpoint.endpoints : k => v.id } }
