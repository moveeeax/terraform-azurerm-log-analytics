variable "name" {
  description = "Name of the Log Analytics workspace."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the workspace."
  type        = string
}

variable "location" {
  description = "Azure region in which to create the workspace."
  type        = string
}

variable "sku" {
  description = <<-EOT
    SKU of the workspace. Use PerGB2018 (the modern pay-as-you-go tier),
    CapacityReservation, or LACluster for a workspace linked to a dedicated
    cluster. PerNode, Standalone and Unlimited are legacy tiers that only
    remain selectable on subscriptions already entitled to them.
  EOT
  type        = string
  default     = "PerGB2018"

  validation {
    # The azurerm provider still accepts the retired Free/Standard/Premium
    # tiers in its own schema validation, so they pass `terraform validate`
    # and only blow up at apply time. Reject them here instead.
    condition = contains([
      "PerGB2018",
      "CapacityReservation",
      "LACluster",
      "PerNode",
      "Standalone",
      "Unlimited",
    ], var.sku)
    error_message = "sku must be one of PerGB2018, CapacityReservation, LACluster, or the legacy tiers PerNode/Standalone/Unlimited. The Free, Standard and Premium tiers are retired by Azure and fail at apply; use PerGB2018 instead."
  }
}

variable "retention_in_days" {
  description = <<-EOT
    Number of days ingested data is retained, between 30 and 730. The default
    of 30 matches Azure's own default and stays inside the retention included
    with PerGB2018, so raising it is a deliberate cost decision.
  EOT
  type        = number
  default     = 30

  validation {
    # azurerm 3.0.x still accepts 7 (the retired Free tier's fixed retention)
    # while 4.x rejects it, so pin the contract at the module boundary and
    # keep it identical across the whole supported provider range.
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = <<-EOT
    Daily ingestion cap in GB. -1 means unlimited (the default). Any other
    value caps ingestion, and once the cap is hit the workspace stops
    collecting data for the rest of the day.
  EOT
  type        = number
  default     = -1

  validation {
    # Both azurerm 3.x and 4.x happily accept daily_quota_gb = 0, which sets
    # the cap to zero and silently stops all ingestion with no error anywhere.
    # -1 is the sentinel for "unlimited"; 0.023 GB is Azure's minimum real cap.
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb >= 0.023
    error_message = "daily_quota_gb must be -1 (unlimited) or at least 0.023 GB. A value of 0 is accepted by Azure but caps ingestion at zero, which silently stops all data collection."
  }
}

variable "internet_ingestion_enabled" {
  description = <<-EOT
    Whether log ingestion over the public internet is permitted. Defaults to
    true, matching Azure's default. Setting it to false requires an Azure
    Monitor Private Link Scope covering every agent and diagnostic setting
    that writes here, otherwise ingestion stops.
  EOT
  type        = bool
  default     = true
}

variable "internet_query_enabled" {
  description = <<-EOT
    Whether querying the workspace over the public internet is permitted.
    Defaults to true, matching Azure's default. Setting it to false requires
    an Azure Monitor Private Link Scope for every query client, including the
    Azure portal, otherwise queries and alert rules stop working.
  EOT
  type        = bool
  default     = true
}

variable "reservation_capacity_in_gb_per_day" {
  description = "Reserved daily capacity in GB, only used when sku is CapacityReservation."
  type        = number
  default     = 100
}

variable "tags" {
  description = "Map of tags applied to the workspace."
  type        = map(string)
  default     = {}
}
