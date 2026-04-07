defmodule HephaestusEcto.Serializer do
  @moduledoc """
  Converts between `Hephaestus.Core.Instance` structs and database-safe values.

  Handles the type conversions required to persist Elixir-specific types
  (atoms, MapSets, module references, DateTimes) into PostgreSQL JSONB.

  All deserialization uses `String.to_existing_atom/1` to prevent
  arbitrary atom creation from database values.
  """

  alias Hephaestus.Core.{Context, ExecutionEntry, Instance}

  @doc """
  Serializes an `Instance` struct into a tuple of database-safe values.

  Returns `{id, workflow_string, status_string, state_map}` where `state_map`
  contains the serialized context, step configs, active/completed steps,
  and execution history.
  """
  @spec to_db(Instance.t()) :: {String.t(), String.t(), String.t(), map()}
  def to_db(%Instance{} = instance) do
    state = %{
      "current_step" => maybe_module_to_string(instance.current_step),
      "context" => serialize_context(instance.context),
      "step_configs" => serialize_step_configs(instance.step_configs),
      "active_steps" => mapset_to_sorted_strings(instance.active_steps),
      "completed_steps" => mapset_to_sorted_strings(instance.completed_steps),
      "execution_history" => Enum.map(instance.execution_history, &serialize_entry/1)
    }

    {instance.id, Atom.to_string(instance.workflow), Atom.to_string(instance.status), state}
  end

  @doc """
  Reconstructs an `Instance` struct from database values.

  Converts string module names back to atoms (via `String.to_existing_atom/1`),
  sorted lists back to MapSets, and ISO 8601 timestamps back to `DateTime`.
  """
  @spec from_db(String.t(), String.t(), String.t(), map()) :: Instance.t()
  def from_db(id, workflow, status, state) when is_map(state) do
    %Instance{
      id: id,
      workflow: ensure_loaded_module(workflow),
      status: String.to_existing_atom(status),
      current_step: maybe_string_to_module(state["current_step"]),
      context: deserialize_context(state["context"]),
      step_configs: deserialize_step_configs(state["step_configs"] || %{}),
      active_steps: strings_to_mapset(state["active_steps"] || []),
      completed_steps: strings_to_mapset(state["completed_steps"] || []),
      execution_history: Enum.map(state["execution_history"] || [], &deserialize_entry/1)
    }
  end

  defp maybe_module_to_string(nil), do: nil
  defp maybe_module_to_string(module) when is_atom(module), do: Atom.to_string(module)

  defp maybe_string_to_module(nil), do: nil
  defp maybe_string_to_module(module_string), do: ensure_loaded_module(module_string)

  defp ensure_loaded_module(module_string) when is_binary(module_string) do
    module = String.to_existing_atom(module_string)
    Code.ensure_loaded!(module)
    module
  end

  defp mapset_to_sorted_strings(mapset) do
    mapset
    |> MapSet.to_list()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.sort()
  end

  defp strings_to_mapset(strings) do
    strings
    |> Enum.map(&ensure_loaded_module/1)
    |> MapSet.new()
  end

  defp serialize_context(%Context{initial: initial, steps: steps}) do
    %{
      "initial" => stringify_keys(initial),
      "steps" =>
        Map.new(steps, fn {step_ref, result} ->
          {Atom.to_string(step_ref), stringify_keys(result)}
        end)
    }
  end

  defp deserialize_context(%{"initial" => initial, "steps" => steps}) do
    %Context{
      initial: atomize_keys(initial),
      steps:
        Map.new(steps, fn {step_ref, result} ->
          {String.to_existing_atom(step_ref), atomize_keys(result)}
        end)
    }
  end

  defp deserialize_context(_), do: Context.new(%{})

  defp serialize_step_configs(configs) do
    Map.new(configs, fn {step_module, config} ->
      {Atom.to_string(step_module), stringify_keys(config)}
    end)
  end

  defp deserialize_step_configs(configs) do
    Map.new(configs, fn {step_module, config} ->
      {ensure_loaded_module(step_module), config}
    end)
  end

  defp serialize_entry(%ExecutionEntry{} = entry) do
    %{
      "step_ref" => Atom.to_string(entry.step_ref),
      "event" => Atom.to_string(entry.event),
      "timestamp" => DateTime.to_iso8601(entry.timestamp),
      "context_updates" => stringify_keys(entry.context_updates)
    }
  end

  defp deserialize_entry(
         %{"step_ref" => step_ref, "event" => event, "timestamp" => timestamp} = entry
       ) do
    {:ok, parsed_timestamp, 0} = DateTime.from_iso8601(timestamp)

    %ExecutionEntry{
      step_ref: ensure_loaded_module(step_ref),
      event: String.to_existing_atom(event),
      timestamp: parsed_timestamp,
      context_updates: atomize_keys(entry["context_updates"])
    }
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} -> {key, stringify_keys(value)}
    end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(other), do: other

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), atomize_keys(value)}
      {key, value} -> {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(other), do: other
end
