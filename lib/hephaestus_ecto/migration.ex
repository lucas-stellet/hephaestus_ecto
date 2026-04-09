defmodule HephaestusEcto.Migration do
  @moduledoc """
  Migrations create and modify the database tables HephaestusEcto needs to function.

  ## Usage

  To use migrations in your application you'll need to generate an `Ecto.Migration` that wraps
  calls to `HephaestusEcto.Migration`:

      mix hephaestus_ecto.gen.migration

  Or manually create a migration:

      defmodule MyApp.Repo.Migrations.AddHephaestus do
        use Ecto.Migration

        def up, do: HephaestusEcto.Migration.up()
        def down, do: HephaestusEcto.Migration.down()
      end

  ## Isolation with Prefixes

  HephaestusEcto supports namespacing through PostgreSQL schemas (prefixes):

      def up, do: HephaestusEcto.Migration.up(prefix: "private")
      def down, do: HephaestusEcto.Migration.down(prefix: "private")

  ## Versioning

  Migrations are versioned and tracked via PostgreSQL table comments. Running `up/1`
  will only apply migrations that haven't been run yet.

  To upgrade to a specific version:

      def up, do: HephaestusEcto.Migration.up(version: 1)
      def down, do: HephaestusEcto.Migration.down(version: 1)
  """

  use Ecto.Migration

  @doc """
  Run the `up` changes for all migrations between the initial version and the current version.

  ## Options

    * `:version` — target version (defaults to latest)
    * `:prefix` — PostgreSQL schema prefix (defaults to `"public"`)
  """
  def up(opts \\ []) when is_list(opts) do
    HephaestusEcto.Migrations.Postgres.up(opts)
  end

  @doc """
  Run the `down` changes from the current version to the target version.

  ## Options

    * `:version` — target version to migrate down to (defaults to initial)
    * `:prefix` — PostgreSQL schema prefix (defaults to `"public"`)
  """
  def down(opts \\ []) when is_list(opts) do
    HephaestusEcto.Migrations.Postgres.down(opts)
  end

  @doc """
  Check the latest version the database is migrated to.

  ## Options

    * `:prefix` — PostgreSQL schema prefix (defaults to `"public"`)
  """
  def migrated_version(opts \\ []) when is_list(opts) do
    HephaestusEcto.Migrations.Postgres.migrated_version(opts)
  end
end
