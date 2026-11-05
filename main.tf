locals {
  # The deprecated boolean inputs map onto the access types azurerm 5.0
  # introduced; the explicit access type wins when both are given (a
  # precondition rejects that combination anyway).
  internet_ingestion_access_type = coalesce(
    var.internet_ingestion_access_type,
    var.internet_ingestion_enabled == false ? "Disabled" : "Enabled",
  )
  internet_query_access_type = coalesce(
    var.internet_query_access_type,
    var.internet_query_enabled == false ? "Disabled" : "Enabled",
  )
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  retention_in_days   = var.retention_in_days

  daily_quota_gb                     = var.daily_quota_gb
  internet_ingestion_access_type     = local.internet_ingestion_access_type
  internet_query_access_type         = local.internet_query_access_type
  reservation_capacity_in_gb_per_day = var.sku == "CapacityReservation" ? var.reservation_capacity_in_gb_per_day : null

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.internet_ingestion_enabled == null || var.internet_ingestion_access_type == null
      error_message = "Set either internet_ingestion_access_type or the deprecated internet_ingestion_enabled, not both."
    }

    precondition {
      condition     = var.internet_query_enabled == null || var.internet_query_access_type == null
      error_message = "Set either internet_query_access_type or the deprecated internet_query_enabled, not both."
    }
  }
}
