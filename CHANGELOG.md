# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-11-08

### Added

- `tables` input setting the plan (`Analytics` or `Basic`), interactive
  retention and total (archive) retention per table through
  `azurerm_log_analytics_workspace_table`, keyed by table name. New `table_ids`
  output. Defaults to `{}`, so existing workspaces plan unchanged.
- Plan-time checks mirroring the provider: unknown plans, retention outside
  4-730 days, total retention that is neither 4-730 days nor a supported year
  value, `retention_in_days` on a Basic table, and total retention below
  interactive retention are rejected.

## [1.1.0] - 2026-11-05

### Changed

- Require azurerm `>= 5.0, < 6.0`. azurerm 5.0 removed
  `internet_ingestion_enabled` and `internet_query_enabled` from the workspace;
  new `internet_ingestion_access_type` and `internet_query_access_type` inputs
  replace them, and the boolean inputs remain as deprecated aliases. Stay on
  1.0.0 for azurerm 3.x/4.x.
- CI: validate and test the 5.0.0 floor, bump actions to their current majors,
  pin tool versions, add the azurerm tflint ruleset, restrict the workflow token
  to `contents: read`, add Dependabot.

## [1.0.0] - 2026-07-26

Initial release with plan-time rejection of retired SKUs, a zero daily quota
and retention outside 30-730 days (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-azurerm-log-analytics/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/moveeeax/terraform-azurerm-log-analytics/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/moveeeax/terraform-azurerm-log-analytics/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-azurerm-log-analytics/releases/tag/v1.0.0
