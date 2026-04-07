defmodule HephaestusEcto.Migration do
  @moduledoc false

  use Ecto.Migration

  def up do
    create table(:workflow_instances, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:workflow, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:state, :map, null: false, default: %{})
      timestamps()
    end

    create(index(:workflow_instances, [:status]))
    create(index(:workflow_instances, [:workflow]))

    execute(
      "CREATE INDEX idx_workflow_instances_state ON workflow_instances USING GIN (state jsonb_path_ops)"
    )
  end

  def down do
    drop(table(:workflow_instances))
  end
end
