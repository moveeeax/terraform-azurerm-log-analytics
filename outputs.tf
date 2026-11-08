output "id" {
  description = "ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_id" {
  description = "Customer ID (workspace ID) of the workspace."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "primary_shared_key" {
  description = "Primary shared key used by agents to send data to the workspace."
  value       = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive   = true
}

output "table_ids" {
  description = "Map of table name to the ID of each table managed through var.tables."
  value       = { for k, t in azurerm_log_analytics_workspace_table.this : k => t.id }
}
