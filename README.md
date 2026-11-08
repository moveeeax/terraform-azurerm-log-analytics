# terraform-azurerm-log-analytics

Terraform module that manages an [Azure](https://azure.microsoft.com/) Log
Analytics workspace, the collection and query surface behind Azure Monitor.
It exposes retention, ingestion caps and network access controls, and surfaces
the workspace ID and shared key for wiring up diagnostic settings and agents.

## Usage

```hcl
module "log_analytics" {
  source = "github.com/moveeeax/terraform-azurerm-log-analytics?ref=v1.0.0"

  name                = "prod-law"
  resource_group_name = "prod-rg"
  location            = "eastus"
  retention_in_days   = 90

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version         |
|-----------|-----------------|
| terraform | >= 1.5          |
| azurerm   | >= 5.0, < 6.0   |

azurerm 5.0 removed `internet_ingestion_enabled` and `internet_query_enabled`
from `azurerm_log_analytics_workspace` in favour of
`internet_ingestion_access_type` and `internet_query_access_type`, which only
exist from 5.0.0. One configuration cannot cover both majors, so this version of
the module needs azurerm 5.x; stay on v1 of the module for azurerm 3.x/4.x. CI
validates and tests against 5.0.0 and the latest 5.x release; 6.x is excluded
until it has been tested.

Running the test suite additionally needs Terraform >= 1.7 for `mock_provider`.
That is a test-only requirement and deliberately not reflected in
`required_version`, so consumers on 1.5 are unaffected.

## Defaults worth knowing about

These are the settings that cost money or quietly break collection, and why the
module defaults land where they do.

- **`retention_in_days` defaults to `30`.** That matches Azure's own default and
  sits inside the retention included with `PerGB2018`, so raising it is a
  deliberate cost decision rather than something the module makes for you. The
  module accepts 30–730 and rejects anything outside that range up front —
  azurerm 3.0.x still accepts `7` (the retired Free tier's fixed retention)
  while 4.x rejects it, so the module pins one contract across the whole
  supported provider range.

- **`daily_quota_gb` defaults to `-1`, which means *unlimited*.** Any other
  value is a hard cap: once the workspace ingests that much in a day it stops
  collecting until the next reset. Azure and the azurerm provider both accept
  `daily_quota_gb = 0`, which caps ingestion at zero and silently stops all data
  collection with no error from Terraform. The module rejects it — the value
  must be `-1` or at least `0.023` GB, Azure's minimum real cap.

- **`sku` defaults to `PerGB2018`.** The azurerm provider's schema still accepts
  the retired `Free`, `Standard` and `Premium` tiers, so they pass
  `terraform validate` and only fail at apply. The module rejects them and
  accepts `PerGB2018`, `CapacityReservation`, `LACluster`, plus the legacy
  `PerNode`/`Standalone`/`Unlimited` tiers that remain selectable on
  subscriptions already entitled to them.

- **`internet_ingestion_access_type` and `internet_query_access_type` default to
  `Enabled`**, matching Azure's default. Setting either to `Disabled` requires an
  Azure Monitor Private Link Scope covering every agent, diagnostic setting and
  query client (including the Azure portal); flipping them without that
  infrastructure stops ingestion or breaks queries and alert rules. They are
  exposed so you can lock the workspace down, but the module will not do it
  behind your back.

- **`reservation_capacity_in_gb_per_day` is only sent when `sku` is
  `CapacityReservation`** and is `null` otherwise, so the default of `100` never
  leaks onto a pay-as-you-go workspace.

## Per-table plan and retention

The workspace-level `retention_in_days` applies to every table. High-volume
tables such as `ContainerLog` or `AzureDiagnostics` usually dominate the bill,
so `tables` lets you override them one by one, keyed by table name:

```hcl
  tables = {
    ContainerLog = {
      plan                    = "Basic"
      total_retention_in_days = 365
    }
    AzureDiagnostics = {
      retention_in_days       = 30
      total_retention_in_days = 1095
    }
  }
```

- `plan` is `Analytics` (the default for an entry) or `Basic`. Basic tables
  ingest at a lower price but support fewer query features and bill queries
  by data scanned; check that nothing alerts on a table before moving it.
- `retention_in_days` is interactive retention, 4-730 days. It cannot be set on
  a Basic table, whose interactive retention Azure fixes at 30 days.
- `total_retention_in_days` adds long-term (archive) retention on top: 4-730
  days, or 1095, 1460, ..., 4383 for 3 to 12 years. It must be at least
  `retention_in_days`.
- Fields left `null` keep Azure's values. Tables not listed are not managed.

The default is `{}`, so the module manages no tables unless you ask. The module
rejects the combinations above at plan time; the provider's schema validation
alone lets a Basic table with `retention_in_days` through `validate`.

## Testing

```sh
terraform init -backend=false
terraform test
```

The suite in [`tests/`](tests) runs against a mocked azurerm provider, so it
needs no Azure credentials and no network.

## Inputs

| Name                                 | Description                                                          | Type          | Default        | Required |
|--------------------------------------|----------------------------------------------------------------------|---------------|----------------|:--------:|
| `name`                               | Name of the Log Analytics workspace.                                 | `string`      | n/a            |   yes    |
| `resource_group_name`                | Name of the resource group in which to create the workspace.         | `string`      | n/a            |   yes    |
| `location`                           | Azure region in which to create the workspace.                       | `string`      | n/a            |   yes    |
| `sku`                                | SKU of the workspace. Retired tiers (Free/Standard/Premium) are rejected. | `string`      | `"PerGB2018"`  |    no    |
| `retention_in_days`                  | Days ingested data is retained. Must be between 30 and 730.          | `number`      | `30`           |    no    |
| `daily_quota_gb`                     | Daily ingestion cap in GB. `-1` means unlimited; `0` is rejected.    | `number`      | `-1`           |    no    |
| `internet_ingestion_access_type`     | Public ingestion access: `Enabled`, `Disabled` or `SecuredByPerimeter`. `null` means `Enabled`. | `string` | `null` | no |
| `internet_query_access_type`         | Public query access: `Enabled`, `Disabled` or `SecuredByPerimeter`. `null` means `Enabled`. | `string` | `null` | no |
| `internet_ingestion_enabled`         | Deprecated, use `internet_ingestion_access_type` (`true` = `Enabled`, `false` = `Disabled`). | `bool` | `null` | no |
| `internet_query_enabled`             | Deprecated, use `internet_query_access_type` (`true` = `Enabled`, `false` = `Disabled`). | `bool` | `null` | no |
| `reservation_capacity_in_gb_per_day` | Reserved daily capacity in GB (CapacityReservation SKU only).        | `number`      | `100`          |    no    |
| `tags`                               | Map of tags applied to the workspace.                                | `map(string)` | `{}`           |    no    |
| `tables`                             | Per-table `plan`, `retention_in_days` and `total_retention_in_days`, keyed by table name. See [Per-table plan and retention](#per-table-plan-and-retention). | `map(object)` | `{}` | no |

## Outputs

| Name                 | Description                                            |
|----------------------|--------------------------------------------------------|
| `id`                 | ID of the Log Analytics workspace.                     |
| `name`               | Name of the Log Analytics workspace.                   |
| `workspace_id`       | Customer ID (workspace ID) of the workspace.           |
| `primary_shared_key` | Primary shared key used by agents (sensitive).         |
| `table_ids`          | Map of table name to ID for tables managed via `tables`. |

## License

[MIT](LICENSE)
