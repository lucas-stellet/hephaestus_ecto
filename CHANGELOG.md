# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `:id` filter for `Storage.query/2` for exact instance ID matches.
- `:status_in` filter for `Storage.query/2` to match instances with any of the given statuses.
- V03 migration to convert `workflow_instances.id` from `uuid` to `varchar(255)`.

### Changed

- BREAKING: `workflow_instances.id` changed from `uuid` to `varchar(255)` in V03 to support the new `key::value` business key format.
- BREAKING: The Ecto schema primary key type changed from `:binary_id` to `:string`.
- Bumped the `hephaestus` dependency from `~> 0.2.0` to `~> 0.3.0`.
- Removed internal `normalize_id/1`; IDs are no longer uppercased on read.

## [0.2.1] - 2026-04-09

### Fixed

- Fixed `migrated_version/1` query for the `public` schema — the previous query concatenated `nspname || '.' || relname` and compared against a value without the `public.` prefix, so it always returned 0 on the default schema. Now uses separate `relname` / `nspname` comparisons, matching the Oban pattern.
- Fixed `record_version/2` to always include the schema prefix using `quoted_prefix` (e.g., `"public".workflow_instances`).
- Made V01 migration fully idempotent: `create` → `create_if_not_exists` for table and indexes. Safe to re-run if table comments are lost.
- Made V02 index creation idempotent: `create` → `create_if_not_exists`.
- Added `quoted_prefix` to opts (via `with_defaults/2`) following Oban's pattern.
- Added migration tests for `migrated_version` on the `public` schema and when comment is NULL.

## [0.2.0] - 2026-04-08

### Added

- Versioned migration system following Oban's pattern (`V01`, `V02`, ...).
- `HephaestusEcto.Migrations.Postgres` orchestrator with version tracking via PostgreSQL table comments.
- `HephaestusEcto.Migration.up/1` and `down/1` now accept `:version` and `:prefix` options.
- `HephaestusEcto.Migration.migrated_version/1` to query the current schema version.
- Migration V02: `workflow_version` integer column on `workflow_instances` (NOT NULL, default 1).
- Composite index on `(workflow, workflow_version)`.
- `workflow_version` field in Ecto schema (`HephaestusEcto.Schema.Instance`).
- `Serializer.to_db/1` returns a 5-tuple including `workflow_version`; `Serializer.from_db/5` restores it.
- `Storage.put/2` persists `workflow_version` (immutable on upsert).
- `Storage.query/2` supports `:workflow_version` (integer equality) and `:workflow_family` (LIKE prefix match) filters.

### Changed

- Refactored `HephaestusEcto.Migration` — extracted original migration logic into the internal versioned migration module under the Postgres migrations namespace.
- Bumped `hephaestus` dependency to `~> 0.2.0`.

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

[0.2.0]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.2.0
[0.2.1]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.2.1
[0.1.1]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.1.1
[0.1.0]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.1.0
[Unreleased]: https://github.com/lucas-stellet/hephaestus_ecto/compare/v0.2.1...HEAD
