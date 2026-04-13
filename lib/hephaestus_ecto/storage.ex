defmodule HephaestusEcto.Storage do
  @moduledoc """
  Ecto/PostgreSQL storage adapter implementing `Hephaestus.Runtime.Storage`.

  Uses a single `workflow_instances` table with JSONB state. The Repo module
  is stored in `persistent_term` at startup — no GenServer process overhead.

  Workflow versioning is persisted alongside each instance. Query filters support both exact
  workflow version matches and workflow-family prefix matching for versioned workflow modules.

  ## Usage

  Configure as the storage adapter in your Hephaestus entry module:

      defmodule MyApp.Hephaestus do
        use Hephaestus,
          storage: {HephaestusEcto.Storage, repo: MyApp.Repo}
      end

  ## Named instances

  Multiple storage instances can coexist by passing a `:name` option:

      HephaestusEcto.Storage.start_link(repo: MyApp.Repo, name: :tenant_a)
      HephaestusEcto.Storage.get(:tenant_a, instance_id)

  The arity-1 callbacks (behaviour interface) use `__MODULE__` as the default name.
  The arity-2 versions accept an explicit name as the first argument.

  ## Query filters

  `query/1` and `query/2` support these filters:

    * `:id` — match an exact workflow instance ID
    * `:status` — match a specific runtime status
    * `:status_in` — match any runtime status in a list
    * `:workflow` — match an exact workflow module
    * `:workflow_version` — match an exact integer workflow version
    * `:workflow_family` — prefix match on the stored workflow module name

  Examples:

      HephaestusEcto.Storage.query(id: "invoiceid::abc123")
      HephaestusEcto.Storage.query(status: :running)
      HephaestusEcto.Storage.query(status_in: [:pending, :running, :waiting])
      HephaestusEcto.Storage.query(workflow: MyApp.Workflows.Invoice.V2)
      HephaestusEcto.Storage.query(workflow_version: 2)
      HephaestusEcto.Storage.query(workflow_family: "Elixir.MyApp.Workflows.Invoice.")
  """

  import Ecto.Query

  alias Hephaestus.Core.Instance
  alias Hephaestus.Runtime.Storage, as: StorageBehaviour
  alias HephaestusEcto.Serializer
  alias HephaestusEcto.Schema.Instance, as: InstanceRecord

  @behaviour StorageBehaviour

  @type name :: term()
  @type filters :: keyword()

  @repo_key_parts {__MODULE__, :repo}

  @doc """
  Returns a child spec for supervision tree integration.

  ## Options

    * `:repo` (required) — the Ecto.Repo module to use
    * `:name` — a name for this storage instance (defaults to `#{inspect(__MODULE__)}`)

  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.get(opts, :name, __MODULE__)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @doc """
  Stores the Repo reference in `persistent_term` and returns `:ignore`.

  No process is started — this only registers the Repo for later lookup.

  ## Options

    * `:repo` (required) — the Ecto.Repo module
    * `:name` — storage instance name (defaults to `#{inspect(__MODULE__)}`)

  """
  @spec start_link(keyword()) :: :ignore
  def start_link(opts \\ []) do
    repo = Keyword.fetch!(opts, :repo)
    name = Keyword.get(opts, :name, __MODULE__)

    :persistent_term.put(repo_key(name), repo)
    :ignore
  end

  @doc """
  Retrieves a workflow instance by ID.

  Returns `{:ok, instance}` if found, `{:error, :not_found}` otherwise.
  """
  @impl StorageBehaviour
  @spec get(String.t()) :: {:ok, Instance.t()} | {:error, :not_found}
  def get(id), do: get(__MODULE__, id)

  @doc """
  Retrieves a workflow instance by ID using a named storage.
  """
  @spec get(name(), String.t()) :: {:ok, Instance.t()} | {:error, :not_found}
  def get(name, id) when is_binary(id) do
    case fetch_record(name, id) do
      nil -> {:error, :not_found}
      record -> {:ok, record_to_instance(record)}
    end
  end

  @doc """
  Persists a workflow instance.

  Uses upsert semantics — inserts a new record or replaces `workflow`, `status`,
  `state`, and `updated_at` on conflict. `workflow_version` is inserted on first
  write and left unchanged on conflict so historical rows keep their original version.
  """
  @impl StorageBehaviour
  @spec put(Instance.t()) :: :ok
  def put(instance), do: put(__MODULE__, instance)

  @doc """
  Persists a workflow instance using a named storage.

  `workflow_version` is serialized from the `%Hephaestus.Core.Instance{}` and stored in the
  `workflow_instances.workflow_version` column.
  """
  @spec put(name(), Instance.t()) :: :ok
  def put(name, %Instance{} = instance) do
    {id, workflow, status, workflow_version, state} = Serializer.to_db(instance)

    attrs = %{
      id: id,
      workflow: workflow,
      status: status,
      workflow_version: workflow_version,
      state: state
    }

    %InstanceRecord{}
    |> InstanceRecord.changeset(attrs)
    |> repo(name).insert(
      on_conflict: {:replace, [:workflow, :status, :state, :updated_at]},
      conflict_target: :id
    )

    :ok
  end

  @doc """
  Deletes a workflow instance by ID.

  Idempotent — returns `:ok` even if the instance does not exist.
  """
  @impl StorageBehaviour
  @spec delete(String.t()) :: :ok
  def delete(id), do: delete(__MODULE__, id)

  @doc """
  Deletes a workflow instance by ID using a named storage.
  """
  @spec delete(name(), String.t()) :: :ok
  def delete(name, id) when is_binary(id) do
    case fetch_record(name, id) do
      nil ->
        :ok

      record ->
        {:ok, _record} = repo(name).delete(record)
        :ok
    end
  end

  @doc """
  Queries workflow instances by filters.

  ## Supported filters

    * `:id` — filter by exact instance ID
    * `:status` — filter by instance status (e.g., `:running`, `:waiting`)
    * `:status_in` — filter by multiple instance statuses
    * `:workflow` — filter by workflow module
    * `:workflow_version` — filter by exact workflow version (integer)
    * `:workflow_family` — filter by workflow module prefix (LIKE match)

  ## Examples

      HephaestusEcto.Storage.query(status: :running)
      HephaestusEcto.Storage.query(id: "orderid::123")
      HephaestusEcto.Storage.query(status_in: [:running, :waiting])
      HephaestusEcto.Storage.query(status: :waiting, workflow: MyApp.OrderWorkflow)
      HephaestusEcto.Storage.query(workflow_version: 2)
      HephaestusEcto.Storage.query(workflow_family: "Elixir.MyApp.Workflows.Order.")

  """
  @impl StorageBehaviour
  @spec query(filters()) :: [Instance.t()]
  def query(filters), do: query(__MODULE__, filters)

  @doc """
  Queries workflow instances by filters using a named storage.
  """
  @spec query(name(), filters()) :: [Instance.t()]
  def query(name, filters) when is_list(filters) do
    filters
    |> Enum.reduce(InstanceRecord, fn
      {:id, id}, query when is_binary(id) ->
        where(query, [instance], instance.id == ^id)

      {:status, status}, query ->
        where(query, [instance], instance.status == ^Atom.to_string(status))

      {:status_in, statuses}, query when is_list(statuses) ->
        string_statuses = Enum.map(statuses, &Atom.to_string/1)
        where(query, [instance], instance.status in ^string_statuses)

      {:workflow, workflow}, query ->
        where(query, [instance], instance.workflow == ^Atom.to_string(workflow))

      {:workflow_version, version}, query when is_integer(version) ->
        where(query, [instance], instance.workflow_version == ^version)

      {:workflow_family, prefix}, query when is_binary(prefix) ->
        escaped_prefix =
          prefix
          |> String.replace("%", "\\%")
          |> String.replace("_", "\\_")

        like_pattern = escaped_prefix <> "%"
        where(query, [instance], like(instance.workflow, ^like_pattern))

      {_key, _value}, query ->
        query
    end)
    |> repo(name).all()
    |> Enum.map(&record_to_instance/1)
  end

  defp record_to_instance(%InstanceRecord{} = record) do
    Serializer.from_db(
      record.id,
      record.workflow,
      record.status,
      record.workflow_version,
      record.state
    )
  end

  defp fetch_record(name, id) do
    repo(name).get(InstanceRecord, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp repo(name) do
    :persistent_term.get(repo_key(name))
  end

  defp repo_key(name), do: {@repo_key_parts, name}
end
