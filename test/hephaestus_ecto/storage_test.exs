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
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{order_id: 1})

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
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})
      :ok = Storage.put(@storage_name, instance)

      updated = %{instance | status: :running}
      :ok = Storage.put(@storage_name, updated)
      {:ok, recovered} = Storage.get(@storage_name, instance.id)

      assert recovered.status == :running
    end
  end

  describe "delete/2" do
    test "removes an instance" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})
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
      pending = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})
      running = %{Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{}) | status: :running}
      :ok = Storage.put(@storage_name, pending)
      :ok = Storage.put(@storage_name, running)

      results = Storage.query(@storage_name, status: :running)

      assert length(results) == 1
      assert hd(results).status == :running
    end

    test "filters by workflow" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})
      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, workflow: HephaestusEcto.Test.SimpleWorkflow)

      assert length(results) == 1
    end

    test "returns empty list when no matches" do
      instance = Instance.new(HephaestusEcto.Test.SimpleWorkflow, %{})
      :ok = Storage.put(@storage_name, instance)

      results = Storage.query(@storage_name, status: :completed)

      assert results == []
    end
  end
end
