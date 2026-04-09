# HephaestusEcto

Ecto/PostgreSQL storage adapter for [Hephaestus](https://github.com/lucas-stellet/hephaestus) workflow engine.

Persists workflow instances across VM restarts using a single `workflow_instances` table with JSONB state and GIN indexing.

Version `0.2.0` adds workflow versioning support, including version-aware migrations,
persisted `workflow_version`, and richer query filters.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:hephaestus_ecto, "~> 0.2.0"}
  ]
end
```

## Setup

### 1. Generate the migration

```bash
mix hephaestus_ecto.gen.migration
mix ecto.migrate
```

This creates the `workflow_instances` table with:

- UUID primary key
- `workflow` and `status` string columns with B-tree indexes
- `workflow_version` integer column (default `1`)
- composite index on `workflow` and `workflow_version`
- `state` JSONB column with GIN index (`jsonb_path_ops`)
- Timestamps

### 1a. Version-aware upgrades

Generated migrations can keep using the original API:

```elixir
def up, do: HephaestusEcto.Migration.up()
def down, do: HephaestusEcto.Migration.down()
```

Or target a specific schema version during staged rollouts:

```elixir
def up, do: HephaestusEcto.Migration.up(version: 2)
def down, do: HephaestusEcto.Migration.down(version: 1)
```

To inspect the applied version at runtime:

```elixir
HephaestusEcto.Migration.migrated_version()
```

### 2. Configure your workflow engine

```elixir
defmodule MyApp.Hephaestus do
  use Hephaestus,
    storage: {HephaestusEcto.Storage, repo: MyApp.Repo},
    runner: Hephaestus.Runtime.Runner.Local
end
```

That's it. Instances are now persisted to PostgreSQL.

## How it works

### Storage adapter

`HephaestusEcto.Storage` implements the `Hephaestus.Runtime.Storage` behaviour:

| Callback | Behavior |
|----------|----------|
| `get/1` | Fetch instance by UUID. Returns `{:ok, instance}` or `{:error, :not_found}` |
| `put/1` | Upsert instance (insert or replace on conflict) |
| `delete/1` | Remove instance. Idempotent — returns `:ok` even if not found |
| `query/1` | Filter by `:status`, `:workflow`, `:workflow_version`, and/or `:workflow_family` |

The adapter uses `persistent_term` to store the Repo reference — no GenServer process overhead. The Repo module is resolved once at startup and looked up in constant time on every call.

### Serialization

Workflow instances contain Elixir-specific types (atoms, MapSets, module references) that can't be stored directly in JSONB. The `Serializer` handles the conversion:

| Elixir type | DB representation |
|-------------|-------------------|
| Atoms | `"Elixir.MyApp.Step"` strings |
| MapSets | Sorted string lists |
| DateTime | ISO 8601 strings |
| Atom map keys | String keys |

All deserialization uses `String.to_existing_atom/1` — no arbitrary atom creation from database values.

`Serializer.to_db/1` returns a 5-tuple:

```elixir
{id, workflow, status, workflow_version, state}
```

`workflow_version` is stored in its own column, while `state` remains JSONB.

### Schema

Single table, simple structure:

```
workflow_instances
├── id        UUID (primary key, from Hephaestus.Core.Instance)
├── workflow  STRING (module name)
├── workflow_version INTEGER (workflow schema version, default 1)
├── status    STRING (pending | running | waiting | completed | failed)
├── state     JSONB (serialized context, steps, history)
└── timestamps
```

## Querying instances

```elixir
# By status
HephaestusEcto.Storage.query(status: :running)

# By workflow
HephaestusEcto.Storage.query(workflow: MyApp.OrderWorkflow)

# Combined
HephaestusEcto.Storage.query(status: :waiting, workflow: MyApp.PaymentWorkflow)

# By exact workflow version
HephaestusEcto.Storage.query(workflow_version: 2)

# By workflow family prefix
HephaestusEcto.Storage.query(workflow_family: "Elixir.MyApp.Workflows.Payment.")
```

For JSONB queries on the `state` field, use the GIN index directly via Ecto:

```elixir
import Ecto.Query

from(i in HephaestusEcto.Schema.Instance,
  where: fragment("state @> ?", ^%{"context" => %{"initial" => %{"order_id" => 123}}})
)
|> MyApp.Repo.all()
```

## Named instances

Multiple storage instances can coexist (e.g., for multi-tenant setups):

```elixir
# Start with a name
HephaestusEcto.Storage.start_link(repo: MyApp.Repo, name: :tenant_a)

# Use the name in calls
HephaestusEcto.Storage.get(:tenant_a, instance_id)
HephaestusEcto.Storage.query(:tenant_a, status: :running)
```

## Requirements

- Elixir ~> 1.19
- PostgreSQL 9.4+ (for JSONB and GIN indexes)
- Ecto SQL ~> 3.10

## License

MIT
