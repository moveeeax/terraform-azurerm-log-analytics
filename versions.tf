terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Floor verified empirically: every argument this module sets on
      # azurerm_log_analytics_workspace (including
      # reservation_capacity_in_gb_per_day) is already present in the resource
      # schema at 3.0.0, so ">= 3.0" is correct rather than optimistic.
      # The upper bound guards against an untested 5.x major; 4.x is validated.
      version = ">= 3.0, < 5.0"
    }
  }
}
