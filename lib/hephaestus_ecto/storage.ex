defmodule HephaestusEcto.Storage do
  @moduledoc """
  Ecto-backed storage adapter for workflow instances.
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

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.get(opts, :name, __MODULE__)},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  @spec start_link(keyword()) :: :ignore
  def start_link(opts \\ []) do
    repo = Keyword.fetch!(opts, :repo)
    name = Keyword.get(opts, :name, __MODULE__)

    :persistent_term.put(repo_key(name), repo)
    :ignore
  end

  @impl StorageBehaviour
  @spec get(String.t()) :: {:ok, Instance.t()} | {:error, :not_found}
  def get(id), do: get(__MODULE__, id)

  @spec get(name(), String.t()) :: {:ok, Instance.t()} | {:error, :not_found}
  def get(name, id) when is_binary(id) do
    case fetch_record(name, id) do
      nil -> {:error, :not_found}
      record -> {:ok, record_to_instance(record)}
    end
  end

  @impl StorageBehaviour
  @spec put(Instance.t()) :: :ok
  def put(instance), do: put(__MODULE__, instance)

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

  @impl StorageBehaviour
  @spec delete(String.t()) :: :ok
  def delete(id), do: delete(__MODULE__, id)

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

  @impl StorageBehaviour
  @spec query(filters()) :: [Instance.t()]
  def query(filters), do: query(__MODULE__, filters)

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
