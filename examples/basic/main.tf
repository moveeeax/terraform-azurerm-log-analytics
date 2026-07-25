terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "log_analytics" {
  source = "../.."

  name                = "example-law"
  resource_group_name = "example-rg"
  location            = "eastus"
  retention_in_days   = 30

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "workspace_id" {
  value = module.log_analytics.workspace_id
}
