# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/lucas-stellet/hephaestus_ecto/releases/tag/v0.1.0
