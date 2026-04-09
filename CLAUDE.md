# CLAUDE.md

## Changelog

- Ao criar novas versões, atualizar o `CHANGELOG.md` seguindo o formato [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
- O `CHANGELOG.md` está registrado no HexDocs (via `docs: extras` no `mix.exs`) e no pacote Hex (via `package: files`).

## Commands

- `mix test` — runs tests (auto-creates and migrates the test DB)
- `mix docs` — generates hexdocs locally
- `mix compile --warnings-as-errors` — verify no warnings

## Conventions

- Commit messages follow conventional commits: `feat:`, `fix:`, `chore:`, `docs:`
- Elixir ~> 1.19

## Versioned Migrations

This library ships versioned database migrations for the `workflow_instances` table. The migration system follows the [Oban migration pattern](https://hexdocs.pm/oban/Oban.Migration.html).

### Architecture

```
lib/hephaestus_ecto/migration.ex           — Public API (up/1, down/1, migrated_version/1)
lib/hephaestus_ecto/migrations/postgres.ex  — Orchestrator (version tracking, routing)
lib/hephaestus_ecto/migrations/postgres/
  v01.ex — Creates workflow_instances table with GIN index
  v02.ex — Adds workflow_version column + composite index
```

### How version tracking works

- The applied schema version is stored as a **PostgreSQL table comment** on the `workflow_instances` table.
- `migrated_version/1` reads this comment via a `pg_class` + `pg_namespace` JOIN query.
- `up/1` compares the current version to the target and runs only missing versions.
- `record_version/2` writes the new version as a comment after applying migrations.

### Key design decisions

1. **Query uses separate `relname` / `nspname` comparisons** (not concatenation). This correctly handles both `public` and custom schema prefixes. Follows the exact pattern from Oban's `Oban.Migrations.Postgres.migrated_version/1`.

2. **All DDL operations are idempotent.** V01 uses `create_if_not_exists` for table and indexes. V02 uses `add_if_not_exists` for columns and `create_if_not_exists` for indexes. This means re-running all migrations is safe even if the table comment is lost (e.g., after a backup restore).

3. **`@disable_ddl_transaction` is NOT needed.** The `migrated_version` query is safe inside DDL transactions because it uses a `LEFT JOIN` on `pg_class` (returns no rows when table doesn't exist, doesn't throw).

4. **`quoted_prefix`** is `inspect(prefix)` (e.g., `"public"`). Used in `COMMENT ON TABLE` and `CREATE INDEX` DDL statements. **`escaped_prefix`** has single quotes escaped for use in SQL string literals (the `WHERE nspname = '...'` clause).

### Adding a new migration version

1. Create `lib/hephaestus_ecto/migrations/postgres/v03.ex` accepting `%{prefix: prefix}` in `up/1` and `down/1`.
2. Use idempotent operations: `add_if_not_exists`, `create_if_not_exists`, `drop_if_exists`, `remove_if_exists`.
3. Bump `@current_version` from `2` to `3` in `lib/hephaestus_ecto/migrations/postgres.ex`.
4. Add tests in `test/hephaestus_ecto/migrations/postgres_test.exs`.
5. Update `CHANGELOG.md`.

### Caveats for host applications

- **Do not manually alter the `workflow_instances` table.** Schema changes should come from the library's versioned migrations.
- **Lost comments**: if a backup strips table comments, `up()` re-runs all versions safely (idempotent DDL). Fix manually: `COMMENT ON TABLE "public".workflow_instances IS '2'`.
- **Ecto before Oban**: `hephaestus_oban`'s `hephaestus_step_results` table has a FK to `workflow_instances`, so the ecto migration must run first.
