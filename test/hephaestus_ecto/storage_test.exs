defmodule HephaestusEcto.Test_Wild.SimpleWorkflow do
  use Hephaestus.Workflow, unique: [key: "testecto"]

  def start, do: HephaestusEcto.Test.PassStep

  def transit(HephaestusEcto.Test.PassStep, :done, _ctx), do: Hephaestus.Steps.Done
end

defmodule HephaestusEcto.TestXWild.SimpleWorkflow do
  use Hephaestus.Workflow, unique: [key: "testecto"]

  def start, do: HephaestusEcto.Test.PassStep

  def transit(HephaestusEcto.Test.PassStep, :done, _ctx), do: Hephaestus.Steps.Done
end

defmodule HephaestusEcto.StorageTest do
  use ExUnit.Case, async: false

  alias Hephaestus.Core.Instance
  alias HephaestusEcto.Storage

  @storage_name HephaestusEcto.TestStorage

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(HephaestusEcto.TestRepo)
    Storage.start_link(repo: HephaestusEcto.TestRepo, name: @storage_name)
    :ok
  end

  describe "put/2 and get/2" do
    test "persists and retrieves an instance" do
      instance =
        Instance.new(
          HephaestusEcto.Test.SimpleWorkflow,
          1,
          %{order_id: 1},
          "testecto::storageputget"
        )

      :ok = Storage.put(@storage_name, instance)
      result = Storage.get(@storage_name, instance.id)

      assert {:ok, recovered} = result
      assert recovered.id == instance.id
      assert recovered.workflow == HephaestusEcto.Test.SimpleWorkflow
      assert recovered.status == :pending
      assert recovered.context.initial.order_id == 1
    end

    test "returns error for nonexistent id" do
      result = Storage.get(@storage_name, "nonexistent-id")

      assert {:error, :not_found} = result
    end

    test "upserts on conflict" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::storageupsert")
      :ok = Storage.put(@storage_name, instance)

      updated = %{instance | status: :running}
      :ok = Storage.put(@storage_name, updated)
      {:ok, recovered} = Storage.get(@storage_name, instance.id)

      assert recovered.status == :running
    end
  end

  describe "delete/2" do
    test "removes an instance" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::storagedelete")
      :ok = Storage.put(@storage_name, instance)

      :ok = Storage.delete(@storage_name, instance.id)

      assert {:error, :not_found} = Storage.get(@storage_name, instance.id)
    end

    test "returns ok for nonexistent instance" do
      result = Storage.delete(@storage_name, "nonexistent-id")

      assert result == :ok
    end
  end

  describe "query/2" do
    test "filters by status" do
      pending = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::querystatuspending")

      running =
        %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::querystatusrunning") |
          status: :running}
      :ok = Storage.put(@storage_name, pending)
      :ok = Storage.put(@storage_name, running)

      results = Storage.query(@storage_name, status: :running)

      assert length(results) == 1
      assert hd(results).status == :running
    end

    test "filters by workflow" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::queryworkflow")
      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, workflow: HephaestusEcto.Test.SimpleWorkflow)

      assert length(results) == 1
    end

    test "returns empty list when no matches" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::queryempty")
      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, status: :completed)

      assert results == []
    end
  end

  describe "query/2 with :id filter" do
    test "returns instance matching exact ID" do
      target = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::filterid1")
      other = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::filterid2")
      :ok = Storage.put(@storage_name, target)
      :ok = Storage.put(@storage_name, other)

      results = Storage.query(@storage_name, id: target.id)

      assert Enum.map(results, & &1.id) == [target.id]
    end
  end

  describe "query/2 with :status_in filter" do
    test "returns instances matching any of the given statuses" do
      pending = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::statusinpending")

      running =
        %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::statusinrunning") |
          status: :running}

      completed =
        %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::statusincomplete") |
          status: :completed}

      :ok = Storage.put(@storage_name, pending)
      :ok = Storage.put(@storage_name, running)
      :ok = Storage.put(@storage_name, completed)

      results = Storage.query(@storage_name, status_in: [:pending, :running])

      assert Enum.sort(Enum.map(results, & &1.status)) == [:pending, :running]
    end

    test "returns instances matching single status" do
      instance =
        %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::statussingle") |
          status: :running}

      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, status_in: [:running])
      assert length(results) == 1
      assert hd(results).id == instance.id
    end
  end

  describe "query/2 with combined new filters" do
    test "applies :id + :status_in + :workflow with AND semantics" do
      target = %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::combinedtarget") |
        status: :running}

      wrong_id = %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::combinedother") |
        status: :running}

      wrong_status = Instance.new(
        HephaestusEcto.Test.SimpleWorkflow,
        1,
        %{},
        "testecto::combinedthird"
      )

      wrong_workflow =
        %{Instance.new(HephaestusEcto.TestXWild.SimpleWorkflow, 1, %{}, "testecto::combinedwild") |
          status: :running}

      :ok = Storage.put(@storage_name, target)
      :ok = Storage.put(@storage_name, wrong_id)
      :ok = Storage.put(@storage_name, wrong_status)
      :ok = Storage.put(@storage_name, wrong_workflow)

      results =
        Storage.query(@storage_name,
          id: target.id,
          status_in: [:running],
          workflow: HephaestusEcto.Test.SimpleWorkflow
        )

      assert Enum.map(results, & &1.id) == [target.id]
    end
  end

  describe "workflow_version query filters" do
    test "query by workflow_version" do
      instance_v1 = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::versionqueryv1")
      instance_v2 = Instance.new(HephaestusEcto.Test.SimpleWorkflow, 2, %{}, "testecto::versionqueryv2")
      :ok = Storage.put(@storage_name, instance_v1)
      :ok = Storage.put(@storage_name, instance_v2)

      results = Storage.query(@storage_name, workflow_version: 2)

      assert length(results) == 1
      assert hd(results).workflow_version == 2
    end

    test "query by workflow_family matches prefix" do
      instance =
        Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::workflowfamilymatch")
      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, workflow_family: "Elixir.HephaestusEcto.Test")

      assert length(results) >= 1

      assert Enum.all?(results, fn inst ->
               String.starts_with?(Atom.to_string(inst.workflow), "Elixir.HephaestusEcto.Test")
             end)
    end

    test "query by workflow_family returns empty when no match" do
      instance =
        Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::workflowfamilyempty")
      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, workflow_family: "Elixir.NonExistent")

      assert results == []
    end

    test "query by workflow_family escapes SQL LIKE wildcards" do
      matching = Instance.new(HephaestusEcto.Test_Wild.SimpleWorkflow, 1, %{}, "testecto::wildmatch")
      non_matching =
        Instance.new(HephaestusEcto.TestXWild.SimpleWorkflow, 1, %{}, "testecto::wildnonmatch")
      :ok = Storage.put(@storage_name, matching)
      :ok = Storage.put(@storage_name, non_matching)

      results = Storage.query(@storage_name, workflow_family: "Elixir.HephaestusEcto.Test_Wild")

      assert Enum.map(results, & &1.workflow) == [HephaestusEcto.Test_Wild.SimpleWorkflow]
    end

    test "persists and retrieves workflow_version" do
      instance =
        Instance.new(HephaestusEcto.Test.SimpleWorkflow, 3, %{}, "testecto::versionpersist")
      :ok = Storage.put(@storage_name, instance)

      {:ok, recovered} = Storage.get(@storage_name, instance.id)

      assert recovered.workflow_version == 3
    end

    test "workflow_version is not replaced on upsert" do
      instance =
        Instance.new(HephaestusEcto.Test.SimpleWorkflow, 5, %{}, "testecto::versionupsert")
      :ok = Storage.put(@storage_name, instance)

      updated = %{instance | status: :running, workflow_version: 99}
      :ok = Storage.put(@storage_name, updated)

      {:ok, recovered} = Storage.get(@storage_name, instance.id)

      assert recovered.workflow_version == 5
      assert recovered.status == :running
    end
  end
end
