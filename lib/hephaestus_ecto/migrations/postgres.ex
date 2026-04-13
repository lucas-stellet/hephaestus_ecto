defmodule HephaestusEcto.Migrations.Postgres do
  @moduledoc """
  PostgreSQL migration orchestrator for `HephaestusEcto`.

  This module coordinates versioned migration modules (`V01`, `V02`, and so on) and keeps the
  applied schema version in a comment on the `workflow_instances` table. The public
  `HephaestusEcto.Migration` module delegates here for all `up/1`, `down/1`, and
  `migrated_version/1` calls.

  The orchestrator pattern keeps each schema change isolated in its own module while still
  exposing a stable, version-aware API to host applications.
  """

  use Ecto.Migration

  @initial_version 1
  @current_version 3
  @default_prefix "public"

  @valid_prefix ~r/^[a-z_][a-z0-9_]*$/

  def initial_version, do: @initial_version

  def current_version, do: @current_version

  def up(opts) do
    opts = with_defaults(opts, @current_version)
    initial = migrated_version(opts)

    cond do
      initial == 0 ->
        change(@initial_version..opts.version, :up, opts)

      initial < opts.version ->
        change((initial + 1)..opts.version, :up, opts)

      true ->
        :ok
    end
  end

  def down(opts) do
    opts = with_defaults(opts, @initial_version)
    initial = max(migrated_version(opts), @initial_version)

    if initial >= opts.version do
      change(initial..(opts.version + 1)//-1, :down, opts)
    else
      :ok
    end
  end

  def migrated_version(opts) do
    opts = with_defaults(opts, @initial_version)

    repo = Map.get_lazy(opts, :repo, fn -> repo() end)
    escaped_prefix = Map.fetch!(opts, :escaped_prefix)

    query = """
    SELECT pg_catalog.obj_description(pg_class.oid, 'pg_class')
    FROM pg_class
    LEFT JOIN pg_namespace ON pg_namespace.oid = pg_class.relnamespace
    WHERE pg_class.relname = 'workflow_instances'
    AND pg_namespace.nspname = '#{escaped_prefix}'
    """

    case repo.query(query, [], log: false) do
      {:ok, %{rows: [[version]]}} when is_binary(version) -> String.to_integer(version)
      _ -> 0
    end
  end

  defp change(range, direction, opts) do
    for index <- range do
      pad_idx = String.pad_leading(to_string(index), 2, "0")

      [__MODULE__, "V#{pad_idx}"]
      |> Module.concat()
      |> apply(direction, [opts])
    end

    case direction do
      :up -> record_version(opts, Enum.max(range))
      :down -> record_version(opts, Enum.min(range) - 1)
    end
  end

  defp record_version(_opts, 0), do: :ok

  defp record_version(%{quoted_prefix: quoted}, version) do
    execute("COMMENT ON TABLE #{quoted}.workflow_instances IS '#{version}'")
  end

  def qualified_table(prefix, table) do
    if prefix == @default_prefix, do: table, else: "#{prefix}.#{table}"
  end

  defp with_defaults(opts, version) do
    opts = Enum.into(opts, %{prefix: @default_prefix, version: version})

    validate_prefix!(opts.prefix)

    opts
    |> Map.put(:quoted_prefix, inspect(opts.prefix))
    |> Map.put(:escaped_prefix, String.replace(opts.prefix, "'", "\\'"))
  end

  defp validate_prefix!(prefix) do
    unless Regex.match?(@valid_prefix, prefix) do
      raise ArgumentError,
            "invalid prefix #{inspect(prefix)} — must match #{inspect(@valid_prefix)}"
    end
  end
end
