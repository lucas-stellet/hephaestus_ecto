defmodule HephaestusEcto.ConcurrencyTest do
  use ExUnit.Case, async: false

  alias Hephaestus.Core.Instance
  alias HephaestusEcto.Storage

  @storage_name HephaestusEcto.ConcurrencyStorage

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(HephaestusEcto.TestRepo)
    Ecto.Adapters.SQL.Sandbox.mode(HephaestusEcto.TestRepo, {:shared, self()})
    Storage.start_link(repo: HephaestusEcto.TestRepo, name: @storage_name)
    :ok
  end

  test "parallel puts for different instances" do
    instances =
      for i <- 1..10 do
        Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::concurrencyparallel#{i}")
      end

    tasks =
      Enum.map(instances, fn inst ->
        Task.async(fn -> Storage.put(@storage_name, inst) end)
      end)

    results = Task.await_many(tasks, 5_000)

    assert Enum.all?(results, &(&1 == :ok))

    for inst <- instances do
      assert {:ok, _} = Storage.get(@storage_name, inst.id)
    end
  end

  test "concurrent get during writes" do
    instance =
      Instance.new(HephaestusEcto.Test.SimpleWorkflow, 1, %{}, "testecto::concurrencyreads")
    :ok = Storage.put(@storage_name, instance)

    write_task =
      Task.async(fn ->
        for i <- 1..5 do
          updated = %{instance | status: if(rem(i, 2) == 0, do: :running, else: :pending)}
          Storage.put(@storage_name, updated)
        end
      end)

    read_task =
      Task.async(fn ->
        for _ <- 1..10 do
          case Storage.get(@storage_name, instance.id) do
            {:ok, inst} -> assert inst.status in [:pending, :running]
            {:error, :not_found} -> flunk("instance disappeared during writes")
          end
        end
      end)

    Task.await(write_task, 5_000)
    Task.await(read_task, 5_000)
  end
end
