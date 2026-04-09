# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Refactored `HephaestusEcto.Migration` into a versioned migration system following Oban's pattern.
  - Extracted current migration logic into `HephaestusEcto.Migrations.Postgres.V01`.
  - Added orchestrator `HephaestusEcto.Migrations.Postgres` with version tracking via PostgreSQL table comments.
  - `HephaestusEcto.Migration.up/1` and `down/1` now accept `:version` and `:prefix` options.
  - Added `HephaestusEcto.Migration.migrated_version/1` to query the current schema version.

## [0.1.1] - 2026-04-08

### Fixed

- `Serializer.to_db/1` and `Serializer.from_db/4` now serialize/deserialize the `runtime_metadata` field from `Hephaestus.Core.Instance`, preventing data loss on persistence.

### Changed

- Bumped `hephaestus` dependency to `~> 0.1.4` (required for `runtime_metadata` support).

## [0.1.0] - 2026-04-07

### Added

- Ecto schema (`HephaestusEcto.Storage.WorkflowInstance`) for persisting workflow instances in a single `workflow_instances` table with JSONB `state` column and GIN indexing.
- `HephaestusEcto.Serializer` for converting between `Hephaestus.Instance` structs and database records.
- `HephaestusEcto.Storage` implementing the `Hephaestus.Storage` behaviour with full CRUD operations (`save/2`, `get/2`, `delete/2`, `list/1`).
- `HephaestusEcto.Migration` module for creating and dropping the `workflow_instances` table.
- `mix hephaestus_ecto.gen.migration` task for generating migration files into the host application.
- Concurrency test suite validating parallel writes and reads.
- Full `@moduledoc` and `@doc` documentation for all public modules and functions.
- README with setup, usage, and architecture overview.
- Hex package configuration with MIT license.

[0.1.1]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.1.1
[0.1.0]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.1.0
