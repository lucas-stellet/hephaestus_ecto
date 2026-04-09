defmodule HephaestusEcto.Migrations.Postgres.V01 do
  @moduledoc false

  use Ecto.Migration

  alias HephaestusEcto.Migrations.Postgres

  def up(%{prefix: prefix}) do
    create table(:workflow_instances, primary_key: false, prefix: prefix) do
      add(:id, :uuid, primary_key: true)
      add(:workflow, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:state, :map, null: false, default: %{})
      timestamps()
    end

    create(index(:workflow_instances, [:status], prefix: prefix))
    create(index(:workflow_instances, [:workflow], prefix: prefix))

    execute(
      "CREATE INDEX idx_workflow_instances_state ON #{Postgres.qualified_table(prefix, "workflow_instances")} USING GIN (state jsonb_path_ops)"
    )
  end

  def down(%{prefix: prefix}) do
    drop(table(:workflow_instances, prefix: prefix))
  end
end
