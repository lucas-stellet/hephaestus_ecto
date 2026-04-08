defmodule HephaestusEcto.SerializerTest do
  use ExUnit.Case, async: true

  alias Hephaestus.Core.{Context, Instance}
  alias HephaestusEcto.Serializer

  describe "to_db/1" do
    test "serializes a pending instance" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{order_id: 123})

      {id, workflow, status, state} = Serializer.to_db(instance)

      assert id == instance.id
      assert workflow == "Elixir.HephaestusEcto.Test.SimpleWorkflow"
      assert status == "pending"
      assert state["current_step"] == nil
      assert state["context"]["initial"]["order_id"] == 123
      assert state["active_steps"] == []
      assert state["completed_steps"] == []
      assert state["step_configs"] == %{}
    end

    test "serializes MapSets as sorted lists" do
      instance = %Instance{
        id: "test-id",
        workflow: HephaestusEcto.Test.SimpleWorkflow,
        status: :running,
        active_steps: MapSet.new([HephaestusEcto.Test.PassStep]),
        completed_steps: MapSet.new(),
        context: Context.new(%{})
      }

      {_id, _workflow, _status, state} = Serializer.to_db(instance)

      assert state["active_steps"] == ["Elixir.HephaestusEcto.Test.PassStep"]
      assert state["completed_steps"] == []
    end
  end

  describe "from_db/4" do
    test "round-trips a full instance" do
      original = %Instance{
        id: "test-id",
        workflow: HephaestusEcto.Test.SimpleWorkflow,
        status: :running,
        current_step: HephaestusEcto.Test.PassStep,
        context: %Context{initial: %{order_id: 123}, steps: %{pass_step: %{result: true}}},
        step_configs: %{HephaestusEcto.Test.PassStep => %{key: "val"}},
        active_steps: MapSet.new([HephaestusEcto.Test.PassStep]),
        completed_steps: MapSet.new(),
        execution_history: []
      }

      {id, workflow, status, state} = Serializer.to_db(original)
      recovered = Serializer.from_db(id, workflow, status, state)

      assert recovered.id == "test-id"
      assert recovered.workflow == HephaestusEcto.Test.SimpleWorkflow
      assert recovered.status == :running
      assert recovered.current_step == HephaestusEcto.Test.PassStep
      assert recovered.active_steps == MapSet.new([HephaestusEcto.Test.PassStep])
      assert recovered.completed_steps == MapSet.new()
      assert recovered.context.initial.order_id == 123
      assert recovered.context.steps.pass_step.result == true
      assert recovered.step_configs == %{HephaestusEcto.Test.PassStep => %{"key" => "val"}}
    end

    test "handles nil current_step" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})

      {id, workflow, status, state} = Serializer.to_db(instance)
      recovered = Serializer.from_db(id, workflow, status, state)

      assert recovered.current_step == nil
    end

    test "handles empty MapSets" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})

      {id, workflow, status, state} = Serializer.to_db(instance)
      recovered = Serializer.from_db(id, workflow, status, state)

      assert recovered.active_steps == MapSet.new()
      assert recovered.completed_steps == MapSet.new()
    end

    test "round-trips runtime_metadata" do
      original = %Instance{
        id: "test-id",
        workflow: HephaestusEcto.Test.SimpleWorkflow,
        status: :running,
        current_step: HephaestusEcto.Test.PassStep,
        context: Context.new(%{}),
        step_configs: %{},
        active_steps: MapSet.new(),
        completed_steps: MapSet.new(),
        execution_history: [],
        runtime_metadata: %{"user_email" => "test@example.com", "trace_id" => "abc-123"}
      }

      {id, workflow, status, state} = Serializer.to_db(original)
      recovered = Serializer.from_db(id, workflow, status, state)

      assert recovered.runtime_metadata == %{"user_email" => "test@example.com", "trace_id" => "abc-123"}
    end

    test "defaults runtime_metadata to empty map for legacy state" do
      state = %{
        "current_step" => nil,
        "context" => %{"initial" => %{}, "steps" => %{}},
        "step_configs" => %{},
        "active_steps" => [],
        "completed_steps" => [],
        "execution_history" => []
      }

      recovered =
        Serializer.from_db(
          "test-id",
          "Elixir.HephaestusEcto.Test.SimpleWorkflow",
          "pending",
          state
        )

      assert recovered.runtime_metadata == %{}
    end
  end
end
