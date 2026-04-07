defmodule HephaestusEcto.Storage do
  @moduledoc """
  Ecto/PostgreSQL storage adapter implementing `Hephaestus.Runtime.Storage`.

  Uses a single `workflow_instances` table with JSONB state. The Repo module
  is stored in `persistent_term` at startup — no GenServer process overhead.

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
  `state`, and `updated_at` on conflict.
  """
  @impl StorageBehaviour
  @spec put(Instance.t()) :: :ok
  def put(instance), do: put(__MODULE__, instance)

  @doc """
  Persists a workflow instance using a named storage.
  """
  @spec put(name(), Instance.t()) :: :ok
  def put(name, %Instance{} = instance) do
    {id, workflow, status, state} = Serializer.to_db(instance)

    attrs = %{id: id, workflow: workflow, status: status, state: state}

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

    * `:status` — filter by instance status (e.g., `:running`, `:waiting`)
    * `:workflow` — filter by workflow module

  ## Examples

      Storage.query(status: :running)
      Storage.query(status: :waiting, workflow: MyApp.OrderWorkflow)

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
      {:status, status}, query ->
        where(query, [instance], instance.status == ^Atom.to_string(status))

      {:workflow, workflow}, query ->
        where(query, [instance], instance.workflow == ^Atom.to_string(workflow))

      {_key, _value}, query ->
        query
    end)
    |> repo(name).all()
    |> Enum.map(&record_to_instance/1)
  end

  defp record_to_instance(%InstanceRecord{} = record) do
    Serializer.from_db(normalize_id(record.id), record.workflow, record.status, record.state)
  end

  defp fetch_record(name, id) do
    repo(name).get(InstanceRecord, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp normalize_id(id), do: String.upcase(id)

  defp repo(name) do
    :persistent_term.get(repo_key(name))
  end

  defp repo_key(name), do: {@repo_key_parts, name}
end
