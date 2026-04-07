defmodule Mix.Tasks.HephaestusEcto.Gen.Migration do
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Ecto
  import Mix.EctoSQL
  import Mix.Generator

  @shortdoc "Generates a workflow_instances migration that delegates to HephaestusEcto.Migration"
  @moduledoc """
  Generates the migration for the `workflow_instances` table.

  The generated migration delegates to `HephaestusEcto.Migration`, keeping
  the table definition in the library and the migration timestamp in your app.

      $ mix hephaestus_ecto.gen.migration

  ## Options

    * `-r`, `--repo` — the repo to generate the migration for
    * `--migrations-path` — custom migrations directory
    * `--no-compile` — skip compilation
    * `--no-deps-check` — skip dependency check

  """

  @aliases [r: :repo]
  @switches [
    repo: [:string, :keep],
    no_compile: :boolean,
    no_deps_check: :boolean,
    migrations_path: :string
  ]

  @impl true
  def run(args) do
    no_umbrella!("hephaestus_ecto.gen.migration")

    repos = parse_repo(args)

    Enum.each(repos, fn repo ->
      case OptionParser.parse!(args, strict: @switches, aliases: @aliases) do
        {opts, []} ->
          ensure_repo(repo, args)
          create_migration(repo, opts)

        {_, _} ->
          Mix.raise(
            "expected hephaestus_ecto.gen.migration to receive no positional arguments, " <>
              "got: #{inspect(Enum.join(args, " "))}"
          )
      end
    end)
  end

  defp create_migration(repo, opts) do
    path = opts[:migrations_path] || Path.join(source_repo_priv(repo), "migrations")
    base_name = "create_workflow_instances.exs"
    file = Path.join(path, "#{timestamp()}_#{base_name}")

    unless File.dir?(path), do: create_directory(path)

    if Path.wildcard(Path.join(path, "*_#{base_name}")) != [] do
      Mix.raise("migration can't be created, there is already a workflow_instances migration.")
    end

    assigns = [
      mod: Module.concat([repo, Migrations, camelize(underscore("create_workflow_instances"))])
    ]

    create_file(file, migration_template(assigns))
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  embed_template(:migration, """
  defmodule <%= inspect @mod %> do
    use Ecto.Migration

    def up, do: HephaestusEcto.Migration.up()
    def down, do: HephaestusEcto.Migration.down()
  end
  """)
end
