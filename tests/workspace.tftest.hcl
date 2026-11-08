# Test-only requirement: `mock_provider` needs Terraform >= 1.7.
# The module itself still supports >= 1.5 (see versions.tf) — do not raise
# required_version to satisfy these tests.
#
# Run with: terraform init -backend=false && terraform test

mock_provider "azurerm" {
  # azurerm_log_analytics_workspace_table parses workspace_id at plan time, so
  # the mocked workspace needs a well-formed ID instead of a random string.
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.OperationalInsights/workspaces/test-law"
    }
  }
}

variables {
  name                = "test-law"
  resource_group_name = "test-rg"
  location            = "eastus"
}

run "defaults_are_safe" {
  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "Default sku must be PerGB2018; the legacy tiers are retired and fail at apply."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 30
    error_message = "Default retention must stay at 30 days; raising it silently increases cost for every consumer."
  }

  assert {
    # -1 is the "unlimited" sentinel. Anything else here would cap ingestion
    # by default and make the workspace quietly drop data.
    condition     = azurerm_log_analytics_workspace.this.daily_quota_gb == -1
    error_message = "Default daily_quota_gb must be -1 (unlimited), not a real cap."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_ingestion_access_type == "Enabled"
    error_message = "Default internet_ingestion_access_type must be Enabled; disabling it without a Private Link Scope stops ingestion."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_query_access_type == "Enabled"
    error_message = "Default internet_query_access_type must be Enabled; disabling it without a Private Link Scope breaks queries and alerts."
  }
}

run "deprecated_booleans_map_to_access_types" {
  variables {
    internet_ingestion_enabled = false
    internet_query_enabled     = true
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_ingestion_access_type == "Disabled"
    error_message = "internet_ingestion_enabled = false must map to Disabled."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_query_access_type == "Enabled"
    error_message = "internet_query_enabled = true must map to Enabled."
  }
}

run "access_type_is_passed_through" {
  variables {
    internet_query_access_type = "SecuredByPerimeter"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_query_access_type == "SecuredByPerimeter"
    error_message = "internet_query_access_type should be passed through."
  }
}

run "rejects_both_old_and_new_inputs" {
  command = plan

  variables {
    internet_ingestion_enabled     = false
    internet_ingestion_access_type = "Disabled"
  }

  expect_failures = [azurerm_log_analytics_workspace.this]
}

run "rejects_unknown_access_type" {
  command = plan

  variables {
    internet_query_access_type = "Private"
  }

  expect_failures = [var.internet_query_access_type]
}

run "reservation_capacity_omitted_unless_capacity_reservation_sku" {
  assert {
    condition     = azurerm_log_analytics_workspace.this.reservation_capacity_in_gb_per_day == null
    error_message = "reservation_capacity_in_gb_per_day must be null unless sku is CapacityReservation."
  }
}

run "reservation_capacity_applied_for_capacity_reservation_sku" {
  variables {
    sku                                = "CapacityReservation"
    reservation_capacity_in_gb_per_day = 200
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.reservation_capacity_in_gb_per_day == 200
    error_message = "reservation_capacity_in_gb_per_day must be passed through when sku is CapacityReservation."
  }
}

run "accepts_capacity_reservation_and_lacluster_skus" {
  variables {
    sku = "LACluster"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "LACluster"
    error_message = "LACluster must remain a selectable sku."
  }
}

# --- rejections -------------------------------------------------------------
# The azurerm provider's own schema validation still accepts these retired
# tiers, so without the module-level validation they pass `terraform validate`
# and only fail at apply.

run "rejects_retired_free_sku" {
  command = plan

  variables {
    sku = "Free"
  }
  expect_failures = [var.sku]
}

run "rejects_retired_standard_sku" {
  command = plan

  variables {
    sku = "Standard"
  }
  expect_failures = [var.sku]
}

run "rejects_retired_premium_sku" {
  command = plan

  variables {
    sku = "Premium"
  }
  expect_failures = [var.sku]
}

run "rejects_misspelled_sku" {
  command = plan

  variables {
    sku = "PerGB2018-v2"
  }
  expect_failures = [var.sku]
}

# daily_quota_gb = 0 is accepted by azurerm 3.x and 4.x alike and caps
# ingestion at zero — the workspace stops collecting data with no error.
run "rejects_zero_daily_quota" {
  command = plan

  variables {
    daily_quota_gb = 0
  }
  expect_failures = [var.daily_quota_gb]
}

run "rejects_below_minimum_daily_quota" {
  command = plan

  variables {
    daily_quota_gb = 0.01
  }
  expect_failures = [var.daily_quota_gb]
}

run "accepts_unlimited_and_real_daily_quota" {
  variables {
    daily_quota_gb = 5
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.daily_quota_gb == 5
    error_message = "A positive daily_quota_gb must be passed through unchanged."
  }
}

run "rejects_retention_below_minimum" {
  command = plan

  variables {
    retention_in_days = 7
  }
  expect_failures = [var.retention_in_days]
}

run "rejects_retention_above_maximum" {
  command = plan

  variables {
    retention_in_days = 731
  }
  expect_failures = [var.retention_in_days]
}

run "accepts_compliance_retention" {
  variables {
    retention_in_days = 730
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 730
    error_message = "The maximum supported retention of 730 days must be accepted."
  }
}

# --- per-table plan and retention ---------------------------------------------

run "no_tables_managed_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_log_analytics_workspace_table.this) == 0
    error_message = "With the default tables = {}, no workspace tables may be managed, so upgrading the module leaves existing plans unchanged."
  }
}

run "tables_are_configured_per_entry" {
  command = plan

  variables {
    tables = {
      ContainerLog = {
        plan                    = "Basic"
        total_retention_in_days = 365
      }
      AzureDiagnostics = {
        retention_in_days       = 7
        total_retention_in_days = 1095
      }
    }
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["ContainerLog"].name == "ContainerLog"
    error_message = "The map key must be used as the table name."
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["ContainerLog"].plan == "Basic"
    error_message = "plan must be passed through."
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["ContainerLog"].retention_in_days == null
    error_message = "retention_in_days must stay null when not set."
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["ContainerLog"].total_retention_in_days == 365
    error_message = "total_retention_in_days must be passed through."
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["AzureDiagnostics"].plan == "Analytics"
    error_message = "plan must default to Analytics."
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["AzureDiagnostics"].retention_in_days == 7
    error_message = "retention_in_days must be passed through."
  }

  assert {
    condition     = azurerm_log_analytics_workspace_table.this["AzureDiagnostics"].total_retention_in_days == 1095
    error_message = "A whole-year total_retention_in_days must be accepted."
  }
}

run "rejects_unknown_table_plan" {
  command = plan

  variables {
    tables = {
      ContainerLog = { plan = "Auxiliary" }
    }
  }
  expect_failures = [var.tables]
}

run "rejects_table_retention_out_of_range" {
  command = plan

  variables {
    tables = {
      ContainerLog = { retention_in_days = 3 }
    }
  }
  expect_failures = [var.tables]
}

run "rejects_table_total_retention_not_supported" {
  command = plan

  variables {
    tables = {
      ContainerLog = { total_retention_in_days = 800 }
    }
  }
  expect_failures = [var.tables]
}

run "rejects_retention_on_basic_table" {
  command = plan

  variables {
    tables = {
      ContainerLog = {
        plan              = "Basic"
        retention_in_days = 30
      }
    }
  }
  expect_failures = [var.tables]
}

run "rejects_total_retention_below_retention" {
  command = plan

  variables {
    tables = {
      ContainerLog = {
        retention_in_days       = 90
        total_retention_in_days = 30
      }
    }
  }
  expect_failures = [var.tables]
}
