defmodule HephaestusEcto.Schema.InstanceTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset, only: [get_change: 2]

  alias HephaestusEcto.Schema.Instance
  alias HephaestusEcto.Test.ChangesetHelpers

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        workflow: "Elixir.MyApp.OrderWorkflow",
        status: "pending",
        state: %{"current_step" => nil}
      }

      changeset = Instance.changeset(attrs)

      assert changeset.valid? == true
      assert get_change(changeset, :id) == "550e8400-e29b-41d4-a716-446655440000"
      assert get_change(changeset, :status) == "pending"
    end

    test "missing required fields produce errors" do
      changeset = Instance.changeset(%{})
      errors = ChangesetHelpers.errors_on(changeset)

      assert changeset.valid? == false
      assert "can't be blank" in errors.id
      assert "can't be blank" in errors.workflow
      assert "can't be blank" in errors.status
      assert "can't be blank" in errors.state
    end

    test "invalid status is rejected" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        workflow: "Elixir.MyApp.OrderWorkflow",
        status: "exploded",
        state: %{}
      }

      changeset = Instance.changeset(attrs)
      errors = ChangesetHelpers.errors_on(changeset)

      assert changeset.valid? == false
      assert "is invalid" in errors.status
    end

    test "all valid statuses are accepted" do
      base = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        workflow: "Elixir.MyApp.OrderWorkflow",
        state: %{}
      }

      for status <- ~w(pending running waiting completed failed) do
        changeset = Instance.changeset(Map.put(base, :status, status))
        assert changeset.valid? == true, "expected status '#{status}' to be valid"
      end
    end

    test "workflow_version must be greater than zero" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        workflow: "Elixir.MyApp.OrderWorkflow",
        status: "pending",
        workflow_version: 0,
        state: %{}
      }

      changeset = Instance.changeset(attrs)
      errors = ChangesetHelpers.errors_on(changeset)

      assert changeset.valid? == false
      assert "must be greater than 0" in errors.workflow_version
    end
  end
end
