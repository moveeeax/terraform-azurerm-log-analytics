# Test-only requirement: `mock_provider` needs Terraform >= 1.7.
# The module itself still supports >= 1.5 (see versions.tf) — do not raise
# required_version to satisfy these tests.
#
# Run with: terraform init -backend=false && terraform test

mock_provider "azurerm" {}

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
    condition     = azurerm_log_analytics_workspace.this.internet_ingestion_enabled == true
    error_message = "Default internet_ingestion_enabled must be true; disabling it without a Private Link Scope stops ingestion."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.internet_query_enabled == true
    error_message = "Default internet_query_enabled must be true; disabling it without a Private Link Scope breaks queries and alerts."
  }
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
