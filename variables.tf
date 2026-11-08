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

variable "internet_ingestion_access_type" {
  description = <<-EOT
    Public network access for log ingestion: Enabled, Disabled or
    SecuredByPerimeter. Null (the default) means Enabled, matching Azure's
    default. Disabled requires an Azure Monitor Private Link Scope covering
    every agent and diagnostic setting that writes here, otherwise ingestion
    stops.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.internet_ingestion_access_type == null || contains(["Enabled", "Disabled", "SecuredByPerimeter"], coalesce(var.internet_ingestion_access_type, "Enabled"))
    error_message = "internet_ingestion_access_type must be one of Enabled, Disabled or SecuredByPerimeter."
  }
}

variable "internet_query_access_type" {
  description = <<-EOT
    Public network access for queries: Enabled, Disabled or
    SecuredByPerimeter. Null (the default) means Enabled, matching Azure's
    default. Disabled requires an Azure Monitor Private Link Scope for every
    query client, including the Azure portal, otherwise queries and alert
    rules stop working.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.internet_query_access_type == null || contains(["Enabled", "Disabled", "SecuredByPerimeter"], coalesce(var.internet_query_access_type, "Enabled"))
    error_message = "internet_query_access_type must be one of Enabled, Disabled or SecuredByPerimeter."
  }
}

variable "internet_ingestion_enabled" {
  description = "Deprecated: use internet_ingestion_access_type. true maps to Enabled, false to Disabled."
  type        = bool
  default     = null
}

variable "internet_query_enabled" {
  description = "Deprecated: use internet_query_access_type. true maps to Enabled, false to Disabled."
  type        = bool
  default     = null
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

variable "tables" {
  description = <<-EOT
    Per-table overrides, keyed by table name (for example ContainerLog or
    AzureDiagnostics). plan is Analytics (the default) or Basic, the cheaper
    ingestion tier with limited query features. retention_in_days is the
    interactive retention (4 to 730 days) and cannot be set on Basic tables,
    whose interactive retention Azure fixes at 30 days. total_retention_in_days
    adds long-term (archive) retention: 4 to 730 days, or a whole number of
    years up to 12 (1095, 1460, ..., 4383). Null fields fall back to Azure's
    defaults. Empty (the default) manages no tables.
  EOT
  type = map(object({
    plan                    = optional(string, "Analytics")
    retention_in_days       = optional(number)
    total_retention_in_days = optional(number)
  }))
  default = {}

  validation {
    condition     = alltrue([for t in values(var.tables) : contains(["Analytics", "Basic"], t.plan)])
    error_message = "tables[*].plan must be Analytics or Basic."
  }

  validation {
    condition = alltrue([
      for t in values(var.tables) :
      t.retention_in_days == null || (
        try(t.retention_in_days >= 4 && t.retention_in_days <= 730 && floor(t.retention_in_days) == t.retention_in_days, false)
      )
    ])
    error_message = "tables[*].retention_in_days must be a whole number between 4 and 730."
  }

  validation {
    # Mirrors the provider's own check: 4-730 days, or one of its fixed
    # year values from 3 to 12 years.
    condition = alltrue([
      for t in values(var.tables) :
      t.total_retention_in_days == null || (
        try(
          (t.total_retention_in_days >= 4 && t.total_retention_in_days <= 730 && floor(t.total_retention_in_days) == t.total_retention_in_days) ||
          contains([1095, 1460, 1826, 2191, 2556, 2922, 3288, 3653, 4018, 4383], t.total_retention_in_days),
          false,
        )
      )
    ])
    error_message = "tables[*].total_retention_in_days must be a whole number between 4 and 730, or one of 1095, 1460, 1826, 2191, 2556, 2922, 3288, 3653, 4018, 4383 (3 to 12 years)."
  }

  validation {
    # The provider enforces this inside the resource rather than in its schema,
    # so `validate` accepts it; reject it at the module boundary instead.
    condition     = alltrue([for t in values(var.tables) : !(t.plan == "Basic" && t.retention_in_days != null)])
    error_message = "tables[*].retention_in_days cannot be set when plan is Basic; Azure fixes the interactive retention of Basic tables at 30 days. Use total_retention_in_days for longer retention."
  }

  validation {
    condition = alltrue([
      for t in values(var.tables) :
      t.retention_in_days == null || t.total_retention_in_days == null || try(t.total_retention_in_days >= t.retention_in_days, false)
    ])
    error_message = "tables[*].total_retention_in_days must be greater than or equal to retention_in_days."
  }
}
