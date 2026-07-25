# terraform-azurerm-log-analytics

Terraform module that manages an [Azure](https://azure.microsoft.com/) Log
Analytics workspace, the collection and query surface behind Azure Monitor.
It exposes retention, ingestion caps and network access controls, and surfaces
the workspace ID and shared key for wiring up diagnostic settings and agents.

## Usage

```hcl
module "log_analytics" {
  source = "github.com/moveeeax/terraform-azurerm-log-analytics"

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
| azurerm   | >= 3.0, < 5.0   |

The `>= 3.0` floor is the real one: every argument this module sets on
`azurerm_log_analytics_workspace` — including `reservation_capacity_in_gb_per_day`
— is already present in the resource schema at azurerm 3.0.0. The `< 5.0` ceiling
keeps an untested major from being pulled in silently; 4.x is validated.

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

- **`internet_ingestion_enabled` and `internet_query_enabled` default to
  `true`**, matching Azure's default. Setting either to `false` requires an
  Azure Monitor Private Link Scope covering every agent, diagnostic setting and
  query client (including the Azure portal); flipping them without that
  infrastructure stops ingestion or breaks queries and alert rules. They are
  exposed so you can lock the workspace down, but the module will not do it
  behind your back.

- **`reservation_capacity_in_gb_per_day` is only sent when `sku` is
  `CapacityReservation`** and is `null` otherwise, so the default of `100` never
  leaks onto a pay-as-you-go workspace.

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
| `internet_ingestion_enabled`         | Whether ingestion over the public internet is permitted.             | `bool`        | `true`         |    no    |
| `internet_query_enabled`             | Whether querying over the public internet is permitted.              | `bool`        | `true`         |    no    |
| `reservation_capacity_in_gb_per_day` | Reserved daily capacity in GB (CapacityReservation SKU only).        | `number`      | `100`          |    no    |
| `tags`                               | Map of tags applied to the workspace.                                | `map(string)` | `{}`           |    no    |

## Outputs

| Name                 | Description                                            |
|----------------------|--------------------------------------------------------|
| `id`                 | ID of the Log Analytics workspace.                     |
| `name`               | Name of the Log Analytics workspace.                   |
| `workspace_id`       | Customer ID (workspace ID) of the workspace.           |
| `primary_shared_key` | Primary shared key used by agents (sensitive).         |

## License

[MIT](LICENSE)
