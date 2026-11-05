terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Floor: internet_ingestion_access_type / internet_query_access_type,
      # which replace the internet_*_enabled arguments removed in 5.0, only
      # exist from azurerm 5.0.0, so one configuration cannot cover 4.x and 5.x.
      # Ceiling: tested against 5.x; 6.0 has not been vetted.
      version = ">= 5.0, < 6.0"
    }
  }
}
